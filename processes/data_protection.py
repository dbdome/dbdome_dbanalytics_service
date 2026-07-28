"""
Data-protection processes (SQL Server) — implements the controls in
docs/MSSQL-RBAC-DataProtection-Deliverable.md on a caller-chosen target.

Selection model: server -> database -> (table + column).
  * Dynamic / static masking: the caller picks the COLUMN and the FUNCTION.
  * Tokenization:             the caller picks the encryption type.

This module starts with DYNAMIC DATA MASKING (deliverable §4.3): a native,
non-destructive control (plaintext stays in the table, masked on display for
principals without UNMASK). Static masking, tokenization and anonymization plug
into the same framework (shared target resolution + audit) and are added next.

Connection + credentials are resolved from metrics.servers exactly like RBAC.
Every action is audited to metrics.dp_log.
"""
import re
import random
import string
import pyodbc
from datetime import datetime

from processes.rbac_provisioning import _resolve_mssql, _connect   # shared target helpers
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
import psycopg2
from psycopg2.extras import execute_values

# Allow-listed Dynamic Data Masking functions (validated before inlining, so a
# caller-supplied FUNCTION string can never inject SQL). Covers the four DDM
# function families (deliverable §4.3).
_MASK_FUNCS = [
    re.compile(r"^default\(\)$", re.I),
    re.compile(r"^email\(\)$", re.I),
    re.compile(r"^random\(\s*-?\d+\s*,\s*-?\d+\s*\)$", re.I),
    re.compile(r'^partial\(\s*\d+\s*,\s*"[^"\';]*"\s*,\s*\d+\s*\)$', re.I),
]


def _valid_mask_function(fn):
    fn = (fn or "").strip()
    return fn if any(rx.match(fn) for rx in _MASK_FUNCS) else None


def _open(server, database):
    """Open a target connection in <database>, or raise."""
    info = _resolve_mssql(server)
    if not info:
        raise RuntimeError("no active MSSQL instance for this server")
    port, user, pw, _ddb = info
    return _connect(server, port, user, pw, database, timeout=300)


def _resolve_object(cur, schema, table, column):
    """Return (schema, table, column, type_name, char_cap) using the EXACT names
    from sys (existence-checked), or None. Validated names are safe to bracket-quote."""
    cur.execute(
        "SELECT s.name, t.name, c.name, ty.name, "
        "  CASE WHEN ty.name IN ('nvarchar','nchar') AND c.max_length>0 THEN c.max_length/2 "
        "       WHEN c.max_length<0 THEN 4000 ELSE c.max_length END "
        "FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id "
        "JOIN sys.schemas s ON s.schema_id=t.schema_id "
        "JOIN sys.types ty ON ty.user_type_id=c.user_type_id "
        "WHERE s.name=? AND t.name=? AND c.name=?", (schema, table, column))
    r = cur.fetchone()
    if not r:
        return None
    # defend against bracket break-out via crafted catalog names (paranoia)
    if any("]" in str(x) for x in (r[0], r[1], r[2])):
        return None
    return (r[0], r[1], r[2], r[3], int(r[4] or 0))


