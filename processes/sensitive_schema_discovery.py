"""
Sensitive Schema Discovery

Scans monitoring.schema for columns matching PII/sensitive patterns and
populates monitoring.sensitive_schema. Existing entries are preserved —
only new discoveries are inserted.

Registered in scheduler as 'sensitive_schema_discovery'.
"""

import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# PII column name patterns (regex alternation for PostgreSQL ~ operator)
PII_PATTERNS = (
    '(ssn|social_sec|national_id|tax_id|id_number|id_card|identity|passport|'
    'credit_card|card_num|card_number|cvv|ccv|'
    'email|e_mail|mail_address|'
    'phone|mobile|cell|fax|telephone|'
    'birth_date|dob|date_of_birth|birthday|'
    'first_name|last_name|full_name|surname|family_name|given_name|'
    'address|street|city|zip_code|postal|zipcode|'
    'salary|income|wage|compensation|'
    'bank_account|iban|routing_num|account_num|swift|'
    'password|pwd|secret|token|api_key|'
    'ip_address|mac_address|'
    'gender|sex|race|ethnicity|religion|'
    'medical|diagnosis|prescription|patient|health|'
    'driver_license|licence|social_security)'
)


def discover_sensitive_columns():
    """Scan monitoring.schema for PII columns and insert into sensitive_schema."""
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # Find PII columns not yet in sensitive_schema
        cur.execute(f"""
            INSERT INTO monitoring.sensitive_schema
                (server, database_name, table_schema, table_name, column_name, data_type)
            SELECT DISTINCT
                s.server,
                s.table_catalog,
                NULL,
                s.table_name,
                s.column_name,
                s.data_type
            FROM monitoring.schema s
            WHERE lower(s.column_name) ~ %s
              AND s.is_enabled = true
              AND NOT EXISTS (
                  SELECT 1 FROM monitoring.sensitive_schema ss
                  WHERE ss.server = s.server
                    AND COALESCE(ss.database_name, '') = COALESCE(s.table_catalog, '')
                    AND ss.table_name = s.table_name
                    AND ss.column_name = s.column_name
              )
        """, (PII_PATTERNS,))

        inserted = cur.rowcount
        conn.commit()

        # Count totals
        cur.execute("SELECT COUNT(*) FROM monitoring.sensitive_schema")
        total = cur.fetchone()[0]

        db_write_log(
            f"Sensitive schema discovery: {inserted} new columns found, {total} total sensitive columns",
            0, "sensitive_schema_discovery", ""
        )

        return inserted, total

    except Exception as e:
        conn.rollback()
        db_write_log(f"sensitive_schema_discovery failed: {e}", 0, "sensitive_schema_discovery", "")
        return 0, 0

    finally:
        cur.close()
        conn.close()
