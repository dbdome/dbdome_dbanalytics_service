import psycopg2
import pandas as pd
from utils.config_dotenv import get_connection_string
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.log4dbexpert import db_write_log
from alerts.metrics_api_sender import send_results , server_upsert
from siem.rapid.rapid_sender import siem_rapid_send
from siem.crowdstrike.crowdstrike_sender import siem_crowdstrike_send
from siem.wazuh.wazuh_sender import siem_wazuh_send
from siem.generic.syslog_sender import siem_send_all
from alerts.alert_dispatcher import dispatch          # background alert delivery
import datetime
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
import json

    

def manage_diagnosys_alerts(_root_cause_id, *args, **kwargs):
    # Collectors call this with extra positional args (query, comparison, server,
    # metadata) and keywords (_server_id, status); only _root_cause_id is used.
    # Accept and ignore the rest so a custom/legacy metric never aborts the run.

    p_sql_cmd = """
    SELECT
        server,
        issue_id,
        root_cause_id,
        query,
        mainstat,
        risk_level,
        api_url,
        api_key,
        server_id,
        db_vendor,
        port
    FROM monitoring.v_dbanalytics_alert
    WHERE root_cause_id = %s
    """

    conn = None
    server = None
    try:
        conn = psycopg2.connect(get_connection_string())
        df = pd.read_sql_query(p_sql_cmd, conn, params=(_root_cause_id,))

        if df.empty:
            return 1

        cur = conn.cursor()
        try:
            for _, row in df.iterrows():

                server        = str(row["server"])
                root_cause_id = str(row["root_cause_id"])
                query         = str(row["query"])
                mainstat      = str(row["mainstat"])
                risk_level    = str(row["risk_level"])
                api_url       = row["api_url"] if pd.notna(row["api_url"]) else None
                api_key       = row["api_key"] if pd.notna(row["api_key"]) else None
                server_id     = str(row["server_id"]) if pd.notna(row["server_id"]) else None
                db_vendor     = str(row["db_vendor"]) if pd.notna(row["db_vendor"]) else "sqlserver"
                port          = int(row["port"]) if pd.notna(row["port"]) else None

                if not api_url or not api_key:
                    db_write_log(
                        f"manage_diagnosys_alerts: server {server} has no "
                        f"organization api_url/api_key - skipping send",
                        0, "manage_diagnosys_alerts", server
                    )
                    continue

                server_upsert(
                    _api_url=api_url,
                    _api_key=api_key,
                    _server=server,
                    _server_id=server_id,
                    _vendor_slug=db_vendor,
                    _port=port,
                )

                cur.execute(query)

                columns = [desc[0] for desc in cur.description]
                rows = cur.fetchall()

                result = [dict(zip(columns, r)) for r in rows]

                # ✅ Fix encoding issue
                json_result = json.dumps(result, default=str, ensure_ascii=False)

                try:
                    impact_score = int(float(mainstat))
                except (TypeError, ValueError):
                    impact_score = 0

                send_results(
                    api_url,
                    api_key,
                    server_id,
                    _server=server,
                    _root_cause_id=root_cause_id,
                    _status="success",
                    _result_count=mainstat,
                    _evidence=json_result,
                    _severity=risk_level,
                    impact_score=impact_score,
                )
        finally:
            cur.close()

    except Exception as e:
        db_write_log(
            f"manage_diagnosys_alerts failed: {e}",
            0,
            "manage_diagnosys_alerts",
            server
        )
    finally:
        if conn is not None:
            conn.close()

    return 1

       

