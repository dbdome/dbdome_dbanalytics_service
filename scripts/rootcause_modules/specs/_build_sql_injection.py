#!/usr/bin/env python3
r"""Build specs/sql_injection.json from SQL_INJECTION_DETECTION.md (area INJ).

Core techniques INJ-001..016 get real per-vendor detection SQL against the
statement-text plane the doc specifies:
  PostgreSQL  pg_stat_activity.query        (~* regex)
  MySQL       information_schema.processlist.info (REGEXP)
  SQL Server  sys.dm_exec_requests + sys.dm_exec_sql_text (LIKE)
  Oracle      v$session join v$sql          (REGEXP_LIKE)
Signatures are curated (the doc's well-known shapes), not exhaustive.
Red-team / behavioral variants (INJ-017..054) are registered as catalog entries
with detect=None (TODO) — they are evasion refinements / behavioral baselines.
"""
import json
import os

V = ["postgresql", "sqlserver", "oracle", "mysql"]
# Broad column set — the per-vendor probes emit different keys; the view maps all,
# absent keys yield NULL per row.
COLS = ["query", "pid", "usename", "client_addr", "state", "session_id",
        "login_name", "sid", "username", "id", "user", "host", "db"]


def pg(sig):
    return ("SELECT pid, usename, host(client_addr) AS client_addr, state, query "
            "FROM pg_stat_activity WHERE query IS NOT NULL AND state <> 'idle' "
            f"AND query ~* '{sig}'")


def mysql(sig):
    return ("SELECT id, user, host, db, info AS query FROM information_schema.processlist "
            f"WHERE info IS NOT NULL AND info REGEXP '{sig}'")


def oracle(sig):
    return ("SELECT s.sid, s.username, q.sql_text AS query FROM v$session s "
            "JOIN v$sql q ON q.sql_id = s.sql_id "
            f"WHERE q.sql_text IS NOT NULL AND REGEXP_LIKE(q.sql_text, '{sig}', 'i')")


def mssql(likes):
    pred = " OR ".join(f"t.text LIKE '%{p}%'" for p in likes)
    return ("SELECT r.session_id, s.login_name, t.text AS query FROM sys.dm_exec_requests r "
            "JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id "
            "CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t "
            f"WHERE ({pred})")


def rc(idn, name, desc, detect, risk="high"):
    return {
        "rc": f"SEC-SQL-INJ-{idn:03d}-RC01",
        "issue": f"SEC-SQL-INJ-{idn:03d}",
        "name": name, "slug": f"inj-{idn:03d}",
        "description": desc, "topics": ["sql-injection", "owasp-a03", "cwe-89", "inj"],
        "risk_level": risk,
        "resolution": "Parameterize the statement (bound variables / prepared statements / "
                      "sp_executesql / EXECUTE IMMEDIATE ... USING). Least-privilege the app role "
                      "and remove the abused primitive. Corroborate with the source identity before alerting.",
        "expected": {"condition": "row_count > 0",
                     "description": "Live/recent statement text matches an injection signature"},
        "columns": COLS,
        "detect": {v: detect.get(v) for v in V},
    }


CORE = [
    rc(1, "Error-based injection",
       "Error-based extraction via cast/XML/convert/UTL leak functions (extractvalue, updatexml, convert(int), utl_inaddr).",
       {"postgresql": pg(r"(xmlparse|xpath\s*\(|cast\s*\(.*as\s+(int|numeric))"),
        "mysql": mysql(r"extractvalue|updatexml|exp\\(~|floor\\(rand"),
        "oracle": oracle(r"utl_inaddr|ctxsys\.drithsx|dbms_xmlgen|xmltype\s*\("),
        "sqlserver": mssql(["convert(int", "convert (int", "cast(0x"])}),
    rc(2, "UNION-based injection",
       "UNION SELECT appended to read other tables/columns.",
       {"postgresql": pg(r"union\s+(all\s+)?select"),
        "mysql": mysql(r"union\\s+(all\\s+)?select")}),
    rc(3, "Boolean-based blind injection",
       "Boolean blind via numeric tautology (AND 1=1 / 1=2).",
       {"postgresql": pg(r"(and|or)\s+[0-9]+\s*=\s*[0-9]+")}),
    rc(4, "Time-based blind injection",
       "Timing oracle via sleep functions (pg_sleep / SLEEP / WAITFOR DELAY / DBMS_LOCK.SLEEP).",
       {"postgresql": pg(r"pg_sleep\s*\("),
        "mysql": mysql(r"sleep\\s*\\("),
        "oracle": oracle(r"dbms_lock\.sleep|dbms_session\.sleep"),
        "sqlserver": mssql(["waitfor delay"])}),
    rc(5, "Stacked queries",
       "A second statement appended after a semicolon (;DROP/;EXEC/;INSERT).",
       {"postgresql": pg(r";\s*(insert|update|delete|drop|create|alter|grant|copy)"),
        "sqlserver": mssql(["; drop ", "; exec", "; insert", "; update", "; delete"])}),
    rc(6, "Out-of-band exfiltration",
       "OOB channel via UTL_HTTP / xp_dirtree / COPY ... PROGRAM / pg_read_file.",
       {"oracle": oracle(r"utl_http|utl_inaddr|httpuritype|utl_tcp"),
        "sqlserver": mssql(["xp_dirtree", "xp_cmdshell", "sp_oacreate", "xp_fileexist"]),
        "postgresql": pg(r"copy\s+.*\s+program|pg_read_file|pg_ls_dir")},
       "critical"),
    rc(7, "Tautology / auth-bypass",
       "Classic auth bypass via a constant-true predicate (' OR '1'='1).",
       {"postgresql": pg(r"(or|and)\s+'?[0-9a-z]+'?\s*=\s*'?[0-9a-z]+'?(\s*(--|#|/\*))?")}),
    rc(8, "Comment / inline-comment evasion",
       "Keyword splitting or trailing comments (UN/**/ION, /*!...*/, -- , #).",
       {"mysql": mysql(r"/\\*!|--\\s|#|/\\*.*\\*/")}),
    rc(9, "Dynamic-SQL / stored-proc injection",
       "Injection through EXEC()/EXECUTE IMMEDIATE/sp_executesql dynamic SQL.",
       {"sqlserver": mssql(["exec(", "execute(", "sp_executesql"]),
        "oracle": oracle(r"execute\s+immediate")}),
    rc(10, "Schema/catalog enumeration via injection",
       "Catalog probing (information_schema / pg_catalog / pg_tables).",
       {"postgresql": pg(r"information_schema\.|pg_catalog\.|pg_tables|pg_class|pg_attribute")}),
    rc(11, "ORDER BY / column-count probing",
       "Column-count discovery via ORDER BY <n>.",
       {"mysql": mysql(r"order\\s+by\\s+[0-9]+")}),
    rc(12, "NoSQL operator injection ($ne/$gt/$regex)", "MongoDB operator injection.", {}, "high"),
    rc(13, "NoSQL $where / $function server-side-JS injection", "MongoDB server-side JS injection.", {}, "critical"),
    rc(14, "Encoding / obfuscation evasion",
       "Hex / CHAR() / CONCAT obfuscation of the payload.",
       {"mysql": mysql(r"0x[0-9a-f]{4,}|char\\s*\\(|concat\\s*\\(")}),
    rc(15, "Automated-tool signature (sqlmap / NoSQLMap)",
       "Tooling fingerprint in the statement text.",
       {"postgresql": pg(r"sqlmap|nosqlmap|/\*[0-9a-f]{4}\*/")}),
    rc(16, "Second-order (stored) injection",
       "Payload stored then executed later — correlation-dependent (TODO: trace stored payload).",
       {}),
]

