"""GRC Phase 9: Continuous Sensitive Data Discovery"""
import re
import psycopg2
import psycopg2.errors  # explicit: psycopg2/__init__ never imports this statically (the binding happens inside the compiled _psycopg), so a frozen build drops it and psycopg2.errors.* raises AttributeError at runtime
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_NAME_PATTERNS = {
    'EMAIL':         re.compile(r'email|e_mail|mail_addr', re.I),
    'CREDIT_CARD':   re.compile(r'cc_num|card_num|credit_card|pan|card_no|ccnumber', re.I),
    'SSN':           re.compile(r'\bssn\b|bvn|bank_verif|social_sec|tax_id|national_id', re.I),
    'PHONE':         re.compile(r'phone|mobile|cell|tel_no|telephone', re.I),
    'NAME':          re.compile(r'first_name|last_name|full_name|surname|given_name', re.I),
    'ADDRESS':       re.compile(r'\baddress\b|street|city|\bzip\b|postal', re.I),
    'DATE_OF_BIRTH': re.compile(r'\bdob\b|birth_date|date_of_birth|birthdate', re.I),
}

_SAMPLE_PATTERNS = {
    'CREDIT_CARD': re.compile(r'\b\d{4}[\s\-]\d{4}[\s\-]\d{4}[\s\-]\d{4}\b'),
    'EMAIL':       re.compile(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
    'SSN':         re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),
    'PHONE':       re.compile(r'\+?[\d\s\-\(\)]{10,15}'),
}


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _load_already_masked(conn, server_name: str) -> set:
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT table_name || '.' || column_name
            FROM   config.masking_rules
            WHERE  server_name=%s
        """, (server_name,))
        masked = {r[0] for r in cur.fetchall()}
        cur.close()
        return masked
    except Exception:
        return set()


def _classify_column(column_name: str) -> tuple:
    for pii_type, pattern in _NAME_PATTERNS.items():
        if pattern.search(column_name):
            return pii_type, 'NAME_PATTERN', 80
    return None, None, 0


def _classify_sample(sample_values: list) -> tuple:
    for pii_type, pattern in _SAMPLE_PATTERNS.items():
        for val in sample_values:
            if val and pattern.search(str(val)):
                return pii_type, 'SAMPLE_REGEX', 90
    return None, None, 0


def _upsert_candidate(conn, server_name: str, db_name: str, table_schema: str,
                      table_name: str, column_name: str, data_type: str,
                      pii_type: str, detection_method: str,
                      confidence_score: int, sample_matches: list):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO log.discovery_candidates
                (server_name, db_name, table_schema, table_name, column_name,
                 data_type, pii_type, detection_method, confidence_score, sample_matches)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (server_name, table_name, column_name) DO UPDATE
                SET confidence_score = GREATEST(EXCLUDED.confidence_score,
                                                discovery_candidates.confidence_score),
                    discovered_at = NOW()
              WHERE discovery_candidates.review_status = 'PENDING'
        """, (server_name, db_name, table_schema, table_name, column_name,
              data_type, pii_type, detection_method, confidence_score,
              sample_matches[:3] if sample_matches else []))
        conn.commit()
        cur.close()
    except Exception as e:
        conn.rollback()
        db_write_log(f"_upsert_candidate: {e}", 0, "continuous_data_discovery", server_name)


def _check_high_confidence_pending(conn):
    """Dispatch alerts for high-confidence candidates pending >24h."""
    try:
        from processes.grc_alert_dispatcher import dispatch_grc_alert
        cur = conn.cursor()
        cur.execute("""
            SELECT server_name, table_name, column_name, pii_type, confidence_score
            FROM   log.discovery_candidates
            WHERE  review_status = 'PENDING'
              AND  confidence_score >= 85
              AND  discovered_at <= NOW() - INTERVAL '24 hours'
        """)
        for row in cur.fetchall():
            server_name, table_name, column_name, pii_type, score = row
            dispatch_grc_alert(
                severity='MEDIUM',
                source_feature='sensitive_data_discovery',
                server_name=server_name,
                event_summary=(f"Unmasked {pii_type} column: {table_name}.{column_name} "
                               f"(confidence={score})"),
                regulation='GDPR',
            )
        cur.close()
    except Exception as e:
        db_write_log(f"_check_high_confidence_pending: {e}", 0, "continuous_data_discovery", "")


def run_continuous_data_discovery():
    try:
        conn = _get_conn()
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT DISTINCT
                    r.server,
                    j.value ->> 'db_name'      AS db_name,
                    j.value ->> 'table_schema' AS table_schema,
                    j.value ->> 'table_name'   AS table_name,
                    j.value ->> 'column_name'  AS column_name,
                    j.value ->> 'data_type'    AS data_type,
                    j.value ->> 'sample_value' AS sample_value
                FROM   monitoring.general_metric_metadata_results r
                CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
                WHERE  r.entry_date >= NOW() - INTERVAL '2 hours'
                  AND  j.value ->> 'column_name' IS NOT NULL
            """)
            rows = cur.fetchall()
            cur.close()

            by_server = {}
            for row in rows:
                server, db_name, tschema, tname, col, dtype, sample = row
                if not col or not tname:
                    continue
                by_server.setdefault(server, []).append((db_name, tschema, tname, col, dtype, sample))

            for server_name, columns in by_server.items():
                masked = _load_already_masked(conn, server_name)
                for db_name, tschema, tname, col, dtype, sample in columns:
                    key = f"{tname}.{col}"
                    if key in masked:
                        continue

                    pii_type, method, score = _classify_column(col)

                    if sample and not pii_type:
                        pii_type, method, score = _classify_sample([sample])
                    elif sample and pii_type:
                        sp, sm, ss = _classify_sample([sample])
                        if sp:
                            method = 'COMBINED'
                            score  = min(score + 10, 100)

                    if pii_type:
                        _upsert_candidate(conn, server_name, db_name, tschema,
                                          tname, col, dtype, pii_type, method,
                                          score, [sample] if sample else [])

            _check_high_confidence_pending(conn)
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"run_continuous_data_discovery: {e}", 0, "continuous_data_discovery", "")
