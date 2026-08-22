"""Generate security_agent/rules.json from rootcause.v_rootcauses.

    python -m security_agent.build_rules [--domains SEC,...] [--out PATH] [--dry-run]

WHY GENERATE RATHER THAN HAND-WRITE
    The product already holds a curated description of every threat it detects.
    Restating that by hand in a prompt file would immediately drift from the
    catalogue and would have to be re-edited every time a root cause changes.
    Generating means the agent's knowledge and the product's rule set are the
    same thing by construction.

THE CONTEXT BUDGET IS THE WHOLE DESIGN
    n_ctx is 4096 tokens. The catalogue can hold hundreds of security root
    causes; pasting them into the system prompt would crowd out the evidence and
    make every verdict worse. So the output has two tiers:

      threats[]  - ONE condensed rule per area, always in the system prompt.
                   Small, general, tells the model what families exist.
      catalog{}  - root_cause_id -> {name, desc, risk}. NOT in the system prompt.
                   The alert being judged carries its own root_cause_id, so
                   exactly one entry is injected as grounding for that alert.

MERGE, DON'T CLOBBER
    always_alert, benign_hints and custom are human judgement policy that is not
    in the catalogue. Regenerating preserves them; only threats and catalog are
    replaced.
"""
import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import psycopg2
import psycopg2.extras

from utils.config_dotenv import get_connection_string

DEFAULT_OUT = Path(__file__).resolve().parent / "rules.json"

# Column names differ across views/versions; take the first that exists.
_PICK = {
    "rc_id":  ("root_cause_id",),
    "rc_name": ("root_cause_name", "name"),
    "rc_desc": ("root_cause_desc", "description", "root_cause_description"),
    "domain": ("domain_name", "domain_code", "domain"),
    "area":   ("area_name", "area_code", "area"),
    "issue":  ("issue_name", "issue_id"),
    "risk":   ("risk_level", "severity"),
}


def _resolve(colnames):
    out = {}
    lower = {c.lower(): c for c in colnames}
    for key, candidates in _PICK.items():
        for c in candidates:
            if c in lower:
                out[key] = lower[c]
                break
    return out


def _clip(s, n):
    s = (s or "").strip().replace("\n", " ")
    return s if len(s) <= n else s[:n].rsplit(" ", 1)[0] + "..."


def fetch(conn, domains):
    """Read the catalogue from the BASE TABLES, not rootcause.v_rootcauses.

    The view looks like the obvious source and is a trap: it selects
    rootcause."dec"(stps.parameters), i.e. it PGP-decrypts detection content for
    every row, and its SELECT DISTINCT forces the whole thing to materialise
    before any LIMIT applies. Measured on this database: count(*) over the view
    times out at 25s, and even fetching 200 root_cause_ids takes 10 seconds. An
    earlier unbounded scan of it held a session for 45 minutes.

    root_causes JOIN issues JOIN areas/domains carries everything a rule needs
    -- id, name, description, area, domain -- returns in milliseconds, and
    touches nothing encrypted, so this does not even need the session key.
    """
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("SET statement_timeout = '60s'")
        sql = """
            SELECT rc.root_cause_id,
                   rc.name         AS root_cause_name,
                   rc.description  AS root_cause_desc,
                   i.issue_id,
                   i.name          AS issue_name,
                   i.domain_code,
                   i.area_code,
                   COALESCE(a.name, i.area_code)   AS area_name,
                   COALESCE(d.name, i.domain_code) AS domain_name
            FROM rootcause.root_causes rc
            JOIN rootcause.issues  i ON i.issue_id = rc.issue_id
            LEFT JOIN rootcause.areas   a ON a.code = i.area_code
                                         AND a.database_type_code = i.database_type_code
            LEFT JOIN rootcause.domains d ON d.code = i.domain_code
            WHERE rc.is_informational IS NOT TRUE
        """
        params = []
        if domains:
            sql += " AND upper(i.domain_code) = ANY(%s)"
            params.append([d.upper() for d in domains])
        cur.execute(sql, params)
        rows = [dict(r) for r in cur.fetchall()]

    cols = {
        "rc_id": "root_cause_id", "rc_name": "root_cause_name",
        "rc_desc": "root_cause_desc", "domain": "domain_name",
        "area": "area_name", "issue": "issue_name",
    }
    return rows, cols


def build(rows, cols):
    catalog, by_area = {}, {}
    for r in rows:
        rid = r.get(cols["rc_id"])
        if not rid:
            continue
        name = _clip(r.get(cols.get("rc_name", "")), 160)
        desc = _clip(r.get(cols.get("rc_desc", "")), 600)
        risk = (r.get(cols.get("risk", "")) or "").strip() or None
        area = (r.get(cols.get("area", "")) or "OTHER").strip() or "OTHER"

        entry = {"name": name}
        if desc:
            entry["desc"] = desc
        if risk:
            entry["risk"] = risk
        catalog[rid] = entry
        by_area.setdefault(area, []).append(name or rid)

    return catalog, by_area


def _area_rule(area, names, n_examples):
    # Distinct, shortest-first: a representative sample of what this family
    # looks like, without a wall of near-duplicates.
    seen, picked = set(), []
    for n in sorted(set(n for n in names if n), key=len):
        k = n.lower()
        if k in seen:
            continue
        seen.add(k)
        picked.append(n)
        if len(picked) >= n_examples:
            break
    return {
        "id": f"AREA_{area.upper().replace(' ', '_').replace('&', 'AND')}",
        "name": f"{area} ({len(names)} detections)",
        "enabled": True,
        "generated": True,
        "text": (f"{area} ({len(names)} detections), e.g. {'; '.join(picked)}."),
    }