def manage_alerts():

    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)

    server = None  # ✅ prevent crash in except

    try:
        # ================= CONFIG =================
        # The gate is per (domain, risk_level) — config.webook_alerts holds one row
        # per combination. Reading it with a bare fetchone() and NO WHERE clause
        # picked an ARBITRARY row and applied its flags to every alert regardless of
        # domain or severity, so whether a critical Security finding reached the SIEM
        # depended on unpredictable row order. Load the whole matrix instead and look
        # each alert up by its own (domain, risk_level).
        with postgres_engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT w.metric_type, w.risk_level,
                           w.send_mail_alert, w.send_siem_alert, w.send_diagnosis_evidence
                    FROM config.webook_alerts w
                    WHERE w.is_active IS TRUE
                """)
            ).fetchall()

        if not rows:
            return 1

        # (domain, risk) -> (mail, siem, evidence); both keys lower-cased because the
        # rootcause content stores risk_level in mixed case ('Critical' vs 'critical').
        gate = {(str(r[0]).strip().lower(), str(r[1]).strip().lower()): (r[2], r[3], r[4])
                for r in rows}

        def _flags(domain, risk):
            return gate.get((str(domain).strip().lower(), str(risk).strip().lower()),
                            (False, False, False))

        # ================= ALERTS =================
        p_sql_cmd = """
            SELECT DISTINCT
                server, domain_name, area_name, issue_name,
                root_cause_id, root_cause_name, root_cause_desc,
                detection_name, detection_desc, step_name, risk_level, query_resultset,
                expected, comparison_data
            FROM rootcause.v_root_cause_alerts
            WHERE execute_numeric_query != 0
              AND risk_level IN (
                  SELECT severity
                  FROM rootcause.severity
                  WHERE is_enabled = true
              )
        """

        df = pd.read_sql_query(p_sql_cmd, con=postgres_engine)

        if df.empty:
            return 1

        # ================= PROCESS =================
        for row in df.itertuples(index=False):

            server            = str(row.server)
            domain_name       = str(row.domain_name)
            area_name         = str(row.area_name)
            issue_name        = str(row.issue_name)
            root_cause_id     = str(row.root_cause_id)
            root_cause_name   = str(row.root_cause_name)
            root_cause_desc   = str(row.root_cause_desc)
            detection_name    = str(row.detection_name)
            detection_desc    = str(row.detection_desc)
            step_name         = str(row.step_name)
            risk_level        = str(row.risk_level)
            query             = str(row.query_resultset)
            expected          = row.expected
            comparison_data   = row.comparison_data

            # ✅ Fix encoding issues (remove problematic chars)
            safe_desc = (
                f"area:{area_name}, domain:{domain_name}, issue:{issue_name}, "
                f"root:{root_cause_name}, desc:{root_cause_desc}, "
                f"detection:{detection_name}, step:{step_name}"
            )

            safe_desc = safe_desc.encode('utf-8', errors='ignore').decode('utf-8')

            # Gate this alert on ITS OWN (domain, risk) row, not on whichever row
            # the old bare fetchone() happened to return.
            send_mail_alert_flag, send_siem_alert_flag, send_diagnosis_evidence = \
                _flags(domain_name, risk_level)

            # ================= ACTIONS =================
            if send_siem_alert_flag:
                # SIEM sends are network I/O against endpoints we do not control.
                # Inline, one unreachable collector cost TIMEOUT seconds on EVERY
                # alert and stalled this loop; dispatch() hands them to the
                # background worker so alert processing never waits on a SIEM.
                dispatch(siem_rapid_send, root_cause_id, risk_level, server, safe_desc,
                         label=f"siem_rapid:{root_cause_id}")
                dispatch(siem_crowdstrike_send, label=f"siem_cs:{root_cause_id}",
                         event_type=root_cause_id,
                         severity=risk_level,
                         server=server,
                         root_cause_id=root_cause_id,
                         description=safe_desc)
                dispatch(siem_wazuh_send, label=f"siem_wazuh:{root_cause_id}",
                         event_type=root_cause_id,
                         severity=risk_level,
                         server=server,
                         root_cause_id=root_cause_id,
                         description=safe_desc)
                # Every other configured SIEM (splunk/qradar/sentinel/arcsight/
                # elastic/sumo/syslog) — format+transport come from config.siem.
                dispatch(siem_send_all, label=f"siem_generic:{root_cause_id}",
                         event_type=root_cause_id,
                         severity=risk_level,
                         server=server,
                         root_cause_id=root_cause_id,
                         description=safe_desc)

            if send_diagnosis_evidence:
                manage_diagnosys_alerts(root_cause_id )

            if send_mail_alert_flag:
                send_mail_alert_no_attachment(
                    server,
                    domain_name,
                    area_name,
                    issue_name,
                    root_cause_id,
                    root_cause_name,
                    root_cause_desc,
                    detection_name,
                    detection_desc,
                    step_name,
                    risk_level,
                    query,
                    expected,
                    comparison_data,
                )

    except Exception as e:
        db_write_log(
            f"manage_alerts failed: {e}",
            0,
            "manage_alerts",
            server
        )

    return 1

def get_utc_timestamp():
    """Return current UTC time as ISO-8601 string with timezone info."""
    return datetime.datetime.now(datetime.timezone.utc).isoformat()