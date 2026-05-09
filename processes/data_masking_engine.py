"""
GRC Phase 4: Data Masking Engine

Applies column-level masking to query result sets based on rules stored
in config.masking_rules. Rules are seeded from monitoring.sensitive_schema
(Phase 3 PII discovery) and can be overridden per server/table/column.

Masking functions
─────────────────
REDACT    → "***REDACTED***"
PARTIAL   → type-aware partial reveal:
              CREDIT_CARD  last 4:    ****-****-****-1234
              SSN          last 4:    ***-**-1234
              EMAIL        domain:    **@domain.com
              PHONE        last 4:    ******4567
              DOB          year only: ****-**-1985  (if len>=4, else ***)
              NAME         initial:   J***
              default      last 2:    ****67
HASH      → first 12 hex chars of SHA-256
TOKENIZE  → stable surrogate stored in config.masking_tokens

Public API
──────────
apply_masking(rows, columns, server_name, db_user, db_name, user_roles)
    → list of rows with sensitive columns replaced

sync_masking_rules()
    → re-seeds config.masking_rules from monitoring.sensitive_schema (hourly job)
"""

import re
import hashlib
import time
import secrets
import string
import psycopg2
from functools import lru_cache

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# ── Rule cache ────────────────────────────────────────────────────────────────

_RULE_CACHE: dict = {}          # (server_name, table_name, col_lower) → rule dict
_CACHE_LOADED_AT: float = 0.0
_CACHE_TTL: int = 60            # seconds

# ── Column-name → PII type classifier (mirrors SQL CASE in phase4 schema) ───

_PII_PATTERNS: list[tuple[re.Pattern, str, str]] = [
    # (regex, pii_type, default_mask_type)
    (re.compile(r'ssn|social_sec|national_id|tax_id|id_card|identity|passport|driver_licen', re.I), 'SSN',         'PARTIAL'),
    (re.compile(r'credit_card|card_num|cvv|ccv|card_number',                                  re.I), 'CREDIT_CARD', 'PARTIAL'),
    (re.compile(r'email|e_mail|mail_address',                                                  re.I), 'EMAIL',       'PARTIAL'),
    (re.compile(r'phone|mobile|cell|fax|telephone',                                            re.I), 'PHONE',       'PARTIAL'),
    (re.compile(r'birth_date|dob|date_of_birth|birthday',                                      re.I), 'DOB',         'PARTIAL'),
    (re.compile(r'first_name|last_name|full_name|surname|family_name|given_name',              re.I), 'NAME',        'PARTIAL'),
    (re.compile(r'address|street|city|zip|postal',                                             re.I), 'ADDRESS',     'HASH'),
    (re.compile(r'salary|income|wage|compensation',                                            re.I), 'SALARY',      'REDACT'),
    (re.compile(r'password|pwd|secret|token|api_key|bank_account|iban|routing|swift',          re.I), 'PASSWORD',    'REDACT'),
    (re.compile(r'medical|diagnosis|prescription|patient|health',                              re.I), 'MEDICAL',     'HASH'),
]


def classify_column(column_name: str) -> tuple[str, str]:
    """Returns (pii_type, default_mask_type) for a column name."""
    for pattern, pii_type, mask_type in _PII_PATTERNS:
        if pattern.search(column_name):
            return pii_type, mask_type
    return 'GENERIC', 'HASH'

# ── DB helpers ────────────────────────────────────────────────────────────────

def _get_conn():
    return psycopg2.connect(get_connection_string())


def _load_rules() -> dict:
    """Load active masking rules from DB into cache keyed by (server, table, col_lower)."""
    global _RULE_CACHE, _CACHE_LOADED_AT
    try:
        conn = _get_conn()
        cur  = conn.cursor()
        cur.execute(
            """
            SELECT server_name, table_name, column_name,
                   pii_type, mask_type, allowed_roles
            FROM   config.masking_rules
            WHERE  is_active = TRUE
            """
        )
        rules = {}
        for server_name, table_name, column_name, pii_type, mask_type, allowed_roles in cur.fetchall():
            key = (server_name.lower(), table_name.lower(), column_name.lower())
            rules[key] = {
                "pii_type":     pii_type,
                "mask_type":    mask_type,
                "allowed_roles": set(r.lower() for r in (allowed_roles or [])),
            }
        cur.close()
        conn.close()
        _RULE_CACHE      = rules
        _CACHE_LOADED_AT = time.time()
    except Exception as e:
        db_write_log(f"data_masking_engine: _load_rules failed: {e}", 0, "data_masking_engine", "")
    return _RULE_CACHE


