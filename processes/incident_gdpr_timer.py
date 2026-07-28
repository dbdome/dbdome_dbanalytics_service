"""
GRC Phase 4: GDPR 72-hour Breach Notification Timer

Runs every 5 minutes. Scans log.incidents for records where:
  - involves_personal_data = TRUE
  - gdpr_notification_due  < NOW()
  - gdpr_notified_at IS NULL

For each overdue incident, fires an alert via the GRC alert channels
(EMAIL / WEBHOOK) tagged as GDPR_BREACH_NOTIFICATION.
"""

from datetime import datetime, timezone
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
import psycopg2
import json
import urllib.request
import urllib.error


def _fire_channel(channel: dict, incident: dict):
    ctype = channel.get("channel_type", "")
    if ctype == "EMAIL":
        # Reuse email_handler if available, else log
        try:
            from email_utils.email_handler import send_plain_email
            send_plain_email(
                to=channel["config_json"].get("recipients", ""),
                subject=f"[GDPR ALERT] 72h breach notification overdue — {incident['title']}",
                body=(
                    f"Incident #{incident['incident_id']}: {incident['title']}\n"
                    f"Detected at: {incident['detected_at']}\n"
                    f"Notification was due: {incident['gdpr_notification_due']}\n"
                    f"ACTION REQUIRED: Notify supervisory authority within GDPR Article 33."
                ),
            )
        except Exception:
            pass
    elif ctype == "WEBHOOK":
        url = channel["config_json"].get("url", "")
        if url:
            payload = json.dumps({
                "event": "GDPR_BREACH_NOTIFICATION_OVERDUE",
                "incident_id": incident["incident_id"],
                "title": incident["title"],
                "gdpr_notification_due": str(incident["gdpr_notification_due"]),
            }).encode()
            try:
                req = urllib.request.Request(
                    url, data=payload,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                urllib.request.urlopen(req, timeout=10)
            except Exception:
                pass


def run_gdpr_timer():
    try:
        conn = psycopg2.connect(get_connection_string())
        cur  = conn.cursor()

        cur.execute(
            """
            SELECT incident_id, title, detected_at, gdpr_notification_due
            FROM   log.incidents
            WHERE  involves_personal_data = TRUE
              AND  gdpr_notification_due  < NOW()
              AND  gdpr_notified_at IS NULL
              AND  state NOT IN ('CLOSED')
            ORDER  BY gdpr_notification_due ASC
            """
        )
        overdue = cur.fetchall()

        if not overdue:
            cur.close()
            conn.close()
            return

        # Fetch active alert channels
        cur.execute(
            """
            SELECT channel_type, config_json
            FROM   config.grc_alert_channels
            WHERE  is_active = TRUE
              AND  channel_type IN ('EMAIL','WEBHOOK')
            """
        )
        channels = [
            {"channel_type": r[0], "config_json": r[1] if isinstance(r[1], dict) else json.loads(r[1] or "{}")}
            for r in cur.fetchall()
        ]

        now = datetime.now(timezone.utc)
        for incident_id, title, detected_at, gdpr_due in overdue:
            incident = {
                "incident_id": incident_id,
                "title": title,
                "detected_at": detected_at,
                "gdpr_notification_due": gdpr_due,
            }
            for ch in channels:
                _fire_channel(ch, incident)

            # Mark as notified (suppress repeat alerts)
            cur.execute(
                "UPDATE log.incidents SET gdpr_notified_at=NOW() WHERE incident_id=%s",
                (incident_id,),
            )
            print(f"[gdpr_timer] fired notification for incident #{incident_id}")

        conn.commit()
        cur.close()
        conn.close()

    except Exception as e:
        db_write_log(f"incident_gdpr_timer error: {e}", "", "incident_gdpr_timer", "")