def _dp_log(server, database, schema, table, column, technique, status, detail):
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO metrics.dp_log (server, database_name, schema_name, table_name, "
                "column_name, technique, status, detail) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                (server, database, schema, table, column, technique, status, (detail or "")[:1000]))
        conn.close()
    except Exception as e:
        print("dp_log failed:", e)


def apply_dynamic_mask(server, database, schema, table, column, function):
    """Apply Dynamic Data Masking to <database>.<schema>.<table>.<column> using the
    caller-chosen <function> (default()/email()/random(a,b)/partial(p,"pad",s)).
    Idempotent: an existing mask on the column is dropped first so the function can
    change. Returns a result dict; audited to metrics.dp_log.
    <table> may be supplied as '<schema>.<table>'; the embedded schema then wins (so
    callers can omit a separate schema argument)."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database,
           "object": f"{schema}.{table}.{column}", "function": function,
           "status": None, "detail": None}

    func = _valid_mask_function(function)
    if not func:
        res["status"] = "error"; res["detail"] = f"unsupported mask function: {function!r}"
        _dp_log(server, database, schema, table, column, "dynamic_mask", "error", res["detail"])
        return res
    if not (server and database and schema and table and column):
        res["status"] = "error"; res["detail"] = "server, database, schema, table, column required"
        return res

    info = _resolve_mssql(server)
    if not info:
        res["status"] = "error"; res["detail"] = "no active MSSQL instance for this server"
        _dp_log(server, database, schema, table, column, "dynamic_mask", "error", res["detail"])
        return res
    port, user, pw, _ddb = info

    try:
        conn = _connect(server, port, user, pw, "master")
        cur = conn.cursor()
        # confirm the database exists (and is a real name) before targeting it
        cur.execute("SELECT name FROM sys.databases WHERE name = ?", (database,))
        row = cur.fetchone()
        if not row:
            res["status"] = "error"; res["detail"] = f"database '{database}' not found"
            _dp_log(server, database, schema, table, column, "dynamic_mask", "error", res["detail"])
            conn.close(); return res
        conn.close()

        # reconnect in the target database context and apply the mask
        conn = _connect(server, port, user, pw, database)
        cur = conn.cursor()
        body = (
            "DECLARE @sc sysname=?, @tb sysname=?, @col sysname=?;"
            "DECLARE @obj nvarchar(776) = QUOTENAME(@sc)+N'.'+QUOTENAME(@tb);"
            "DECLARE @c   nvarchar(258) = QUOTENAME(@col);"
            "DECLARE @sql nvarchar(max);"
            "IF EXISTS (SELECT 1 FROM sys.masked_columns mc "
            "  JOIN sys.tables t  ON t.object_id = mc.object_id "
            "  JOIN sys.schemas s ON s.schema_id = t.schema_id "
            "  WHERE s.name=@sc AND t.name=@tb AND mc.name=@col AND mc.is_masked=1) "
            "BEGIN "
            "  SET @sql = N'ALTER TABLE '+@obj+N' ALTER COLUMN '+@c+N' DROP MASKED'; "
            "  EXEC sys.sp_executesql @sql; "
            "END "
            "SET @sql = N'ALTER TABLE '+@obj+N' ALTER COLUMN '+@c+"
            "           N' ADD MASKED WITH (FUNCTION = ''" + func + "'')'; "
            "EXEC sys.sp_executesql @sql;"
        )
        cur.execute(body, (schema, table, column))
        while cur.nextset():
            pass
        conn.close()
        res["status"] = "ok"; res["detail"] = f"MASKED WITH (FUNCTION = '{func}')"
        _dp_log(server, database, schema, table, column, "dynamic_mask", "ok", res["detail"])
        db_write_log(f"dynamic_mask {server}/{database}/{schema}.{table}.{column} -> {func}",
                     0, "data_protection", server)
    except Exception as e:
        res["status"] = "error"; res["detail"] = str(e)[:300]
        _dp_log(server, database, schema, table, column, "dynamic_mask", "error", res["detail"])
    return res


def revert_dynamic_mask(server, database, schema, table, column):
    """Reverse Dynamic Data Masking: DROP MASKED on the column (plaintext was never
    altered, so the column is fully restored). Audited as revert_dynamic_mask.
    <table> may be '<schema>.<table>'; the embedded schema then wins."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}.{column}",
           "status": None, "detail": None}
    try:
        conn = _open(server, database); cur = conn.cursor()
        obj = _resolve_object(cur, schema, table, column)
        if not obj:
            conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
            _dp_log(server, database, schema, table, column, "revert_dynamic_mask", "error", res["detail"]); return res
        s, t, c, _ty, _cap = obj
        cur.execute(
            "IF EXISTS (SELECT 1 FROM sys.masked_columns mc "
            "  JOIN sys.tables t ON t.object_id=mc.object_id "
            "  JOIN sys.schemas s ON s.schema_id=t.schema_id "
            "  WHERE s.name=? AND t.name=? AND mc.name=? AND mc.is_masked=1) "
            f"ALTER TABLE [{s}].[{t}] ALTER COLUMN [{c}] DROP MASKED;", (s, t, c))
        conn.close()
        res.update(status="ok", detail="mask removed (DROP MASKED)")
        _dp_log(server, database, s, t, c, "revert_dynamic_mask", "ok", res["detail"])
        db_write_log(f"revert_dynamic_mask {server}/{database}/{s}.{t}.{c}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column, "revert_dynamic_mask", "error", res["detail"])
    return res


# constants for the destructive / vault controls
_ANON_SALT        = "dbdome-anon-salt-2026"
_TOKEN_PASSPHRASE = "Dbd0me#Tok3n!Vault2026"
_VAULT_DB         = "TokenVault"
_VAULT_KEY_PW     = "Vlt#MasterKey!2026"


def _shuffle_sql(s, t, c):
    """In-place random permutation of one column (keeps the value distribution,
    breaks the row->value link). Updatable CTE over the base table."""
    return (f";WITH src AS (SELECT [{c}] AS v, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM [{s}].[{t}]),"
            f"shf AS (SELECT [{c}] AS v, ROW_NUMBER() OVER (ORDER BY NEWID()) rn FROM [{s}].[{t}]) "
            f"UPDATE src SET v = shf.v FROM src JOIN shf ON src.rn = shf.rn;")


# ---------------------------------------------------------------------------
# STATIC MASKING (deliverable §5.1) — destructive, for NON-PRODUCTION copies.
# Caller selects column + function.
# ---------------------------------------------------------------------------
def static_mask(server, database, schema, table, column, function):
    """Permanently replace <column> values. function:
    null | default | fixed:<value> | shuffle | partial(p,"pad",s).  DESTRUCTIVE.
    <table> may be '<schema>.<table>'; the embedded schema then wins."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}.{column}",
           "function": function, "status": None, "detail": None}
    fn = (function or "").strip()
    if not all([server, database, schema, table, column]):
        res.update(status="error", detail="server, database, schema, table, column required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        obj = _resolve_object(cur, schema, table, column)
        if not obj:
            conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
            _dp_log(server, database, schema, table, column, "static_mask", "error", res["detail"]); return res
        s, t, c, _ty, _cap = obj

        if fn.lower() == "shuffle":
            cur.execute(_shuffle_sql(s, t, c)); detail = "shuffled values"
        else:
            if fn.lower() == "null":
                expr = "NULL"; detail = "set NULL"
            elif fn.lower() == "default":
                expr = "''"; detail = "set empty string"
            elif fn.lower().startswith("fixed:"):
                expr = "N'" + fn[6:].replace("'", "''") + "'"; detail = "fixed value"
            else:
                m = re.match(r'^partial\(\s*(\d+)\s*,\s*"([^"\';]*)"\s*,\s*(\d+)\s*\)$', fn, re.I)
                if not m:
                    conn.close(); res.update(status="error", detail=f"unsupported static function: {function!r}")
                    _dp_log(server, database, schema, table, column, "static_mask", "error", res["detail"]); return res
                p, pad, sfx = int(m.group(1)), m.group(2).replace("'", "''"), int(m.group(3))
                expr = (f"LEFT(CONVERT(nvarchar(4000),[{c}]),{p})+N'{pad}'+"
                        f"RIGHT(CONVERT(nvarchar(4000),[{c}]),{sfx})")
                detail = f"partial keep {p}/{sfx}"
            cur.execute(f"UPDATE [{s}].[{t}] SET [{c}] = {expr};")
        rows = cur.rowcount
        conn.close()
        res.update(status="ok", detail=f"{detail} ({rows} rows)")
        _dp_log(server, database, s, t, c, "static_mask", "ok", res["detail"])
        db_write_log(f"static_mask {server}/{database}/{s}.{t}.{c} {fn} rows={rows}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column, "static_mask", "error", res["detail"])
    return res


# ---------------------------------------------------------------------------
# ANONYMIZATION (deliverable §5.2) — irreversible, for NON-PRODUCTION.
# Caller selects column + technique.
# ---------------------------------------------------------------------------
_ANON_DATE_TYPES = ("date", "datetime", "datetime2", "smalldatetime", "datetimeoffset")


def _anon_expr(c, ty, cap, tq):
    """SET expression + label for one column under technique tq, or (None, None)."""
    if tq == "suppress":
        return "NULL", "suppressed (NULL)"
    if tq == "substitute":
        width = cap if cap and cap > 0 else 50
        return (f"LEFT(N'anon_'+CONVERT(nvarchar(20),ABS(CHECKSUM(NEWID()))),{width})",
                "substituted with fake value")
    if tq == "generalize":
        if ty in _ANON_DATE_TYPES:
            return f"DATEFROMPARTS(YEAR([{c}]),1,1)", "generalized to year"
        return f"LEFT(CONVERT(nvarchar(4000),[{c}]),1)+N'XXX'", "generalized"
    if tq == "hash":
        cap2 = min(cap if cap and cap > 0 else 64, 64)
        return (f"LEFT(CONVERT(varchar(64),HASHBYTES('SHA2_256',"
                f"CONVERT(nvarchar(4000),CONCAT(N'{_ANON_SALT}',[{c}]))),2),{cap2})",
                "salted SHA-256 hash")
    return None, None


def _big_varchar_columns(cur, schema, table, min_len):
    """Character columns in <schema>.<table> that are 'big': varchar/nvarchar(MAX)
    or declared length >= min_len. Returns [(name, type_name, char_cap)] in column
    order. Names are catalog-sourced and bracket-safe (']' rejected)."""
    cur.execute(
        "SELECT c.name, ty.name, "
        " CASE WHEN ty.name IN ('nvarchar','nchar') AND c.max_length>0 THEN c.max_length/2 "
        "      WHEN c.max_length<0 THEN 4000 ELSE c.max_length END AS char_len "
        "FROM sys.columns c "
        "JOIN sys.tables t  ON t.object_id=c.object_id "
        "JOIN sys.schemas s ON s.schema_id=t.schema_id "
        "JOIN sys.types ty  ON ty.user_type_id=c.user_type_id "
        "WHERE s.name=? AND t.name=? AND c.is_computed=0 "
        "  AND ty.name IN ('varchar','nvarchar','char','nchar') "
        "  AND (c.max_length<0 OR (CASE WHEN ty.name IN ('nvarchar','nchar') AND c.max_length>0 "
        "       THEN c.max_length/2 ELSE c.max_length END) >= ?) "
        "ORDER BY c.column_id", (schema, table, min_len))
    return [(r[0], r[1], int(r[2] or 0)) for r in cur.fetchall() if "]" not in str(r[0])]


# ---------------------------------------------------------------------------
# FORMAT-PRESERVING ("realistic") anonymization. Per-row, per-character random
# replacement that keeps the original LENGTH and SHAPE, chosen by column name:
#   card number / account / PAN / SSN / CVV -> random digits (separators kept)
#   phone / mobile / fax                     -> random digits (separators kept)
#   email / mail                             -> random local@domain.tld
#   first/last/full name, card holder        -> random letters, same case, spaces kept
#   (explicit column with no name match)     -> generic same-shape random
# Done in Python (not T-SQL) so length/shape/case are preserved exactly.
# ---------------------------------------------------------------------------
_REALISTIC_RULES = [
    (re.compile(r"cvv|cvc|cv2|csc|security_?code", re.I),                      "digits"),
    (re.compile(r"card.*num|num.*card|card_?no|\bpan\b|account_?num|\biban\b|\bssn\b", re.I), "digits"),
    (re.compile(r"phone|mobile|cell|tel\b|telephone|fax|msisdn|whatsapp", re.I), "phone"),
    (re.compile(r"e[-_]?mail", re.I),                                          "email"),
    (re.compile(r"first_?name|last_?name|sur_?name|given_?name|family_?name|"
                r"full_?name|card_?hold|card_?old|cardhold|holder|customer_?name|"
                r"contact_?name|\bname\b", re.I),                              "name"),
]


def _realistic_rule(colname):
    """Classify a column NAME into a format-preserving rule, or None."""
    for rx, rule in _REALISTIC_RULES:
        if rx.search(colname or ""):
            return rule
    return None


def _rand_like_char(ch):
    """Random char of the SAME class/case as ch (letter->letter, digit->digit);
    anything else (space, separator, punctuation) is kept verbatim."""
    if ch.isupper() and ch.isalpha(): return random.choice(string.ascii_uppercase)
    if ch.islower() and ch.isalpha(): return random.choice(string.ascii_lowercase)
    if ch.isdigit():                  return random.choice("0123456789")
    return ch


def _rand_digit(ch):
    return random.choice("0123456789") if ch.isdigit() else ch


def _rand_email(s):
    """Random email preserving an @ and a dot. Keeps the local/domain lengths and
    separators of the original when it looks like an email; otherwise builds one."""
    s = (s or "").strip()
    if "@" in s:
        local, _, domain = s.partition("@")
        local = "".join(_rand_like_char(c) for c in local) or "u"
        domain = "".join(_rand_like_char(c) for c in domain)
        if "." not in domain:
            domain = (domain or "ex") + ".com"
        return local + "@" + domain
    loc = "".join(random.choice(string.ascii_lowercase) for _ in range(max(len(s) - 8, 3)))
    return loc + "@example.com"


def _realistic_value(rule, val):
    """Anonymize one value under <rule>, preserving length/shape. NULL stays NULL."""
    if val is None:
        return None
    s = str(val)
    if rule == "name":
        return "".join(_rand_like_char(c) if c.isalpha() else c for c in s)
    if rule == "email":
        return _rand_email(s)
    if rule in ("digits", "phone"):
        return "".join(_rand_digit(c) for c in s)
    return "".join(_rand_like_char(c) for c in s)        # generic same-shape


_CHAR_TYPES = ("varchar", "nvarchar", "char", "nchar")


def _realistic_columns(cur, schema, table):
    """Character columns whose NAME matches a realistic rule.
    Returns [(name, type_name, char_cap, rule)] in column order."""
    cur.execute(
        "SELECT c.name, ty.name, "
        " CASE WHEN ty.name IN ('nvarchar','nchar') AND c.max_length>0 THEN c.max_length/2 "
        "      WHEN c.max_length<0 THEN 4000 ELSE c.max_length END "
        "FROM sys.columns c "
        "JOIN sys.tables t  ON t.object_id=c.object_id "
        "JOIN sys.schemas s ON s.schema_id=t.schema_id "
        "JOIN sys.types ty  ON ty.user_type_id=c.user_type_id "
        "WHERE s.name=? AND t.name=? AND c.is_computed=0 "
        "  AND ty.name IN ('varchar','nvarchar','char','nchar') "
        "ORDER BY c.column_id", (schema, table))
    out = []
    for r in cur.fetchall():
        if "]" in str(r[0]):
            continue
        rule = _realistic_rule(r[0])
        if rule:
            out.append((r[0], r[1], int(r[2] or 0), rule))
    return out


def _apply_realistic(cur, s, t, targets, chunk=2000):
    """Row-wise format-preserving anonymization. targets: [(col, type, cap, rule)].
    Adds a temporary surrogate key (plain BIGINT populated by ROW_NUMBER, so it works
    even when the table already has an identity column from SELECT INTO), updates each
    row by that key, then drops it. Returns (rows_updated, [col names])."""
    cols = [c for (c, _ty, _cap, _r) in targets]
    rule_of = {c: r for (c, _ty, _cap, r) in targets}
    rid = "__anon_rid"
    cur.execute(f"IF COL_LENGTH('[{s}].[{t}]','{rid}') IS NULL "
                f"ALTER TABLE [{s}].[{t}] ADD [{rid}] BIGINT NULL;")
    cur.execute(f";WITH cte AS (SELECT [{rid}], ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn "
                f"FROM [{s}].[{t}]) UPDATE cte SET [{rid}] = rn;")
    sel = ", ".join(f"[{c}]" for c in cols)
    cur.execute(f"SELECT [{rid}], {sel} FROM [{s}].[{t}];")
    rows = cur.fetchall()
    params = [tuple(_realistic_value(rule_of[cols[i]], r[i + 1]) for i in range(len(cols))) + (r[0],)
              for r in rows]
    set_clause = ", ".join(f"[{c}]=?" for c in cols)
    upd = f"UPDATE [{s}].[{t}] SET {set_clause} WHERE [{rid}]=?;"
    try:
        cur.fast_executemany = True
    except Exception:
        pass
    for i in range(0, len(params), chunk):
        cur.executemany(upd, params[i:i + chunk])
    cur.execute(f"ALTER TABLE [{s}].[{t}] DROP COLUMN [{rid}];")
    return len(rows), cols


def anonymize(server, database, schema, table, column, technique, min_len=100):
    """Irreversibly transform character data. technique:
    suppress | substitute | generalize | shuffle | hash | realistic.  DESTRUCTIVE.
    'realistic' = format-preserving fake data (same length/shape) chosen by column
    name: card/account/cvv/ssn & phone -> random digits; email -> random address;
    names & card holder -> random letters (case + spaces kept).

    If <column> is given, only that column is anonymized. If <column> is empty,
    EVERY 'big' character column (varchar/nvarchar/char/nchar of length >= min_len,
    or MAX) in <schema>.<table> is anonymized. <table> may be passed as
    'schema.table'; the embedded schema then overrides the <schema> argument."""
    tq = (technique or "suppress").strip().lower()
    # accept table supplied as "<schema>.<table>"
    if table and "." in table:
        parts = table.replace("[", "").replace("]", "").split(".")
        if len(parts) == 2 and parts[0].strip() and parts[1].strip():
            schema, table = parts[0].strip(), parts[1].strip()
    obj_label = f"{schema}.{table}" + (f".{column}" if column else " (all big varchars)")
    res = {"server": server, "database": database, "object": obj_label,
           "technique": tq, "status": None, "detail": None}
    if not all([server, database, schema, table]):
        res.update(status="error", detail="server, database, schema, table required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()

        if tq == "realistic":
            if column:
                obj = _resolve_object(cur, schema, table, column)
                if not obj:
                    conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
                    _dp_log(server, database, schema, table, column, "anonymize", "error", res["detail"]); return res
                s, t, _c, ty, cap = obj
                if ty not in _CHAR_TYPES:
                    conn.close(); res.update(status="error", detail=f"realistic supports character columns only; {_c} is {ty}")
                    _dp_log(server, database, s, t, _c, "anonymize", "error", res["detail"]); return res
                rtargets = [(_c, ty, cap, _realistic_rule(_c) or "format")]
            else:
                s, t = schema, table
                rtargets = _realistic_columns(cur, schema, table)
                if not rtargets:
                    conn.close()
                    res.update(status="ok", detail=f"no card/name/email/phone-like character columns in {schema}.{table}")
                    _dp_log(server, database, schema, table, "", "anonymize", "ok", res["detail"]); return res
            rows, done = _apply_realistic(cur, s, t, rtargets)
            conn.close()
            for (c, _ty, _cap, rule) in rtargets:
                _dp_log(server, database, s, t, c, "anonymize", "ok", f"realistic/{rule} ({rows} rows)")
            res.update(status="ok",
                       detail=f"realistic: {len(done)} column(s) [{', '.join(done)}] ~{rows} rows")
            db_write_log(f"anonymize {server}/{database}/{s}.{t} realistic cols={len(done)} ({', '.join(done)})",
                         0, "data_protection", server)
            return res

        if column:
            obj = _resolve_object(cur, schema, table, column)
            if not obj:
                conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
                _dp_log(server, database, schema, table, column, "anonymize", "error", res["detail"]); return res
            s, t, _c, ty, cap = obj
            targets = [(_c, ty, cap)]
        else:
            s, t = schema, table
            targets = _big_varchar_columns(cur, schema, table, min_len)
            if not targets:
                conn.close()
                res.update(status="ok", detail=f"no big character columns (>= {min_len} chars) in {schema}.{table}")
                _dp_log(server, database, schema, table, "", "anonymize", "ok", res["detail"]); return res

        done, rows = [], 0
        for (c, ty, cap) in targets:
            if tq == "shuffle":
                cur.execute(_shuffle_sql(s, t, c)); detail = "shuffled"
            else:
                expr, detail = _anon_expr(c, ty, cap, tq)
                if expr is None:
                    conn.close(); res.update(status="error", detail=f"unsupported technique: {technique!r}")
                    _dp_log(server, database, s, t, "", "anonymize", "error", res["detail"]); return res
                cur.execute(f"UPDATE [{s}].[{t}] SET [{c}] = {expr};")
            rows = cur.rowcount
            done.append(c)
            _dp_log(server, database, s, t, c, "anonymize", "ok", f"{detail} ({cur.rowcount} rows)")
        conn.close()
        res.update(status="ok",
                   detail=f"{tq}: {len(done)} column(s) [{', '.join(done)}] ~{rows} rows")
        db_write_log(f"anonymize {server}/{database}/{s}.{t} {tq} cols={len(done)} ({', '.join(done)})",
                     0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column or "", "anonymize", "error", res["detail"])
    return res


# ---------------------------------------------------------------------------
# STAGED ANONYMISATION (copy -> switch -> archive). Run in order:
#   anonymize_pre     : copy <schema>.<table> to <table>_<yyyyMMddHHmmss>, anonymize
#                       the COPY (all big varchars). Original left intact.
#   anonymize_actual  : switch the live table with its latest pre-copy (3-way rename
#                       swap). Live <table> = anonymized; original now under the dated
#                       copy name. Re-running switches back.
#   anonymize_confirm : create the backup schema if needed and move the original
#                       (the dated copy left by anonymize_actual) into it.
# ---------------------------------------------------------------------------
_BACKUP_SCHEMA = "dbdome_backup"


def _ident_ok(n):
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", n or ""))


def _split_schema_table(schema, table):
    """Allow <table> supplied as '<schema>.<table>' (embedded schema wins)."""
    if table and "." in table:
        parts = table.replace("[", "").replace("]", "").split(".")
        if len(parts) == 2 and parts[0].strip() and parts[1].strip():
            return parts[0].strip(), parts[1].strip()
    return schema, table


def _table_exists(cur, schema, table):
    cur.execute("SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id "
                "WHERE s.name=? AND t.name=?", (schema, table))
    return bool(cur.fetchone()[0])


def _pre_copies(cur, schema, table):
    """Dated pre-copies of <table> in <schema>, oldest..newest by name."""
    cur.execute("SELECT t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id "
                "WHERE s.name=?", (schema,))
    pat = re.compile("^" + re.escape(table) + r"_\d{14}$")
    return sorted(r[0] for r in cur.fetchall() if pat.match(r[0]))


# ---------------------------------------------------------------------------
# Mirror the anonymized dry-run copy into LOCAL Postgres for review / Grafana.
# Target: <_PG_ANON_SCHEMA>.<server>_<database>_<table>_<yyyyMMddHHmmss>
# in the dbanalytics DB (get_connection_string()).
# ---------------------------------------------------------------------------
_PG_ANON_SCHEMA = "anonymization"


def _pg_ident(s):
    """Sanitize an arbitrary name into a safe lowercase Postgres identifier token."""
    s = re.sub(r"[^A-Za-z0-9_]", "_", (s or ""))
    return re.sub(r"_+", "_", s).strip("_").lower()


def _pg_target_name(server, database, copy):
    """Build <server>_<database>_<copy> as a <=63-char Postgres identifier. <copy>
    already carries the <table>_<datetime> tail, which is preserved when trimming."""
    tail = _pg_ident(copy)
    prefix = _pg_ident(f"{server}_{database}")
    name = f"{prefix}_{tail}" if prefix else tail
    if len(name) > 63:                       # keep the unique table_datetime tail intact
        keep = max(63 - len(tail) - 1, 0)
        prefix = prefix[:keep].rstrip("_")
        name = (f"{prefix}_{tail}" if prefix else tail)[:63]
    if not re.match(r"^[A-Za-z_]", name):
        name = ("t_" + name)[:63]
    return name


def _pg_coltype(type_code):
    """Map a pyodbc cursor.description Python type to a Postgres column type."""
    import datetime as _dt
    from decimal import Decimal
    if type_code is _dt.datetime: return "timestamp"
    if type_code is _dt.date:     return "date"
    if type_code is _dt.time:     return "time"
    if type_code is Decimal:      return "numeric"
    if type_code is bool:         return "boolean"
    if type_code is int:          return "bigint"
    if type_code is float:        return "double precision"
    if type_code in (bytes, bytearray): return "bytea"
    return "text"


def _load_copy_to_postgres(server, database, schema, copy, batch=5000):
    """Copy the anonymized dry-run table [schema].[copy] from the SQL Server source
    into local Postgres <_PG_ANON_SCHEMA>.<server>_<database>_<copy> (recreated each
    run). Returns (pg_qualified_name, rows_loaded)."""
    src = _open(server, database); scur = src.cursor()
    try:
        scur.execute(f"SELECT * FROM [{schema}].[{copy}]")
        desc = scur.description or []
        seen, pgcols = {}, []
        for c in desc:                       # sanitize + dedupe column names, keep order
            nm = _pg_ident(c[0]) or "col"
            if nm in seen:
                seen[nm] += 1; nm = f"{nm}_{seen[nm]}"
            else:
                seen[nm] = 0
            pgcols.append((nm, _pg_coltype(c[1])))

        tbl = _pg_target_name(server, database, copy)
        coldefs = ", ".join(f'"{n}" {t}' for n, t in pgcols)
        collist = ", ".join(f'"{n}"' for n, _ in pgcols)
        insert = (f'INSERT INTO "{_PG_ANON_SCHEMA}"."{tbl}" ({collist}) VALUES %s'
                  if pgcols else None)

        pg = psycopg2.connect(get_connection_string()); pg.autocommit = True
        try:
            with pg.cursor() as cur:
                cur.execute(f'CREATE SCHEMA IF NOT EXISTS "{_PG_ANON_SCHEMA}"')
                cur.execute(f'DROP TABLE IF EXISTS "{_PG_ANON_SCHEMA}"."{tbl}"')
                cur.execute(f'CREATE TABLE "{_PG_ANON_SCHEMA}"."{tbl}" ({coldefs or "dummy text"})')
                total = 0
                if insert:
                    while True:
                        rows = scur.fetchmany(batch)
                        if not rows:
                            break
                        execute_values(cur, insert, [tuple(r) for r in rows])
                        total += len(rows)
        finally:
            pg.close()
        return f"{_PG_ANON_SCHEMA}.{tbl}", total
    finally:
        src.close()


def anonymize_pre(server, database, schema, table, technique="realistic", min_len=100):
    """Phase 1: copy <schema>.<table> to <table>_<yyyyMMddHHmmss> and anonymize the
    COPY. Default technique is 'realistic' (format-preserving by column name).
    The original is left untouched for review.
    NOTE: SELECT INTO copies data + column types/identity, NOT indexes, constraints,
    defaults or triggers. Returns the new copy name in res['copy']."""
    tq = (technique or "realistic").strip().lower()
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}",
           "technique": tq, "status": None, "detail": None, "copy": None, "pg_table": None}
    if not all([server, database, schema, table]) or "]" in (schema + table):
        res.update(status="error", detail="valid server, database, schema, table required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        if not _table_exists(cur, schema, table):
            conn.close(); res.update(status="error", detail=f"{schema}.{table} not found")
            _dp_log(server, database, schema, table, "", "anonymize_pre", "error", res["detail"]); return res
        copy = f"{table}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        cur.execute(f"IF OBJECT_ID(N'[{schema}].[{copy}]',N'U') IS NOT NULL DROP TABLE [{schema}].[{copy}];")
        cur.execute(f"SELECT * INTO [{schema}].[{copy}] FROM [{schema}].[{table}];")
        copied = cur.rowcount
        conn.close()
        a = anonymize(server, database, schema, copy, "", tq, min_len)   # all big varchars on the COPY
        detail = f"copied {copied} rows -> {schema}.{copy}; anonymize: {a.get('detail')}"
        # Mirror the anonymized copy into local Postgres (anonymization schema). A load
        # failure must not flip the on-source anonymize result, but is reported.
        if a.get("status") != "error":
            try:
                pg_tbl, pg_rows = _load_copy_to_postgres(server, database, schema, copy)
                res["pg_table"] = pg_tbl
                detail += f"; pg: {pg_rows} rows -> {pg_tbl}"
            except Exception as pe:
                detail += f"; pg load FAILED: {str(pe)[:200]}"
        res.update(status=a.get("status"), copy=f"{schema}.{copy}", detail=detail)
        _dp_log(server, database, schema, copy, "", "anonymize_pre", res["status"], res["detail"])
        db_write_log(f"anonymize_pre {server}/{database}/{schema}.{table} -> {copy} ({tq})", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, "", "anonymize_pre", "error", res["detail"])
    return res


def anonymize_actual(server, database, schema, table):
    """Phase 2: switch the live <schema>.<table> with its most recent anonymize_pre
    copy via a 3-way sp_rename swap. The anonymized copy becomes <table>; the previous
    <table> is preserved under the copy's dated name. Re-running switches back."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}",
           "status": None, "detail": None, "switched_with": None}
    if not all([server, database, schema, table]) or "]" in (schema + table):
        res.update(status="error", detail="valid server, database, schema, table required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        if not _table_exists(cur, schema, table):
            conn.close(); res.update(status="error", detail=f"{schema}.{table} not found")
            _dp_log(server, database, schema, table, "", "anonymize_actual", "error", res["detail"]); return res
        copies = _pre_copies(cur, schema, table)
        if not copies:
            conn.close(); res.update(status="error", detail=f"no anonymize_pre copy found for {schema}.{table}")
            _dp_log(server, database, schema, table, "", "anonymize_actual", "error", res["detail"]); return res
        partner = copies[-1]
        tmp = f"{table}__swaptmp_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{table}]", tmp))
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{partner}]", table))
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{tmp}]", partner))
        conn.close()
        res.update(status="ok", switched_with=f"{schema}.{partner}",
                   detail=f"switched {schema}.{table} <-> {schema}.{partner} (live now = anonymized copy)")
        _dp_log(server, database, schema, table, "", "anonymize_actual", "ok", res["detail"])
        db_write_log(f"anonymize_actual {server}/{database}/{schema}.{table} <-> {partner}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, "", "anonymize_actual", "error", res["detail"])
    return res


def anonymize_confirm(server, database, schema, table, backup_schema=_BACKUP_SCHEMA):
    """Phase 3: archive the original. Create <backup_schema> on the same database if
    missing, then move the original (the dated copy left in <schema> by
    anonymize_actual) into it via ALTER SCHEMA TRANSFER. The working schema then keeps
    only the anonymized <table>; the original lives in <backup_schema>."""
    schema, table = _split_schema_table(schema, table)
    bsch = (backup_schema or _BACKUP_SCHEMA).strip() or _BACKUP_SCHEMA
    res = {"server": server, "database": database, "object": f"{schema}.{table}",
           "backup_schema": bsch, "status": None, "detail": None, "archived": None}
    if not all([server, database, schema, table]) or "]" in (schema + table) or not _ident_ok(bsch):
        res.update(status="error", detail="valid server, database, schema, table, backup_schema required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        copies = _pre_copies(cur, schema, table)
        if not copies:
            conn.close(); res.update(status="error", detail=f"no dated copy of {schema}.{table} to archive")
            _dp_log(server, database, schema, table, "", "anonymize_confirm", "error", res["detail"]); return res
        old = copies[-1]
        cur.execute(f"IF SCHEMA_ID(N'{bsch}') IS NULL EXEC('CREATE SCHEMA [{bsch}]');")
        cur.execute("SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id "
                    "WHERE s.name=? AND t.name=?", (bsch, old))
        if cur.fetchone()[0]:
            conn.close(); res.update(status="error", detail=f"[{bsch}].[{old}] already exists; archive aborted")
            _dp_log(server, database, schema, table, "", "anonymize_confirm", "error", res["detail"]); return res
        cur.execute(f"ALTER SCHEMA [{bsch}] TRANSFER [{schema}].[{old}];")
        conn.close()
        res.update(status="ok", archived=f"{bsch}.{old}",
                   detail=f"original archived: [{schema}].[{old}] -> [{bsch}].[{old}]")
        _dp_log(server, database, schema, table, "", "anonymize_confirm", "ok", res["detail"])
        db_write_log(f"anonymize_confirm {server}/{database}/{schema}.{table} -> {bsch}.{old}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, "", "anonymize_confirm", "error", res["detail"])
    return res


def preview_copy(server, database, schema, table, rows=50, copy=None):
    """Read-only preview of the anonymized dry-run copy. Picks the latest
    <table>_<yyyyMMddHHmmss> in <schema> (or the explicit <copy>) and returns
    SELECT TOP <rows> * as {columns, rows}. <rows> is capped to 500."""
    schema, table = _split_schema_table(schema, table)
    try:
        rows = max(1, min(int(rows), 500))
    except (TypeError, ValueError):
        rows = 50
    res = {"server": server, "database": database, "object": f"{schema}.{table}",
           "copy": None, "columns": [], "rows": [], "count": 0, "status": None, "detail": None}
    if not all([server, database, schema, table]) or "]" in (schema + table):
        res.update(status="error", detail="valid server, database, schema, table required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        if copy:
            copy = copy.split(".")[-1].replace("[", "").replace("]", "").strip()
            if not _table_exists(cur, schema, copy):
                conn.close(); res.update(status="error", detail=f"{schema}.{copy} not found"); return res
        else:
            copies = _pre_copies(cur, schema, table)
            if not copies:
                conn.close(); res.update(status="error", detail=f"no anonymize_pre copy found for {schema}.{table}"); return res
            copy = copies[-1]
        res["copy"] = f"{schema}.{copy}"
        cur.execute(f"SELECT TOP {rows} * FROM [{schema}].[{copy}];")
        res["columns"] = [d[0] for d in cur.description] if cur.description else []
        res["rows"] = [[(None if v is None else str(v)) for v in r] for r in cur.fetchall()]
        res["count"] = len(res["rows"])
        conn.close()
        res.update(status="ok", detail=f"{res['count']} row(s) from {schema}.{copy} (TOP {rows})")
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
    return res


# ---------------------------------------------------------------------------
# TOKENIZATION (deliverable §4.2) — surrogate token in the table, real value in a
# separate encrypted vault DB. Caller selects the encryption type.
# ---------------------------------------------------------------------------
def tokenize(server, database, schema, table, column, encryption_type="passphrase"):
    """Replace <column> with a random surrogate token; store the real value
    encrypted in the TokenVault database, recoverable only via the de-tokenize
    proc. encryption_type: passphrase (ENCRYPTBYPASSPHRASE) | aes256 (symmetric
    key). The original column is set to its token; a de-tokenize proc is created
    and granted to db_payment_processor when that role exists.
    <table> may be '<schema>.<table>'; the embedded schema then wins."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}.{column}",
           "encryption_type": encryption_type, "status": None, "detail": None}
    et = (encryption_type or "passphrase").strip().lower()
    if et not in ("passphrase", "aes256"):
        res.update(status="error", detail=f"unsupported encryption type: {encryption_type!r}"); return res
    if not all([server, database, schema, table, column]):
        res.update(status="error", detail="server, database, schema, table, column required"); return res

    info = _resolve_mssql(server)
    if not info:
        res.update(status="error", detail="no active MSSQL instance for this server")
        _dp_log(server, database, schema, table, column, "tokenize", "error", res["detail"]); return res
    port, user, pw, _ddb = info
    try:
        # validate the target column
        conn = _connect(server, port, user, pw, database, timeout=300); cur = conn.cursor()
        obj = _resolve_object(cur, schema, table, column)
        if not obj:
            conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
            _dp_log(server, database, schema, table, column, "tokenize", "error", res["detail"]); return res
        s, t, c, ty, cap = obj
        if ty not in ("char", "varchar", "nchar", "nvarchar") or cap < 32:
            conn.close(); res.update(status="error",
                detail=f"column type/size '{ty}({cap})' cannot hold a 32-char token")
            _dp_log(server, database, schema, table, column, "tokenize", "error", res["detail"]); return res
        conn.close()

        # 1) vault DB + tokens table (master, then vault)
        m = _connect(server, port, user, pw, "master", timeout=120); mc = m.cursor()
        mc.execute(f"IF DB_ID('{_VAULT_DB}') IS NULL CREATE DATABASE [{_VAULT_DB}];")
        while mc.nextset(): pass
        m.close()
        v = _connect(server, port, user, pw, _VAULT_DB, timeout=120); vc = v.cursor()
        vc.execute("IF OBJECT_ID('dbo.Tokens') IS NULL "
                   "CREATE TABLE dbo.Tokens (token char(32) NOT NULL PRIMARY KEY, "
                   "src nvarchar(512) NULL, enc varbinary(max) NOT NULL, "
                   "created_utc datetime2 NOT NULL DEFAULT SYSUTCDATETIME());")
        while vc.nextset(): pass
        v.close()

        # 2) tokenize in the source DB. ENCRYPTBYPASSPHRASE works cross-DB, so the
        #    vault holds ciphertext and the source never stores a usable key.
        src = f"[{s}].[{t}]"
        sconn = _connect(server, port, user, pw, database, timeout=300); sc = sconn.cursor()
        # add a transient token column, generate tokens
        sc.execute(f"IF COL_LENGTH('{s}.{t}','{c}__tok') IS NULL ALTER TABLE {src} ADD [{c}__tok] char(32) NULL;")
        sc.execute(f"UPDATE {src} SET [{c}__tok] = LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),32) "
                   f"WHERE [{c}] IS NOT NULL;")
        # store (token, encrypted real value) in the vault
        sc.execute(
            f"INSERT INTO {_VAULT_DB}.dbo.Tokens (token, src, enc) "
            f"SELECT [{c}__tok], N'{database}.{s}.{t}.{c}', "
            f"ENCRYPTBYPASSPHRASE('{_TOKEN_PASSPHRASE}', CONVERT(nvarchar(4000),[{c}])) "
            f"FROM {src} WHERE [{c}] IS NOT NULL AND [{c}__tok] IS NOT NULL "
            f"AND NOT EXISTS (SELECT 1 FROM {_VAULT_DB}.dbo.Tokens z WHERE z.token=[{c}__tok]);")
        ins = sc.rowcount
        # replace the real value with the token, drop the transient column
        sc.execute(f"UPDATE {src} SET [{c}] = [{c}__tok] WHERE [{c}__tok] IS NOT NULL;")
        sc.execute(f"ALTER TABLE {src} DROP COLUMN [{c}__tok];")
        while sc.nextset(): pass
        sconn.close()

        # 3) de-tokenize proc in the vault, granted to db_payment_processor if present
        v = _connect(server, port, user, pw, _VAULT_DB, timeout=120); vc = v.cursor()
        vc.execute("CREATE OR ALTER PROCEDURE dbo.usp_Detokenize @token char(32) AS "
                   "BEGIN SET NOCOUNT ON; "
                   f"SELECT CONVERT(nvarchar(4000), DECRYPTBYPASSPHRASE('{_TOKEN_PASSPHRASE}', enc)) AS value "
                   "FROM dbo.Tokens WHERE token=@token; END;")
        vc.execute("IF DATABASE_PRINCIPAL_ID('db_payment_processor') IS NOT NULL "
                   "GRANT EXECUTE ON dbo.usp_Detokenize TO db_payment_processor;")
        while vc.nextset(): pass
        v.close()

        res.update(status="ok",
                   detail=f"{ins} values tokenized into {_VAULT_DB}.dbo.Tokens (encryption={et})")
        _dp_log(server, database, s, t, c, "tokenize", "ok", res["detail"])
        db_write_log(f"tokenize {server}/{database}/{s}.{t}.{c} enc={et} rows={ins}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column, "tokenize", "error", res["detail"])
    return res


# ---------------------------------------------------------------------------
# STAGED TOKENIZATION (copy -> switch), mirroring staged anonymization:
#   tokenize_pre    : copy <schema>.<table> to <table>_<yyyyMMddHHmmss>, tokenize the
#                     chosen COLUMN on the COPY (original untouched), mirror copy to PG.
#   tokenize_actual : switch the live table with its latest pre-copy (3-way rename swap).
#   (archive with anonymize_confirm — the swap/archive mechanics are technique-agnostic.)
# ---------------------------------------------------------------------------
def tokenize_pre(server, database, schema, table, column, encryption_type="passphrase"):
    """Phase 1: copy <schema>.<table> to <table>_<yyyyMMddHHmmss> and tokenize <column>
    on the COPY (original left intact for review); the copy is also mirrored into local
    Postgres. Returns the new copy name in res['copy']."""
    schema, table = _split_schema_table(schema, table)
    et = (encryption_type or "passphrase").strip().lower()
    res = {"server": server, "database": database, "object": f"{schema}.{table}.{column}",
           "encryption_type": et, "status": None, "detail": None, "copy": None, "pg_table": None}
    if not all([server, database, schema, table, column]) or "]" in (schema + table):
        res.update(status="error", detail="valid server, database, schema, table, column required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        if not _table_exists(cur, schema, table):
            conn.close(); res.update(status="error", detail=f"{schema}.{table} not found")
            _dp_log(server, database, schema, table, column, "tokenize_pre", "error", res["detail"]); return res
        copy = f"{table}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        cur.execute(f"IF OBJECT_ID(N'[{schema}].[{copy}]',N'U') IS NOT NULL DROP TABLE [{schema}].[{copy}];")
        cur.execute(f"SELECT * INTO [{schema}].[{copy}] FROM [{schema}].[{table}];")
        copied = cur.rowcount
        conn.close()
        tk = tokenize(server, database, schema, copy, column, et)   # tokenize the COLUMN on the COPY
        detail = f"copied {copied} rows -> {schema}.{copy}; tokenize: {tk.get('detail')}"
        # Mirror the tokenized copy into local Postgres. A load failure must not flip the
        # on-source tokenize result, but is reported.
        if tk.get("status") != "error":
            try:
                pg_tbl, pg_rows = _load_copy_to_postgres(server, database, schema, copy)
                res["pg_table"] = pg_tbl
                detail += f"; pg: {pg_rows} rows -> {pg_tbl}"
            except Exception as pe:
                detail += f"; pg load FAILED: {str(pe)[:200]}"
        res.update(status=tk.get("status"), copy=f"{schema}.{copy}", detail=detail)
        _dp_log(server, database, schema, copy, column, "tokenize_pre", res["status"], res["detail"])
        db_write_log(f"tokenize_pre {server}/{database}/{schema}.{table}.{column} -> {copy} (enc={et})", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column, "tokenize_pre", "error", res["detail"])
    return res


def tokenize_actual(server, database, schema, table):
    """Phase 2: switch the live <schema>.<table> with its most recent tokenize_pre copy
    via a 3-way sp_rename swap. The tokenized copy becomes <table>; the previous <table>
    is preserved under the copy's dated name. Re-running switches back. (Swap mechanics
    are technique-agnostic — same as anonymize_actual.)"""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}",
           "status": None, "detail": None, "switched_with": None}
    if not all([server, database, schema, table]) or "]" in (schema + table):
        res.update(status="error", detail="valid server, database, schema, table required"); return res
    try:
        conn = _open(server, database); cur = conn.cursor()
        if not _table_exists(cur, schema, table):
            conn.close(); res.update(status="error", detail=f"{schema}.{table} not found")
            _dp_log(server, database, schema, table, "", "tokenize_actual", "error", res["detail"]); return res
        copies = _pre_copies(cur, schema, table)
        if not copies:
            conn.close(); res.update(status="error", detail=f"no tokenize_pre copy found for {schema}.{table}")
            _dp_log(server, database, schema, table, "", "tokenize_actual", "error", res["detail"]); return res
        partner = copies[-1]
        tmp = f"{table}__swaptmp_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{table}]", tmp))
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{partner}]", table))
        cur.execute("EXEC sp_rename ?, ?", (f"[{schema}].[{tmp}]", partner))
        conn.close()
        res.update(status="ok", switched_with=f"{schema}.{partner}",
                   detail=f"switched {schema}.{table} <-> {schema}.{partner} (live now = tokenized copy)")
        _dp_log(server, database, schema, table, "", "tokenize_actual", "ok", res["detail"])
        db_write_log(f"tokenize_actual {server}/{database}/{schema}.{table} <-> {partner}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, "", "tokenize_actual", "error", res["detail"])
    return res


def revert_tokenize(server, database, schema, table, column):
    """Reverse tokenization: replace each token in <column> with its decrypted real
    value from TokenVault (passphrase vault). Reversible by design. Audited as
    revert_tokenize. <table> may be '<schema>.<table>'; the embedded schema then wins."""
    schema, table = _split_schema_table(schema, table)
    res = {"server": server, "database": database, "object": f"{schema}.{table}.{column}",
           "status": None, "detail": None}
    try:
        conn = _open(server, database); cur = conn.cursor()
        obj = _resolve_object(cur, schema, table, column)
        if not obj:
            conn.close(); res.update(status="error", detail=f"{schema}.{table}.{column} not found")
            _dp_log(server, database, schema, table, column, "revert_tokenize", "error", res["detail"]); return res
        s, t, c, _ty, _cap = obj
        cur.execute(
            f"UPDATE src SET [{c}] = v.plain "
            f"FROM [{s}].[{t}] src "
            f"JOIN (SELECT token, CONVERT(nvarchar(4000), "
            f"             DECRYPTBYPASSPHRASE('{_TOKEN_PASSPHRASE}', enc)) AS plain "
            f"      FROM {_VAULT_DB}.dbo.Tokens) v ON v.token = src.[{c}];")
        rows = cur.rowcount
        conn.close()
        res.update(status="ok", detail=f"de-tokenized {rows} rows")
        _dp_log(server, database, s, t, c, "revert_tokenize", "ok", res["detail"])
        db_write_log(f"revert_tokenize {server}/{database}/{s}.{t}.{c} rows={rows}", 0, "data_protection", server)
    except Exception as e:
        res.update(status="error", detail=str(e)[:300])
        _dp_log(server, database, schema, table, column, "revert_tokenize", "error", res["detail"])
    return res
