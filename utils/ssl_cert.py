"""TLS/SSL certificate management for the DBDOME web (uvicorn) server.

Two-tier model, exactly as requested:

  * **personal**  — a self-signed certificate DBDOME generates for itself on first
                    run. It makes the appliance serve HTTPS out of the box; browsers
                    show a trust warning (self-signed) until a real cert is installed.
  * **customer**  — a certificate the customer uploads (their own CA-signed cert +
                    private key). Once installed it becomes the active certificate.

Which one is served is decided by a tiny pointer file (``active_cert``). The
customer can switch back to the personal cert at any time (revert), and the
personal cert is never deleted, so HTTPS always has something to fall back to.

Everything lives in ``<app_dir>/certs`` (next to the exe when frozen). The
private-key password for an uploaded encrypted key is stored encrypted with the
same Fernet scheme (``enc:v1:``) as every other DBDOME secret.

.env knobs (all optional):
  WEB_SSL_ENABLED       true/false (default: true) — serve HTTPS at all
  WEB_SSL_CERT          absolute path to a cert file — hard override of the slots
  WEB_SSL_KEY           absolute path to the matching private key
  WEB_SSL_KEY_PASSWORD  password for WEB_SSL_KEY (plain or enc:v1:)

Uvicorn binds the certificate once at startup, so installing/reverting a
certificate takes effect on the next web-service restart.
"""
import os
import sys
import ssl
import socket
import datetime

from utils.secrets_crypto import encrypt_secret, decrypt_secret

# --------------------------------------------------------------------------- #
# Locations
# --------------------------------------------------------------------------- #