def _get_rules() -> dict:
    if time.time() - _CACHE_LOADED_AT > _CACHE_TTL:
        _load_rules()
    return _RULE_CACHE

# ── Masking functions ─────────────────────────────────────────────────────────

def _mask_redact(_value: str, _pii_type: str) -> str:
    return "***REDACTED***"


def _mask_partial(value: str, pii_type: str) -> str:
    s = str(value)
    if not s:
        return "***"

    if pii_type == "CREDIT_CARD":
        digits = re.sub(r'\D', '', s)
        last4  = digits[-4:] if len(digits) >= 4 else digits
        return f"****-****-****-{last4}"

    if pii_type == "SSN":
        digits = re.sub(r'\D', '', s)
        last4  = digits[-4:] if len(digits) >= 4 else digits
        return f"***-**-{last4}"

    if pii_type == "EMAIL":
        if "@" in s:
            local, domain = s.split("@", 1)
            masked_local  = (local[:2] + "***") if len(local) > 2 else "***"
            return f"{masked_local}@{domain}"
        return s[:2] + "***"

    if pii_type == "PHONE":
        digits = re.sub(r'\D', '', s)
        last4  = digits[-4:] if len(digits) >= 4 else digits
        return "*" * max(len(s) - 4, 0) + last4

    if pii_type == "DOB":
        # Keep year only: ****-**-1985 or just the year if parseable
        parts = re.split(r'[-/.]', s)
        if len(parts) == 3:
            # Try to find the 4-digit year part
            year = next((p for p in parts if len(p) == 4 and p.isdigit()), None)
            if year:
                return f"****-**-{year}" if parts[-1] == year else f"{year}-**-**"
        if len(s) >= 4:
            return "****-**-" + s[-4:]
        return "****"

    if pii_type == "NAME":
        return (s[0] + "***") if s else "***"

    # Default: show last 2 characters
    if len(s) > 2:
        return "*" * (len(s) - 2) + s[-2:]
    return "***"


def _mask_hash(value: str, _pii_type: str) -> str:
    h = hashlib.sha256(str(value).encode("utf-8")).hexdigest()
    return h[:12]


def _mask_tokenize(value: str, pii_type: str) -> str:
    """Return a stable token from config.masking_tokens. Creates one on first use."""
    original_hash = hashlib.sha256(str(value).encode("utf-8")).hexdigest()
    try:
        conn = _get_conn()
        cur  = conn.cursor()

        cur.execute(
            "SELECT token FROM config.masking_tokens WHERE pii_type=%s AND original_hash=%s",
            (pii_type, original_hash),
        )
        row = cur.fetchone()
        if row:
            token = row[0]
        else:
            # Generate a stable random token (16 alphanumeric chars)
            alphabet = string.ascii_uppercase + string.digits
            token    = "TKN-" + "".join(secrets.choice(alphabet) for _ in range(12))
            cur.execute(
                "INSERT INTO config.masking_tokens (pii_type, original_hash, token) "
                "VALUES (%s,%s,%s) ON CONFLICT DO NOTHING",
                (pii_type, original_hash, token),
            )
            conn.commit()

        cur.close()
        conn.close()
        return token
    except Exception as e:
        db_write_log(f"data_masking_engine: tokenize failed: {e}", 0, "data_masking_engine", "")
        return _mask_hash(value, pii_type)


_MASK_FN = {
    "REDACT":   _mask_redact,
    "PARTIAL":  _mask_partial,
    "HASH":     _mask_hash,
    "TOKENIZE": _mask_tokenize,
}


def _apply_mask(value, mask_type: str, pii_type: str):
    if value is None:
        return None
    fn = _MASK_FN.get(mask_type, _mask_hash)
    try:
        return fn(str(value), pii_type)
    except Exception:
        return "***"

# ── Public API ────────────────────────────────────────────────────────────────

