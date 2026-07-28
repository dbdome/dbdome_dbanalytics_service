from dotenv import load_dotenv
import os
import sys
from urllib.parse import quote
from utils.secrets_crypto import decrypt_secret, get_raw_key

def get_connection_string():
    env_path = os.path.join(os.path.dirname(sys.executable), ".env")
    load_dotenv(env_path, override=True)
    pg_user = os.getenv("PG_USER","dbdome_adm")
    # PG_PASSWORD may be stored encrypted (enc:v1:...) in .env; decrypt_secret
    # returns plaintext as-is, so both encrypted and legacy plaintext work.
    pg_password = decrypt_secret(os.getenv("PG_PASSWORD" , 'Yd2243796Anz!!'))
    pg_host = os.getenv("PG_HOST","localhost")
    pg_port = os.getenv("PG_PORT", 5432)
    pg_db = os.getenv("PG_DB","dbanalytics")

    # URL-quote the credentials: the decrypted password may contain characters
    # reserved in URIs (@ : / %), which silently break libpq's URL parsing.
    dsn = f"postgresql://{quote(pg_user, safe='')}:{quote(pg_password, safe='')}@{pg_host}:{pg_port}/{pg_db}"

    # Inject the per-session rootcause decryption key as a libpq startup option
    # (options=-c rootcause.k=<key>) so every connection can decrypt the encrypted
    # detection logic (sql_scripts/7300_rootcause_content_encryption.sql) via
    # rootcause.dec(). The key is passed only in the process's own conninfo -- it
    # is never stored in the catalog or any dump, so backups stay ciphertext-only.
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
    load_dotenv(os.path.join(os.path.dirname(sys.executable), ".env"), override=True)
    # Windows env lookups are case-insensitive so "org_ip" resolved "ORG_IP"
    # there; Linux is case-sensitive, so accept both (the .env convention is the
    # uppercase ORG_IP). Without this the link host renders as "none" on Linux.
    report_ip = os.getenv("ORG_IP") or os.getenv("org_ip")
    return report_ip

def get_llm():
    LLM   = os.getenv("LLM")  
    return LLM