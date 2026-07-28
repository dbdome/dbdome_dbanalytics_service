r"""Root-cause explainer (LLM feature, powered by `claude -p`).

Feeds a rootcause.v_rootcauses row - the detection SQL, its match condition and
the linked resolution steps - to claude-opus-4-8 and returns a plain-English
remediation narrative for a DBA, auditor or executive.

Uses the Claude Code CLI (`claude -p`), so it needs no `anthropic` pip package
and no API key in .env (the CLI supplies its own auth).

CLI:
    python -m analysis.rootcause_explainer SEC-SQL-AUD-027-RC01
    python -m analysis.rootcause_explainer SEC-SQL-AUD-027-RC01 --vendor oracle
    python -m analysis.rootcause_explainer SEC-SQL-PRI-001-RC12 --audience auditor --text
    python -m analysis.rootcause_explainer SEC-SQL-AUD-027-RC01 --save     # cache to analysis.rc_explanations

Programmatic:
    from analysis.rootcause_explainer import explain
    result = explain("SEC-SQL-AUD-027-RC01", vendor="oracle")   # -> dict

Environment:
    CLAUDE_BIN    path to claude.exe (default C:\Users\yoram\.local\bin\claude.exe)
    CLAUDE_MODEL  model alias/id (default: opus)
"""
import argparse
import json
import os
import re
import subprocess
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    from utils.utils_config_dotenv import get_connection_string
except Exception:
    try:
        from utils.config_dotenv import get_connection_string
    except Exception:
        get_connection_string = None

CLAUDE_BIN = os.environ.get("CLAUDE_BIN", r"C:\Users\yoram\.local\bin\claude.exe")
MODEL = os.environ.get("CLAUDE_MODEL", "opus")

_AUDIENCE_GUIDE = {
    "dba": "a senior database administrator - be technical and actionable",
    "auditor": "a compliance auditor - emphasise control intent, evidence and regulatory relevance",
    "executive": "a non-technical executive - emphasise business risk and impact, minimal jargon",
}


def fetch_rootcause(root_cause_id, vendor=None):
    """Return a dict describing the root cause: taxonomy, detection SQL, match
    condition and resolution steps. Returns None if the root cause is unknown."""
    if get_connection_string is None:
        raise RuntimeError("no DB connection helper available")
    import psycopg2
    conn = psycopg2.connect(get_connection_string())
    conn.set_session(readonly=True, autocommit=True)
    cur = conn.cursor()
    cur.execute("SET LOCAL statement_timeout = 15000")

    where_vendor = " AND lower(vendor_name) = lower(%s)" if vendor else ""
    params = [root_cause_id] + ([vendor] if vendor else [])
    cur.execute(f"""
        SELECT domain_name, area_name, issue_name, root_cause_id, root_cause_name,
               root_cause_desc, detection_name, detection_desc, vendor_name,
               risk_level, content->>'sql' AS detection_sql, expected::text AS expected
        FROM rootcause.v_rootcauses
        WHERE root_cause_id = %s{where_vendor}
        ORDER BY vendor_name
        LIMIT 1
    """, params)
    row = cur.fetchone()
    if not row:
        cur.close(); conn.close()
        return None
    cols = [d[0] for d in cur.description]
    rc = dict(zip(cols, row))
    rc_vendor = vendor or rc.get("vendor_name")

    # resolution steps for this root cause + vendor
    cur.execute("""
        SELECT rs.name, rs.content->>'action' AS action, rs.risk_level,
               rs.requires_confirmation, rs.is_reversible, rps.step_order
        FROM rootcause.resolution_paths rp
        JOIN rootcause.resolution_path_steps rps ON rps.resolution_path_id = rp.id
        JOIN rootcause.resolution_steps rs ON rs.id = rps.resolution_step_id
        WHERE rp.root_cause_id = %s AND lower(rp.vendor_slug) = lower(%s)
        ORDER BY rps.step_order
    """, (root_cause_id, rc_vendor))
    rc["resolution_steps"] = [
        {"name": r[0], "action": r[1], "risk_level": r[2],
         "requires_confirmation": r[3], "is_reversible": r[4]}
        for r in cur.fetchall()
    ]
    cur.close(); conn.close()
    return rc


def _run_claude(prompt):
    cmd = [CLAUDE_BIN, "-p", prompt, "--output-format", "json",
           "--max-turns", "1", "--model", MODEL]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          stdin=subprocess.DEVNULL, timeout=600)
    if proc.returncode != 0 or not proc.stdout.strip():
        raise RuntimeError(f"claude failed: {proc.stderr or proc.stdout}")
    env = json.loads(proc.stdout)
    if env.get("is_error"):
        raise RuntimeError(f"claude error: {env.get('subtype')}")
    return env.get("result", ""), env


def _extract_json_obj(text):
    cleaned = re.sub(r"```(?:json)?", "", text).strip()
    m = re.search(r"\{[\s\S]*\}\s*$", cleaned)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError:
        return None


