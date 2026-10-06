from dotenv import load_dotenv
import os
import sys
from urllib.parse import quote
from utils.secrets_crypto import decrypt_secret, get_raw_key


def build_pg_host(pg_host, pg_port):
    """Turn PG_HOST -- which may be a comma-separated failover list -- into the
    host portion of a libpq URI, plus any extra query params HA needs.

    High availability / DR:
        PG_HOST=localhost                 -> ("localhost:5432", "")
        PG_HOST=localhost,192.168.1.1     -> ("localhost:5432,192.168.1.1:5432",
                                              "target_session_attrs=read-write&connect_timeout=10")

    libpq itself does the failover. Given several hosts it tries them
    left-to-right, so the first entry is the primary and the rest are the DR
    alternates, in order. target_session_attrs=read-write makes it connect only
    to a node that accepts writes -- the primary, or a standby that has been
    PROMOTED during a DR failover -- and skip one still in read-only recovery,
    which is what you want for a write-heavy monitoring service (a write to a
    read-only standby would only error later). connect_timeout bounds how long a
    dead primary stalls the failover; libpq's default is ~2 minutes PER host.

    A single host (the common case) is returned exactly as before, so there is
    no behaviour change unless a comma is actually present. An entry may carry
    its own port (host:port); otherwise PG_PORT is applied to it. IPv6 literals
    are not handled -- use a hostname for those.
    """
    hosts = [h.strip() for h in str(pg_host).split(",") if h.strip()]
    if len(hosts) <= 1:
        return f"{pg_host}:{pg_port}", ""
    joined = ",".join(h if ":" in h else f"{h}:{pg_port}" for h in hosts)
    return joined, "target_session_attrs=read-write&connect_timeout=10"


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

    # PG_HOST may be a comma-separated failover list (primary,alternate,...) for
    # HA/DR; build_pg_host expands it into a libpq multi-host target.
    host_uri, ha_params = build_pg_host(pg_host, pg_port)

    # URL-quote the credentials: the decrypted password may contain characters
    # reserved in URIs (@ : / %), which silently break libpq's URL parsing.
    dsn = f"postgresql://{quote(pg_user, safe='')}:{quote(pg_password, safe='')}@{host_uri}/{pg_db}"

    # Assemble the query string. All params share one '?...&...' -- multiple
    # '?' would make libpq treat the second onward as part of a value.
    params = []
    if ha_params:
        params.append(ha_params)

    # Inject the per-session rootcause decryption key as a libpq startup option
    # (options=-c rootcause.k=<key>) so every connection can decrypt the encrypted
    # detection logic (sql_scripts/7300_rootcause_content_encryption.sql) via
    # rootcause.dec(). The key is passed only in the process's own conninfo -- it
    # is never stored in the catalog or any dump, so backups stay ciphertext-only.
    try:
        key = get_raw_key()
        if key:
            params.append(f"options={quote(f'-c rootcause.k={key}', safe='')}")
    except Exception:
        pass

    if params:
        dsn = f"{dsn}?{'&'.join(params)}"
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