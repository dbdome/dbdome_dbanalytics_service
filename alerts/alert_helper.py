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
import datetime
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
import json

    

def manage_diagnosys_alerts(_root_cause_id ):

    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)

    p_sql_cmd = """
    SELECT 
        server,
        issue_id,
        root_cause_id,
        query,
        mainstat,
        risk_level
    FROM monitoring.v_dbanalyitcs_alert
    WHERE root_cause_id = %s
    """

    conn = None
    try:
        pg_connection_string = get_connection_string()
        conn = psycopg2.connect(pg_connection_string)        
        df = pd.read_sql_query(p_sql_cmd, conn, params=(_root_cause_id,))

        if df.empty:
            return 1

        for _, row in df.iterrows():

            server        = str(row["server"])
            issue_id      = str(row["issue_id"])
            root_cause_id = str(row["root_cause_id"])
            query         = str(row["query"])
            mainstat      = str(row["mainstat"])
            risk_level    = str(row["risk_level"])

            server_upsert(server)

            
        cur = conn.cursor()
        try:
                    cur.execute(query)

                    columns = [desc[0] for desc in cur.description]
                    rows = cur.fetchall()

                    result = [dict(zip(columns, r)) for r in rows]

                    # ✅ Fix encoding issue
                    json_result = json.dumps(result, default=str, ensure_ascii=False)

                    print(json_result)

                    send_results(
                        server,
                        root_cause_id,
                        "success",
                        mainstat,
                        json_result,
                        risk_level,
                        mainstat
                    )

        finally:
                    cur.close()
                    conn.close()

    except Exception as e:
        db_write_log(
            f"manage_diagnosys_alerts failed: {e}",
            0,
            "manage_diagnosys_alerts",
            server if 'server' in locals() else None
        )

    return 1

       

def manage_alerts():

    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)

    server = None  # ✅ prevent crash in except

    try:
        # ================= CONFIG =================
        with postgres_engine.connect() as conn:            
            result = conn.execute(
                text("""
                    SELECT send_mail_alert, send_siem_alert, send_diagnosis_evidence
                    FROM config.webook_alerts
                """)
            ).fetchone()

        if result is None:
            return 1

        send_mail_alert_flag      = result[0]
        send_siem_alert_flag      = result[1]
        send_diagnosis_evidence   = result[2]

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

            # ================= ACTIONS =================
            if send_siem_alert_flag:
                siem_rapid_send(
                    root_cause_id,
                    risk_level,
                    server,
                    safe_desc
                )
                siem_crowdstrike_send(
                    event_type=root_cause_id,
                    severity=risk_level,
                    server=server,
                    root_cause_id=root_cause_id,
                    description=safe_desc
                )

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