def _app_dir():
    """Directory that holds the exe (frozen) or this source tree (dev)."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _certs_dir():
    d = os.path.join(_app_dir(), "certs")
    os.makedirs(d, exist_ok=True)
    return d


def _personal_paths():
    d = _certs_dir()
    return os.path.join(d, "personal.crt"), os.path.join(d, "personal.key")


def _customer_paths():
    d = _certs_dir()
    return (os.path.join(d, "customer.crt"),
            os.path.join(d, "customer.key"),
            os.path.join(d, "customer.pass"))


def _active_pointer():
    return os.path.join(_certs_dir(), "active_cert")


# --------------------------------------------------------------------------- #
# .env helpers
# --------------------------------------------------------------------------- #

def _bool_env(name, default):
    v = os.getenv(name)
    if v is None or v.strip() == "":
        return default
    return v.strip().lower() in ("1", "true", "yes", "on")


def is_ssl_enabled():
    return _bool_env("WEB_SSL_ENABLED", True)


# --------------------------------------------------------------------------- #
# Personal (self-signed) certificate
# --------------------------------------------------------------------------- #

def _org_identities():
    """Host names / IPs to embed as SANs so the cert matches however the box is
    reached (configured ORG_IP, hostname, localhost, loopback)."""
    names, ips = ["localhost"], ["127.0.0.1"]
    org_ip = (os.getenv("ORG_IP") or os.getenv("org_ip") or "").strip()
    if org_ip:
        ips.append(org_ip)
    try:
        host = socket.gethostname()
        if host and host not in names:
            names.append(host)
        try:
            host_ip = socket.gethostbyname(host)
            if host_ip and host_ip not in ips:
                ips.append(host_ip)
        except Exception:
            pass
    except Exception:
        pass
    # de-dup, preserve order
    return list(dict.fromkeys(names)), list(dict.fromkeys(ips))


def ensure_personal_cert():
    """Generate the self-signed personal cert/key if either is missing.

    Returns (cert_path, key_path). Raises if the crypto libs are unavailable.
    """
    crt, key = _personal_paths()
    if os.path.exists(crt) and os.path.exists(key):
        return crt, key

    from cryptography import x509
    from cryptography.x509.oid import NameOID
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    names, ips = _org_identities()
    cn = ips[-1] if len(ips) > 1 else (names[-1] if names else "DBDOME")

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "DBDOME"),
        x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, "DBDOME Appliance"),
        x509.NameAttribute(NameOID.COMMON_NAME, cn),
    ])

    san = [x509.DNSName(n) for n in names]
    from ipaddress import ip_address
    for ip in ips:
        try:
            san.append(x509.IPAddress(ip_address(ip)))
        except ValueError:
            pass

    # datetime.utcnow avoided elsewhere in the tree; explicit now() is fine here.
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(private_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - datetime.timedelta(days=1))
        .not_valid_after(now + datetime.timedelta(days=3650))  # 10 years
        .add_extension(x509.SubjectAlternativeName(san), critical=False)
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.ExtendedKeyUsage([x509.ExtendedKeyUsageOID.SERVER_AUTH]),
            critical=False,
        )
        .sign(private_key, hashes.SHA256())
    )

    # Write key first (0600 where the OS honours it), then cert.
    with open(key, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        ))
    try:
        os.chmod(key, 0o600)
    except Exception:
        pass
    with open(crt, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))

    return crt, key


# --------------------------------------------------------------------------- #
# Active-slot resolution
# --------------------------------------------------------------------------- #

def _read_active():
    try:
        with open(_active_pointer(), "r", encoding="utf-8") as f:
            v = f.read().strip().lower()
            if v in ("personal", "customer"):
                return v
    except Exception:
        pass
    return "personal"


def _write_active(slot):
    if slot not in ("personal", "customer"):
        raise ValueError("slot must be 'personal' or 'customer'")
    with open(_active_pointer(), "w", encoding="utf-8") as f:
        f.write(slot)


def _customer_present():
    crt, key, _ = _customer_paths()
    return os.path.exists(crt) and os.path.exists(key)


def get_active_ssl_files():
    """Return (cert_path, key_path, key_password_or_None) for the certificate that
    should be served, or None if SSL is disabled / nothing usable is available.

    Resolution order:
      1. WEB_SSL_CERT + WEB_SSL_KEY env override (hard path override)
      2. the active slot (customer if selected & present, else personal)
      3. personal (auto-generated as a last resort)
    """
    if not is_ssl_enabled():
        return None

    # 1) explicit env override
    env_cert = (os.getenv("WEB_SSL_CERT") or "").strip().strip('"')
    env_key = (os.getenv("WEB_SSL_KEY") or "").strip().strip('"')
    if env_cert and env_key and os.path.exists(env_cert) and os.path.exists(env_key):
        pw = os.getenv("WEB_SSL_KEY_PASSWORD")
        return env_cert, env_key, (decrypt_secret(pw) if pw else None)

    # 2) active slot
    active = _read_active()
    if active == "customer" and _customer_present():
        crt, key, passfile = _customer_paths()
        pw = None
        try:
            if os.path.exists(passfile):
                with open(passfile, "r", encoding="utf-8") as f:
                    stored = f.read().strip()
                pw = decrypt_secret(stored) if stored else None
        except Exception:
            pw = None
        return crt, key, (pw or None)

    # 3) personal fallback (generate on demand)
    try:
        crt, key = ensure_personal_cert()
        return crt, key, None
    except Exception as e:
        print(f"[ssl] personal cert unavailable, serving plain HTTP: {e}")
        return None


def get_uvicorn_ssl_kwargs():
    """kwargs to splat into uvicorn.run(): {} when SSL is off/unavailable."""
    files = get_active_ssl_files()
    if not files:
        return {}
    cert, key, pw = files
    kw = {"ssl_certfile": cert, "ssl_keyfile": key}
    if pw:
        kw["ssl_keyfile_password"] = pw
    return kw


def web_scheme():
    """'https' when the web server will serve TLS, else 'http'. Used to keep
    embedded dashboard links on the right scheme."""
    return "https" if get_active_ssl_files() else "http"


# --------------------------------------------------------------------------- #
# Certificate inspection
# --------------------------------------------------------------------------- #

def describe_cert(cert_path):
    """Best-effort human-readable summary of a PEM cert for the UI."""
    info = {"path": cert_path, "exists": os.path.exists(cert_path)}
    if not info["exists"]:
        return info
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        with open(cert_path, "rb") as f:
            cert = x509.load_pem_x509_certificate(f.read())

        def _cn(name):
            try:
                return name.get_attributes_for_oid(NameOID.COMMON_NAME)[0].value
            except Exception:
                return name.rfc4822_name if hasattr(name, "rfc4822_name") else str(name)

        try:
            not_after = cert.not_valid_after_utc
            not_before = cert.not_valid_before_utc
        except AttributeError:  # cryptography < 42
            not_after = cert.not_valid_after.replace(tzinfo=datetime.timezone.utc)
            not_before = cert.not_valid_before.replace(tzinfo=datetime.timezone.utc)

        now = datetime.datetime.now(datetime.timezone.utc)
        sans = []
        try:
            ext = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName)
            sans = [str(g.value) for g in ext.value]
        except Exception:
            pass

        info.update({
            "subject": _cn(cert.subject),
            "issuer": _cn(cert.issuer),
            "self_signed": cert.subject == cert.issuer,
            "not_before": not_before.strftime("%Y-%m-%d"),
            "not_after": not_after.strftime("%Y-%m-%d"),
            "days_left": (not_after - now).days,
            "expired": not_after < now,
            "sans": sans,
        })
    except Exception as e:
        info["error"] = str(e)
    return info


# --------------------------------------------------------------------------- #
# Customer certificate install / revert
# --------------------------------------------------------------------------- #

def validate_cert_key(cert_path, key_path, password=None):
    """Load the pair the same way uvicorn will (ssl.load_cert_chain). Raises on
    a mismatched/invalid/encrypted-without-password pair; returns describe_cert()."""
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=cert_path, keyfile=key_path, password=(password or None))
    return describe_cert(cert_path)


def install_customer_cert(cert_bytes, key_bytes, password=None):
    """Validate then install an uploaded customer cert+key and make it active.

    Writes to temp files, validates the pair, and only then moves them into the
    customer slot — a bad upload never clobbers a working certificate. Returns
    the cert summary dict. Raises ValueError on an invalid/mismatched pair.
    """
    crt, key, passfile = _customer_paths()
    tmp_crt, tmp_key = crt + ".tmp", key + ".tmp"

    if isinstance(cert_bytes, str):
        cert_bytes = cert_bytes.encode("utf-8")
    if isinstance(key_bytes, str):
        key_bytes = key_bytes.encode("utf-8")

    with open(tmp_crt, "wb") as f:
        f.write(cert_bytes)
    with open(tmp_key, "wb") as f:
        f.write(key_bytes)
    try:
        os.chmod(tmp_key, 0o600)
    except Exception:
        pass

    try:
        summary = validate_cert_key(tmp_crt, tmp_key, password)
    except ssl.SSLError as e:
        _safe_unlink(tmp_crt, tmp_key)
        raise ValueError(f"Certificate/key rejected: {e}") from e
    except Exception as e:
        _safe_unlink(tmp_crt, tmp_key)
        raise ValueError(f"Could not load certificate/key: {e}") from e

    # Promote temp -> live
    os.replace(tmp_crt, crt)
    os.replace(tmp_key, key)
    try:
        if password:
            with open(passfile, "w", encoding="utf-8") as f:
                f.write(encrypt_secret(password))
            try:
                os.chmod(passfile, 0o600)
            except Exception:
                pass
        elif os.path.exists(passfile):
            os.remove(passfile)
    except Exception:
        pass

    _write_active("customer")
    return summary


def revert_to_personal():
    """Switch the active certificate back to the self-signed personal cert."""
    ensure_personal_cert()
    _write_active("personal")


def _safe_unlink(*paths):
    for p in paths:
        try:
            os.remove(p)
        except Exception:
            pass


# --------------------------------------------------------------------------- #
# Status for the config UI
# --------------------------------------------------------------------------- #

def get_status():
    crt_p, key_p = _personal_paths()
    crt_c, key_c, _ = _customer_paths()
    env_cert = (os.getenv("WEB_SSL_CERT") or "").strip().strip('"')
    env_key = (os.getenv("WEB_SSL_KEY") or "").strip().strip('"')
    env_override = bool(env_cert and env_key
                        and os.path.exists(env_cert) and os.path.exists(env_key))

    active = "env" if env_override else _read_active()
    if active == "customer" and not _customer_present():
        active = "personal"

    return {
        "enabled": is_ssl_enabled(),
        "active": active,
        "scheme": web_scheme(),
        "env_override": env_override,
        "env_cert": env_cert if env_override else "",
        "personal": describe_cert(crt_p) if os.path.exists(crt_p) else {"exists": False},
        "customer": describe_cert(crt_c) if _customer_present() else {"exists": False},
    }
