"""
Reversible, app-layer encryption for operational secrets the service must USE
(monitored-DB passwords in metrics.servers, SMTP password in config.mail_config).

Design:
  * Authenticated symmetric encryption (Fernet = AES-128-CBC + HMAC).
  * The key lives OUTSIDE the database (env var DBDOME_SECRET_KEY, persisted in the
    service .env on the host) — so a stolen DB dump/backup cannot be decrypted.
  * Stored values are prefixed "enc:v1:" so reads can tell ciphertext from legacy
    plaintext and migrate gradually. decrypt_secret() passes plaintext through
    unchanged, and encrypt_secret() never double-encrypts.

These are secrets we must reproduce to log in, so this is ENCRYPTION (reversible),
never password hashing.
"""
import os
import sys
from dotenv import load_dotenv
from cryptography.fernet import Fernet

_PREFIX = "enc:v1:"
_cached_fernet = None


def _env_path():
    # Same .env get_connection_string() uses: next to the executable (frozen) or
    # the interpreter (source). On the host this file is outside any DB backup.
    return os.path.join(os.path.dirname(sys.executable), ".env")


def _load_or_create_key():
    # 1) explicit process env wins (lets a migration inject the exact key)
    key = os.environ.get("DBDOME_SECRET_KEY")
    if key:
        return key.encode() if isinstance(key, str) else key
    # 2) load from the service .env
    path = _env_path()
    try:
        load_dotenv(path, override=False)
    except Exception:
        pass
    key = os.environ.get("DBDOME_SECRET_KEY")
    if key:
        return key.encode() if isinstance(key, str) else key
    # 3) generate once and persist next to the other host-side secrets
    key = Fernet.generate_key().decode()
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"\nDBDOME_SECRET_KEY={key}\n")
    except Exception:
        pass
    os.environ["DBDOME_SECRET_KEY"] = key
    return key.encode()


def _fernet():
    global _cached_fernet
    if _cached_fernet is None:
        _cached_fernet = Fernet(_load_or_create_key())
    return _cached_fernet


def get_raw_key():
    """Return the raw DBDOME_SECRET_KEY string (the symmetric passphrase).

    Used by get_connection_string() to inject the per-session rootcause
    decryption key (`options=-c rootcause.k=<key>`) so the DB can decrypt
    detection logic (sql_scripts/7300_rootcause_content_encryption.sql). Same
    key this module uses for Fernet, so there is exactly one host-side secret.
    """
    k = _load_or_create_key()
    return k.decode("ascii") if isinstance(k, (bytes, bytearray)) else k


def is_encrypted(value):
    return isinstance(value, str) and value.startswith(_PREFIX)


def encrypt_secret(value):
    """Return enc:v1:<token>. None/blank and already-encrypted values pass through."""
    if value is None:
        return value
    s = value if isinstance(value, str) else str(value)
    if s == "" or is_encrypted(s):
        return s
    return _PREFIX + _fernet().encrypt(s.encode("utf-8")).decode("ascii")


def decrypt_secret(value):
    """Return plaintext. Legacy plaintext / None pass through unchanged so this is
    safe to call everywhere before and after migration."""
    if not is_encrypted(value):
        return value
    try:
        return _fernet().decrypt(value[len(_PREFIX):].encode("ascii")).decode("utf-8")
    except Exception:
        # Never break a connection/send because of a decrypt issue — surface raw.
        return value