def apply_masking(
    rows:        list,
    columns:     list[str],
    server_name: str,
    db_user:     str      = "",
    db_name:     str      = "",
    user_roles:  list[str] = None,
) -> list:
    """
    Apply column-level masking to a result set.

    Parameters
    ----------
    rows        : list of tuples/lists returned by cursor.fetchall()
    columns     : column names in the same order as rows values
    server_name : monitored server name (matched against masking_rules)
    db_user     : login name — used to check allowed_roles bypass
    db_name     : database/schema context (used for rule lookup refinement)
    user_roles  : list of roles the db_user holds

    Returns
    -------
    List of tuples with sensitive columns replaced by masked values.
    If no masking rules match any column, returns rows unchanged.
    """
    if not rows or not columns:
        return rows

    if user_roles is None:
        user_roles = []

    user_roles_lower = {r.lower() for r in user_roles}
    if db_user:
        user_roles_lower.add(db_user.lower())

    rules       = _get_rules()
    server_low  = (server_name or "").lower()
    col_lowers  = [c.lower() for c in columns]

    # Build masking plan: list of (col_index, mask_type, pii_type) for columns that need masking
    plan: list[tuple[int, str, str]] = []
    for idx, col in enumerate(col_lowers):
        # Try server-specific rule first, then wildcard server ""
        rule = rules.get((server_low, "", col)) or rules.get(("", "", col))

        # Also check without server prefix (rule may have been loaded without table context)
        if rule is None:
            # Fall back to pure column-name classification if column looks sensitive
            pii_type, default_mask = classify_column(col)
            if pii_type != 'GENERIC':
                # Only auto-mask if there is NO explicit allow listed for this user
                rule = {"pii_type": pii_type, "mask_type": default_mask, "allowed_roles": set()}

        if rule is None:
            continue

        # Skip masking if this user/role is in the allow list
        if rule["allowed_roles"] & user_roles_lower:
            continue

        plan.append((idx, rule["mask_type"], rule["pii_type"]))

    if not plan:
        return rows

    masked_rows = []
    for row in rows:
        row_list = list(row)
        for idx, mask_type, pii_type in plan:
            row_list[idx] = _apply_mask(row_list[idx], mask_type, pii_type)
        masked_rows.append(tuple(row_list))

    return masked_rows


def reload_rule_cache():
    """Force an immediate cache refresh — call after masking rule changes."""
    global _CACHE_LOADED_AT
    _CACHE_LOADED_AT = 0.0
    _load_rules()

# ── Sync job (hourly) ─────────────────────────────────────────────────────────

def sync_masking_rules():
    """
    Scheduled hourly job.
    Inserts any newly discovered sensitive columns from monitoring.sensitive_schema
    into config.masking_rules, then reloads the rule cache.
    """
    try:
        conn = _get_conn()
        cur  = conn.cursor()
        cur.execute(
            """
            INSERT INTO config.masking_rules
                (server_name, database_name, table_name, column_name, pii_type, mask_type, regulation)
            SELECT
                ss.server,
                ss.database_name,
                ss.table_name,
                ss.column_name,
                COALESCE(ss.pii_type, 'GENERIC'),
                COALESCE(ss.mask_type, 'HASH'),
                CASE
                    WHEN ss.pii_type IN ('CREDIT_CARD','SSN')                   THEN 'PCI-DSS'
                    WHEN ss.pii_type = 'MEDICAL'                                THEN 'HIPAA'
                    WHEN ss.pii_type IN ('EMAIL','NAME','DOB','ADDRESS','SALARY') THEN 'GDPR'
                    ELSE 'internal'
                END
            FROM monitoring.sensitive_schema ss
            ON CONFLICT (server_name, table_name, column_name) DO UPDATE
                SET pii_type   = EXCLUDED.pii_type,
                    mask_type  = EXCLUDED.mask_type,
                    updated_at = NOW()
            """
        )
        new_rows = cur.rowcount
        conn.commit()
        cur.close()
        conn.close()

        reload_rule_cache()
        db_write_log(
            f"sync_masking_rules: {new_rows} rules upserted, cache reloaded",
            0, "data_masking_engine", "",
        )
    except Exception as e:
        db_write_log(f"sync_masking_rules failed: {e}", 0, "data_masking_engine", "")
