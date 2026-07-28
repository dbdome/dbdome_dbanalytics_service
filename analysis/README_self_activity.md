# Self-activity / false-alarm suppression

Some DBDOME detections are pure **state inventories** (e.g. "list every user with
their roles/privileges", connection gauges). They always return rows, so their
`row_count > 0` condition always matches — the result is stored in
`monitoring.general_metric_metadata_results` **and** alerted every collection
cycle. That is a permanent **false alarm**: DBDOME reading the catalog, not a real
incident or actual sensitive-data usage.

This feature suppresses those: a matched (metric, query) is **neither stored nor
alerted**.

## Parts

| File | Role | Uses LLM? |
|---|---|---|
| `sql_scripts/6430_analysis_suppression_rules.sql` | Creates `analysis.suppression_rules` + seeds the Oracle privilege-inventory rule (`SEC-SQL-AUTHZ-001-RC01`). | no |
| `analysis/self_activity_filter.py` | **Hot-path enforcement.** `is_self_activity(metric_name, query, vendor)` — deterministic, DB-rule-driven, cached (300s TTL), **fail-open**. Called by every vendor generic-query collector before it stores/alerts. | no |
| `analysis/self_activity_agent.py` | **Offline reviewer** (`claude -p`, claude-opus-4-8). Finds more false-alarm detections and proposes rules; also `--explain` a single detection. | yes |

The split is deliberate: **the LLM curates rules offline; the deterministic core
enforces them in the hot path.** No LLM/network in the collector loop, no
`anthropic` pip dependency in the build.

## The rules table — `analysis.suppression_rules`

`match_mode`: `query` (fingerprint of `sample_query`, whitespace/case/comment-
insensitive) · `metric` (whole `metric_name`) · `query_and_metric` (both).
`vendor_slug` / `metric_name` are optional scopes. Toggle with `is_active`.
Add a rule by hand:

```sql
INSERT INTO analysis.suppression_rules (rule_name, match_mode, vendor_slug, metric_name, sample_query, reason)
VALUES ('my-rule', 'metric', 'oracle', 'SEC-SQL-XXX-001-RC01', NULL, 'why it is a false alarm');
```

The filter reloads within 5 minutes; call `analysis.self_activity_filter.refresh_rules()` to force it.

## The reviewer agent

Run on the dev/ops box (needs `claude.exe`; `CLAUDE_BIN` env overrides the path):

```
python -m analysis.self_activity_agent                # review last 72h, print report (no changes)
python -m analysis.self_activity_agent --limit 40
python -m analysis.self_activity_agent --apply          # insert proposals INACTIVE (is_active=false) for review
python -m analysis.self_activity_agent --apply --activate   # insert ACTIVE (enforced immediately)
python -m analysis.self_activity_agent --explain SEC-SQL-AUTHZ-001-RC01   # plain-English explainer
```

Proposals default to **inactive** — review them in `analysis.suppression_rules`,
then flip `is_active = true` (or run with `--activate`). Only inventory-type
detections whose collected result you want gone from gmmr should be activated.

## Verify a rule works

```
python -m analysis.self_activity_filter "<the query text>" <metric_name> <vendor>
# prints: suppress: True/False | rule: <name> | loaded rules: N
```