def explain(root_cause_id, vendor=None, audience="dba", as_text=False):
    """Generate a remediation narrative for a root cause.

    Returns a dict: {root_cause_id, vendor, audience, model, session_id,
    cost_usd, narrative} where narrative is a structured dict (default) or a
    plain-text string (as_text=True). Raises if the root cause is unknown.
    """
    rc = fetch_rootcause(root_cause_id, vendor)
    if rc is None:
        raise ValueError(f"root cause {root_cause_id}"
                         + (f" / {vendor}" if vendor else "") + " not found")

    who = _AUDIENCE_GUIDE.get(audience, _AUDIENCE_GUIDE["dba"])
    ctx = {
        "root_cause_id": rc["root_cause_id"], "name": rc["root_cause_name"],
        "description": rc["root_cause_desc"], "domain": rc["domain_name"],
        "area": rc["area_name"], "issue": rc["issue_name"],
        "vendor": rc["vendor_name"], "risk_level": rc["risk_level"],
        "detection_sql": rc["detection_sql"], "match_condition": rc["expected"],
        "resolution_steps": rc["resolution_steps"],
    }

    if as_text:
        prompt = (
            f"You are a database security expert writing for {who}. Explain the "
            "following DBDOME root-cause detection in clear prose (under 250 words): "
            "what it detects, why it matters, what a match means, and the concrete "
            "remediation. Ground your remediation in the resolution steps provided.\n\n"
            "DETECTION:\n" + json.dumps(ctx, ensure_ascii=False, indent=1, default=str)
        )
        text, env = _run_claude(prompt)
        narrative = text.strip()
    else:
        prompt = (
            f"You are a database security expert writing for {who}. Analyse the "
            "DBDOME root-cause detection below and respond with ONLY a JSON object "
            "(no prose before/after) with these keys:\n"
            '{"summary": "one sentence", '
            '"what_it_detects": "2-3 sentences grounded in the detection SQL", '
            '"why_it_matters": "risk / compliance relevance", '
            '"business_impact": "plain-language consequence", '
            '"severity_rationale": "why this risk_level", '
            '"remediation": ["step", "step", ...], '
            '"verification": "how to confirm the fix", '
            '"false_positive_notes": "when this may be benign"}\n\n'
            "DETECTION:\n" + json.dumps(ctx, ensure_ascii=False, indent=1, default=str)
        )
        text, env = _run_claude(prompt)
        narrative = _extract_json_obj(text) or {"raw": text.strip()}

    return {
        "root_cause_id": rc["root_cause_id"], "vendor": rc["vendor_name"],
        "audience": audience, "model": env.get("model") or MODEL,
        "session_id": env.get("session_id"),
        "cost_usd": env.get("total_cost_usd"), "narrative": narrative,
    }


def save_explanation(result):
    """Cache a narrative into analysis.rc_explanations (created on first use)."""
    if get_connection_string is None:
        raise RuntimeError("no DB connection helper available")
    import psycopg2
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    cur.execute("""
        CREATE SCHEMA IF NOT EXISTS analysis;
        CREATE TABLE IF NOT EXISTS analysis.rc_explanations (
            id            bigserial PRIMARY KEY,
            root_cause_id text NOT NULL,
            vendor        text,
            audience      text NOT NULL DEFAULT 'dba',
            model         text,
            narrative     jsonb NOT NULL,
            generated_at  timestamp NOT NULL DEFAULT now()
        );
    """)
    narrative = result["narrative"]
    cur.execute("""
        INSERT INTO analysis.rc_explanations (root_cause_id, vendor, audience, model, narrative)
        VALUES (%s, %s, %s, %s, %s)
    """, (result["root_cause_id"], result["vendor"], result["audience"],
          result["model"], json.dumps(narrative, ensure_ascii=False, default=str)))
    conn.commit(); cur.close(); conn.close()


def _print(result, as_text):
    n = result["narrative"]
    print(f"# {result['root_cause_id']}  ({result['vendor']}, {result['audience']})")
    print(f"  model={result['model']}  cost=${result.get('cost_usd', 0):.4f}\n")
    if as_text or isinstance(n, str):
        print(n if isinstance(n, str) else n.get("raw", ""))
        return
    order = ["summary", "what_it_detects", "why_it_matters", "business_impact",
             "severity_rationale", "remediation", "verification", "false_positive_notes"]
    for k in order:
        if k not in n:
            continue
        label = k.replace("_", " ").title()
        v = n[k]
        if isinstance(v, list):
            print(f"{label}:")
            for i, s in enumerate(v, 1):
                print(f"  {i}. {s}")
        else:
            print(f"{label}: {v}")
        print()


def main():
    ap = argparse.ArgumentParser(description="DBDOME root-cause explainer (claude -p)")
    ap.add_argument("root_cause_id")
    ap.add_argument("--vendor", help="oracle|sqlserver|postgresql|mysql|mariadb|informix")
    ap.add_argument("--audience", default="dba", choices=sorted(_AUDIENCE_GUIDE))
    ap.add_argument("--text", action="store_true", help="prose narrative instead of structured JSON")
    ap.add_argument("--json", action="store_true", help="print the raw result JSON")
    ap.add_argument("--save", action="store_true", help="cache into analysis.rc_explanations")
    args = ap.parse_args()

    result = explain(args.root_cause_id, vendor=args.vendor,
                     audience=args.audience, as_text=args.text)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    else:
        _print(result, args.text)
    if args.save:
        save_explanation(result)
        print("\n[saved to analysis.rc_explanations]")


if __name__ == "__main__":
    main()
