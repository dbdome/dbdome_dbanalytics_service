"""
GRC Phase 4: Cross-Border Data Transfer Scanner

Runs every 15 minutes. Inspects recent entries in log.firewall_audit_log
and detects sessions where:
  - The queried server belongs to a non-EEA / non-adequate country
    (per config.data_regions)
  - There is no valid transfer agreement in config.transfer_agreements

Each unique (source_server, destination_server) pair found in the audit
log is checked. A "cross-border transfer" in this context means a user
session that touches a DB in a different data_residency_zone, without a
documented legal basis.
"""

import json
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
import psycopg2


_LOOKBACK_MINUTES = 20   # scan the last N minutes of audit log


def run_cross_border_scan():
    try:
        conn = psycopg2.connect(get_connection_string())
        cur  = conn.cursor()

        # Load region map: server_name → {country_code, zone, is_adequate}
        cur.execute(
            "SELECT server_name, country_code, country_name, "
            "       data_residency_zone, is_adequate "
            "FROM config.data_regions"
        )
        regions = {
            r[0]: {"country_code": r[1], "country_name": r[2],
                   "zone": r[3], "is_adequate": r[4]}
            for r in cur.fetchall()
        }

        if len(regions) < 2:
            cur.close(); conn.close(); return

        # Load transfer agreements
        cur.execute(
            "SELECT source_server, destination_server, agreement_type "
            "FROM config.transfer_agreements "
            "WHERE (valid_until IS NULL OR valid_until >= CURRENT_DATE)"
        )
        agreements = {(r[0], r[1]): r[2] for r in cur.fetchall()}

        # Find distinct (server_name, db_user) pairs from recent audit log
        cur.execute(
            """
            SELECT DISTINCT server_name, db_user, db_name
            FROM log.firewall_audit_log
            WHERE event_time >= NOW() - INTERVAL '%s minutes'
              AND action_taken IN ('ALLOWED','MASKED','ALERTED')
            """,
            (_LOOKBACK_MINUTES,),
        )
        recent_sessions = cur.fetchall()

        # Identify cross-border: session server vs "home" zone of the service
        # We define the "home" zone as the zone of the majority of servers,
        # or simply flag any server that is in a different zone from an EEA baseline.
        eea_servers = {s for s, r in regions.items() if r["zone"] == "EEA"}

        inserted = 0
        for server_name, db_user, db_name in recent_sessions:
            if server_name not in regions:
                continue
            src_region = regions[server_name]

            # Skip if server is EEA or adequate
            if src_region["is_adequate"] or src_region["zone"] == "EEA":
                continue

            # This server is outside EEA / non-adequate — check for agreement
            # We treat transfer as "home EEA service → this non-EEA server"
            for eea_srv in eea_servers:
                pair = (eea_srv, server_name)
                agreement_type = agreements.get(pair, "NONE")
                has_legal_basis = agreement_type not in ("NONE", None)

                risk = "CRITICAL" if not has_legal_basis else "MEDIUM"

                # Deduplicate: skip if already logged in last 24h
                cur.execute(
                    """
                    SELECT 1 FROM log.cross_border_transfers
                    WHERE source_server=%s AND destination_server=%s
                      AND detected_at >= NOW()-INTERVAL '24 hours'
                    LIMIT 1
                    """,
                    (eea_srv, server_name),
                )
                if cur.fetchone():
                    continue

                cur.execute(
                    """
                    INSERT INTO log.cross_border_transfers
                        (source_server, destination_server,
                         source_country, destination_country,
                         transfer_mechanism, has_legal_basis,
                         db_user, table_name, detected_at, risk_level)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,NOW(),%s)
                    """,
                    (
                        eea_srv, server_name,
                        regions[eea_srv]["country_name"] if eea_srv in regions else "EEA",
                        src_region["country_name"],
                        agreement_type, has_legal_basis,
                        db_user, db_name, risk,
                    ),
                )
                inserted += 1

        conn.commit()
        if inserted:
            print(f"[cross_border_scanner] logged {inserted} transfer events")
        cur.close()
        conn.close()

    except Exception as e:
        db_write_log(f"cross_border_scanner error: {e}", "", "cross_border_scanner", "")
