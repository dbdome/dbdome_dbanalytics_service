"""One-time / idempotent migration: encrypt rootcause.detection_steps logic.

Encrypts detection_steps.content / .expected / .parameters (all jsonb) in place
using rootcause.enc() (pgcrypto/AES-256, see
sql_scripts/7300_rootcause_content_encryption.sql) with the SAME key the deployed
service injects per session (DBDOME_SECRET_KEY in the service .env). Already-armored
values pass through, so this is safe to re-run and safe on partially-migrated data.

PREREQUISITE: 7300_rootcause_content_encryption.sql must already be applied (it
creates pgcrypto + rootcause.enc/dec and rewrites v_rootcauses). The deploy runner
applies numbered sql_scripts before this migration.

Usage (on the host, against the local dbanalytics):
    python encrypt_detection_logic.py [path-to-service-.env]
Default service .env: C:\\ProgramData\\DBDOME\\bin\\.env

The key rides only in this process's session (SET rootcause.k) -- it is never
written to the catalog or a dump, so backups of detection_steps stay ciphertext.
"""
import os
import sys
from dotenv import load_dotenv
from cryptography.fernet import Fernet

BIN_ENV = sys.argv[1] if len(sys.argv) > 1 else r"C:\ProgramData\DBDOME\bin\.env"
APP_DIR = r"C:\dev\dbdome_dbanalytics_service"

# Ensure a key exists in the service .env and load it, so this migration and the
# running service share the exact same passphrase.
load_dotenv(BIN_ENV)
KEY = os.environ.get("DBDOME_SECRET_KEY")
if not KEY:
    KEY = Fernet.generate_key().decode()
    with open(BIN_ENV, "a", encoding="utf-8") as f:
        f.write(f"\nDBDOME_SECRET_KEY={KEY}\n")
    os.environ["DBDOME_SECRET_KEY"] = KEY
    print(f"generated new DBDOME_SECRET_KEY in {BIN_ENV}")
else:
    print(f"using existing DBDOME_SECRET_KEY from {BIN_ENV}")

import psycopg2  # noqa: E402

PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DB   = os.getenv("PG_DB", "dbanalytics")

# Connect as an admin role for the one-off migration; the running service uses its
# own (engine) role. Password default matches the platform install convention.
conn = psycopg2.connect(host=PG_HOST, port=PG_PORT, dbname=PG_DB,
                        user=os.getenv("MIGRATE_PG_USER", "dbdome_adm"),
                        password=os.getenv("MIGRATE_PG_PASSWORD", "Yd2243796Anz!!"))
conn.autocommit = False
cur = conn.cursor()

# Inject the per-session key so rootcause.enc()/dec() can operate.
cur.execute("SELECT set_config('rootcause.k', %s, false)", (KEY,))

# Guard: the encryption objects must exist (7300 applied).
cur.execute("SELECT to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL")
if not cur.fetchone()[0]:
    sys.exit("ERROR: rootcause.enc(jsonb) not found -- apply "
             "sql_scripts/7300_rootcause_content_encryption.sql first.")

NEEDS_WORK = """
      NOT rootcause.is_encrypted(content)
   OR (expected   IS NOT NULL AND NOT rootcause.is_encrypted(expected))
   OR (parameters IS NOT NULL AND NOT rootcause.is_encrypted(parameters))
"""

cur.execute(f"SELECT count(*) FROM rootcause.detection_steps")
total = cur.fetchone()[0]
cur.execute(f"SELECT count(*) FROM rootcause.detection_steps WHERE {NEEDS_WORK}")
todo = cur.fetchone()[0]
print(f"detection_steps: {total} rows, {todo} need encryption")

if todo:
    cur.execute(f"""
        UPDATE rootcause.detection_steps
           SET content    = rootcause.enc(content),
               expected   = rootcause.enc(expected),
               parameters = rootcause.enc(parameters)
         WHERE {NEEDS_WORK}
    """)
    print(f"encrypted {cur.rowcount} rows")

# Verify: every row is now encrypted, and a sample decrypts back to valid SQL.
cur.execute(f"SELECT count(*) FROM rootcause.detection_steps WHERE {NEEDS_WORK}")
remaining = cur.fetchone()[0]
cur.execute("""
    SELECT rootcause.dec(content) ->> 'sql'
      FROM rootcause.detection_steps
     WHERE rootcause.is_encrypted(content) AND content ? 'sql' IS NOT FALSE
     LIMIT 1
""")
sample = cur.fetchone()
if remaining:
    conn.rollback()
    sys.exit(f"ERROR: {remaining} rows still unencrypted after migration -- rolled back.")

conn.commit()
print(f"verify: 0 rows unencrypted; sample decrypt -> {(sample[0][:60] + '...') if sample and sample[0] else '(no sql key sample)'}")

# Role-default key so sessions that do NOT go through get_connection_string()
# (Grafana datasource, report tools, ad-hoc psql) can still decrypt via
# rootcause.dec(). Without this, v_rootcauses returns NULL content in Grafana.
# NOT applied to *_grafana_ro: those roles have no rootcause access (6690) and
# stay unable to decrypt as defense in depth. The key lives in pg_db_role_setting
# (catalog) -- not in a plain pg_dump of the data, so the seed backup stays clean.
for role in ("dbdome_mon_usr", "dbexpert_mon_usr", "dbexpert_adm",
             "dbdome_adm", "dbdome_engine"):
    cur.execute("SELECT 1 FROM pg_roles WHERE rolname=%s", (role,))
    if cur.fetchone():
        cur.execute(f'ALTER ROLE "{role}" SET rootcause.k = %s', (KEY,))
        print(f"  role-default rootcause.k set on {role}")
conn.commit()

cur.close()
conn.close()
print("MIGRATION_DONE")
