from dotenv import load_dotenv
import os
import sys
from urllib.parse import quote
from utils.secrets_crypto import decrypt_secret, get_raw_key

def get_connection_string():
    load_dotenv()
    pg_user = os.getenv("PG_USER")
    # PG_PASSWORD may be stored encrypted (enc:v1:...) in .env; decrypt_secret is
    # idempotent (legacy plaintext passes through). Mirrors utils.config_dotenv.
    pg_password = decrypt_secret(os.getenv("PG_PASSWORD"))
    pg_host = os.getenv("PG_HOST")
    pg_port = os.getenv("PG_PORT")
    pg_db = os.getenv("PG_DB")

    # URL-quote the credentials: the decrypted password may contain characters
    # reserved in URIs (@ : / %), which silently break libpq's URL parsing.
    dsn = f"postgresql://{quote(pg_user or '', safe='')}:{quote(pg_password or '', safe='')}@{pg_host}:{pg_port}/{pg_db}"

    # Inject the per-session rootcause decryption key so encrypted detection logic
    # (7300_rootcause_content_encryption.sql) decrypts via rootcause.dec(). The key
    # rides only in this process's conninfo, never in the catalog or a dump.
    try:
        key = get_raw_key()
        if key:
            dsn = f"{dsn}?options={quote(f'-c rootcause.k={key}', safe='')}"
    except Exception:
        pass
    return dsn

def get_ssrs_SERVER_config():
    SSRS_SERVER = os.getenv("SSRS_SERVER")
    return SSRS_SERVER

def get_ssrs_NTLM_USER():
    NTLM_USER = os.getenv("NTLM_USER")
    return NTLM_USER

def get_ssrs_NTLM_PASSWORD():
    NTLM_PASSWORD = os.getenv("NTLM_PASSWORD")
    return NTLM_PASSWORD

def get_ssrs_role_name():
    role_name = os.getenv("role_name")
    return role_name

def get_ssrs_report_path():
    report_path = os.getenv("report_path")
    return report_path

def get_public_or_ip():
    load_dotenv(os.path.join(os.path.dirname(sys.executable), ".env"))
    report_ip = os.getenv("org_ip")
    return report_ip