def fit_to_budget(by_area, budget_tokens, hand_written_chars=0):
    """Largest areas first, trimmed until the rules block fits the token budget.

    The budget is the point of this function. Generating 19 areas x 8 examples
    produced a 10,827-char block -- about 2,706 tokens of a 4,096-token context,
    leaving too little room for the query and its precedent. A rule set that
    crowds out the evidence makes every verdict worse, so the generator refuses
    to emit one and says what it dropped.
    """
    areas = sorted(by_area.items(), key=lambda kv: len(kv[1]), reverse=True)
    # ~4 chars/token is the usual rough ratio for English prose.
    budget_chars = max(0, budget_tokens * 4 - hand_written_chars)

    for n_examples in (5, 4, 3, 2, 1):
        for keep in range(len(areas), 0, -1):
            chosen = areas[:keep]
            rules_out = [_area_rule(a, names, n_examples) for a, names in chosen]
            size = sum(len(r["text"]) + 8 for r in rules_out)
            if size <= budget_chars:
                return rules_out, {
                    "examples_per_area": n_examples,
                    "areas_kept": keep,
                    "areas_total": len(areas),
                    "dropped": [a for a, _ in areas[keep:]],
                    "chars": size,
                }
    # Even one area at one example does not fit -- emit nothing rather than
    # silently blow the context.
    return [], {"examples_per_area": 0, "areas_kept": 0, "areas_total": len(areas),
                "dropped": [a for a, _ in areas], "chars": 0}


def _handwritten_chars(existing) -> int:
    """Prompt cost of the rules a human wrote, which the merge always preserves.

    Counted the same way prompt_block() renders them, so the budget reflects the
    real system prompt rather than only the part this script generates.
    """
    if not isinstance(existing, dict):
        return 0
    total = len(((existing.get("always_alert") or {}).get("text") or "")) + 20
    for key in ("threats", "custom", "benign_hints"):
        for r in (existing.get(key) or []):
            if isinstance(r, dict) and r.get("enabled") and not r.get("generated"):
                total += len(r.get("text") or "") + len(str(r.get("id") or "")) + 8
    return total


def merge(existing, catalog, threats, source):
    out = dict(existing) if isinstance(existing, dict) else {}
    out["version"] = int(out.get("version") or 0) + 1
    out["generated_from"] = source
    # Hand-written rules survive; only generated content is replaced.
    kept = [t for t in (out.get("threats") or [])
            if isinstance(t, dict) and not t.get("generated")]
    out["threats"] = kept + threats
    out["catalog"] = catalog
    out.setdefault("always_alert", {})
    out.setdefault("benign_hints", [])
    out.setdefault("custom", [])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--domains", default="SEC",
                    help="comma-separated domain codes/names to include, or ALL")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--budget-tokens", type=int, default=700,
                    help="max tokens the generated rules may occupy in the system "
                         "prompt (default 700 of a 4096 context, leaving room for "
                         "the query and its precedent)")
    args = ap.parse_args()

    domains = None if args.domains.upper() == "ALL" else \
        [d.strip() for d in args.domains.split(",") if d.strip()]

    conn = psycopg2.connect(get_connection_string())
    try:
        rows, cols = fetch(conn, domains)
    finally:
        conn.close()

    catalog, by_area = build(rows, cols)

    # The hand-written rules are preserved by the merge and share the same
    # budget, so measure them FIRST and give the generator only what is left.
    # Ignoring them is how the first attempt produced a 1,324-token block while
    # believing it had budgeted 700.
    existing_pre = {}
    if os.path.isfile(args.out):
        try:
            with open(args.out, encoding="utf-8") as fh:
                existing_pre = json.load(fh)
        except Exception:
            existing_pre = {}
    hand_chars = _handwritten_chars(existing_pre)

    threats, fit = fit_to_budget(by_area, args.budget_tokens, hand_chars)
    print(f"  hand-written rules occupy {hand_chars:,} chars "
          f"(~{hand_chars // 4:,} tokens) of the {args.budget_tokens:,}-token budget")
    print(f"  root causes read : {len(rows)}")
    print(f"  catalog entries  : {len(catalog)}   (NOT in the prompt - looked up per alert)")
    print(f"  areas            : {fit['areas_kept']}/{fit['areas_total']} kept, "
          f"{fit['examples_per_area']} example(s) each")
    if fit["dropped"]:
        print(f"  dropped for budget: {', '.join(fit['dropped'])}")
        print(f"                      (still in the catalog, so still available as "
              f"per-alert grounding)")

    existing = {}
    if os.path.isfile(args.out):
        try:
            with open(args.out, encoding="utf-8") as fh:
                existing = json.load(fh)
        except Exception as e:
            print(f"  WARNING: existing {args.out} unreadable ({e}); starting fresh")

    merged = merge(existing, catalog, threats,
                   f"rootcause.v_rootcauses (domains={args.domains})")

    # The prompt block is what actually costs context -- report it, because a
    # generated file that silently blows n_ctx would degrade every verdict.
    from security_agent import rules as _r
    body = json.dumps(merged, indent=2, ensure_ascii=False)
    if args.dry_run:
        print("\n--- would write ---")
        print(body[:1500] + (" ...[clip]" if len(body) > 1500 else ""))
        return

    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(body + "\n")
    print(f"  wrote {args.out} ({len(body):,} bytes)")

    _r.load(force=True)
    block = _r.prompt_block()
    approx_tokens = len(block) // 4
    print(f"  system-prompt rules block: {len(block):,} chars (~{approx_tokens:,} tokens)")
    if approx_tokens > 900:
        print("  WARNING: that is a large share of a 4096-token context. Consider "
              "--domains SEC, or trimming areas, or raising SECURITY_AGENT_N_CTX.")


if __name__ == "__main__":
    main()
