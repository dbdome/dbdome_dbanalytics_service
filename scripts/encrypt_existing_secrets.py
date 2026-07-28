"""One-time migration: encrypt existing plaintext secrets in place.

Encrypts config.mail_config.smtp_password and metrics.servers.password using the
SAME key the deployed service uses (DBDOME_SECRET_KEY in the service .env), so the
running app can decrypt them. Already-encrypted (enc:v1:) and blank values are
skipped, so this is safe to re-run.

Usage (on the host, against the local dbanalytics):
    python encrypt_existing_secrets.py [path-to-service-.env]
Default service .env: C:\\ProgramData\\DBDOME\\bin\\.env
"""
import os
import sys
from dotenv import load_dotenv
from cryptography.fernet import Fernet

BIN_ENV = sys.argv[1] if len(sys.argv) > 1 else r"C:\ProgramData\DBDOME\bin\.env"
APP_DIR = r"C:\dev\dbdome_dbanalytics_service"

# Ensure a key exists in the service .env and is loaded into this process so the
# migration and the running service share it.
load_dotenv(BIN_ENV)
if not os.environ.get("DBDOME_SECRET_KEY"):
    k = Fernet.generate_key().decode()
    with open(BIN_ENV, "a", encoding="utf-8") as f:
        f.write(f"\nDBDOME_SECRET_KEY={k}\n")
    os.environ["DBDOME_SECRET_KEY"] = k
    print(f"generated new DBDOME_SECRET_KEY in {BIN_ENV}")
else:
    print(f"using existing DBDOME_SECRET_KEY from {BIN_ENV}")

sys.path.insert(0, APP_DIR)
from utils.secrets_crypto import encrypt_secret, is_encrypted  # noqa: E402
import psycopg2  # noqa: E402

conn = psycopg2.connect(host="localhost", dbname="dbanalytics",
                        user="dbdome_adm", password="Yd2243796Anz!!")
conn.autocommit = False
cur = conn.cursor()


def migrate(table, pwcol):
    cur.execute(f"SELECT ctid, {pwcol} FROM {table} WHERE {pwcol} IS NOT NULL AND {pwcol} <> ''")
    rows = cur.fetchall()
    n = 0
    for ctid, pw in rows:
        if not is_encrypted(pw):
            cur.execute(f"UPDATE {table} SET {pwcol}=%s WHERE ctid=%s", (encrypt_secret(pw), ctid))
            n += 1
    print(f"{table}.{pwcol}: encrypted {n} of {len(rows)} non-empty rows")


migrate("config.mail_config", "smtp_password")
migrate("metrics.servers", "password")
conn.commit()
cur.close()
conn.close()
print("MIGRATION_DONE")