# Red-team / behavioral variants — registered as catalog entries (detection TODO).
REDTEAM = {
    17: "Inline-comment keyword split (UN/**/ION, /*!...*/)",
    18: "Error oracle via floor(rand)/exp/geometry/XML-gen",
    19: "Char-by-char blind via substring()/ascii()",
    20: "Timing oracle via heavy compute (no sleep keyword)",
    21: "OOB via sp_OACreate / sp_send_dbmail / DBMS_LDAP",
    22: "Auth-bypass without '=' (OR 1 / LIKE / BETWEEN / ||)",
    23: "Catalog enumeration on MySQL / SQL Server / Oracle",
    24: "Payload laundered through the application role",
    25: "Tooling with --random-agent / --tamper (fingerprint stripped)",
    26: "Payload in a normalized constant slot (digest-matching)",
    27: "Baseline poisoning during the learning window",
    28: "Slow-and-low manual injection on a single high-value action",
    29: "Injection inside a dynamic-SQL function/module body",
    30: "Batch/ETL-path second-order (scheduled job)",
    31: "SQL/JSON path injection (jsonb_path_query / JSON_EXTRACT)",
    32: "ORDER BY-clause injection (ORDER BY CASE WHEN)",
    33: "Space-free / Unicode keyword evasion",
    34: "ORM raw-fragment ($queryRaw / knex.raw / literal())",
    35: "Connection-handshake injection (search_path / options)",
    36: "Trigger-fired dynamic SQL (detonates on write)",
    37: "Type-juggling (WHERE token = 0 matches any string)",
    38: "Multibyte charset quote-smuggling (GBK)",
    39: "Mass-assignment / column-name injection",
    40: "Header/log-stored second-order",
    41: "Polyglot payload (valid as SQL + NoSQL)",
    42: "Prepared-statement-body scan gap",
    43: "Capture-integrity self-check (sensor blinded)",
    44: "Auto-SQL shape baseline (PostgREST/Hasura/Data-API)",
    45: "SECURITY DEFINER dynamic-SQL routines (RLS-bypass)",
    46: "Clause-context injection (LIMIT/OFFSET/GROUP BY/HAVING/IN)",
    47: "Write-path & RETURNING/CTE injection",
    48: "MongoDB aggregation-pipeline injection",
    49: "MongoDB nested array-operator injection",
    50: "WAF-evasion token variants (sci-notation / versioned comments / RLIKE)",
    51: "SQL Server linked-server passthrough + EXECUTE AS",
    52: "Sweep-scope topology gap (replicas / other DBs)",
    53: "ORM Leak — operator-based blind exfiltration (behavioral)",
    54: "Prototype-pollution filter-less dump (missing mandatory predicate)",
}

RCS = CORE + [
    rc(n, name, name + " (red-team variant; detection TODO — see SQL_INJECTION_DETECTION.md).", {})
    for n, name in sorted(REDTEAM.items())
]

SPEC = {
    "module": "sql_injection",
    "area_code": "INJ",
    "source": "PLANS/SQL_INJECTION_DETECTION.md",
    "vendors": V,
    "root_causes": RCS,
}

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "sql_injection.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=2)
    withsql = sum(1 for r in RCS if any(r["detect"].get(v) for v in V))
    print(f"wrote {out}: {len(RCS)} root causes, {withsql} with detection SQL, "
          f"{len(RCS)-withsql} catalog-only (TODO)")
