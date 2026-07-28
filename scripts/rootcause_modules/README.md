# rootcause module scripts — scaffold + generator

Toolkit to turn the security **module plans** in `C:\dev\PLANS` into
`insert_<module>_rootcause.sql` scripts that seed the `rootcause` schema for all
database vendors, matching the existing hand-written scripts (e.g.
`../insert_pii_sensitive_columns_rootcause.sql`).

## Why a generator (and not 6 hand-written SQL files)
The `PLANS/*_PLAN.md` and `*_DETECTION.md` files are **prose** — they list
root-cause IDs and descriptions but not the complete per-vendor detection SQL.
The authoritative data (per-vendor detection paths) lives in the modules'
`*_detection.json` knowledge files (in the dbexpertai backend), which are **not**
in this repo. Rather than fabricate hundreds of detection queries, this toolkit:

1. **Scaffolds** the `rootcause` schema (`00_rootcause_schema.sql`).
2. Provides a **generator** (`gen_rootcause_module.py`) that renders a full,
   pattern-correct insert script from a compact per-module **spec** (`specs/*.json`).
3. Ships **one worked example** (`specs/insider_threat.json` →
   `insert_insider_threat_rootcause.sql`) with real PostgreSQL detection SQL for
   the catalog-native insider root causes, and **stub specs** for the other five
   modules to fill in.

## Files
| File | Purpose |
|---|---|
| `00_rootcause_schema.sql` | Idempotent DDL for the `rootcause.*` tables (for fresh/dev DBs; no-op where they exist). |
| `gen_rootcause_module.py` | Spec (JSON) → `insert_<module>_rootcause.sql`. |
| `specs/_template.json` | Blank spec to copy. |
| `specs/insider_threat.json` | Worked example (6 RCs; 3 with real PostgreSQL SQL, 3 feed-dependent = TODO). |
| `specs/{ai_exfiltration,ai_agent,cloud_misconfig,supply_chain,dos_resource}.json` | Stubs to fill. |
| `insert_insider_threat_rootcause.sql` | Generated worked output. |

## Modules / area codes
| Module | spec | area code | source plan |
|---|---|---|---|
| Module | spec | area | status |
|---|---|---|---|
| Supply Chain | `supply_chain.json` | `SCP` ✓ | **filled** — 36 RCs; 29 detection steps (21 PostgreSQL + 8 vendor: SCP‑021/023/030/036 SQL Server, 023/034 Oracle, 029/033 MySQL); 15 detect TODO (baseline/other-vendor) |
| SQL Injection | `sql_injection.json` | `INJ` ✓ | **filled** — 54 RCs; core INJ‑001..016 have real per‑vendor SQL (13 RCs, 24 steps across pg/mysql/mssql/oracle); red‑team INJ‑017..054 catalogued, detect TODO |
| Ransomware | `ransomware.json` | `RAN` ✓ | **catalog** — 71 RCs parsed from the doc's enumerated detections; detect TODO (module JSON lists 197 total) |
| Worms | `worms.json` | `WRM` ✓ | **catalog** — 164 RCs parsed from the doc; detect TODO (module JSON lists 154) |
| Insider Threat | `insider_threat.json` | `INS` ✓ | example — 6 RCs (3 PostgreSQL SQL) |
| AI Agent | `ai_agent.json` | `AGT` ✓ | stub |
| AI Exfiltration | `ai_exfiltration.json` | `AIX`? | stub |
| Cloud Misconfig | `cloud_misconfig.json` | `CLD`? | stub |
| DoS / Resource | `dos_resource.json` | `DOS`? | stub |

> Confirmed area codes: `SCP/INJ/RAN/WRM/INS/AGT`. Stub codes `AIX/CLD/DOS` are
> placeholders — confirm against the module's `*_DETECTION.md` / knowledge JSON.
>
> **Catalog vs filled:** "catalog" specs register every root cause (so they exist
> under `rootcause` for all vendors, each with a `monitoring.v_<rc>` view) but
> leave `detect` = null. Faithful per‑vendor detection SQL for the large modules
> (ransomware 197 / worms 154) needs the module knowledge JSON — point me at the
> `*_detection.json` files and I'll extend the generator to convert them.
>
> Builders that produce the filled specs (run to regenerate the JSON):
> `specs/_build_supply_chain.py`, `specs/_build_sql_injection.py`.
> `specs/build_spec_from_doc.py <doc> <module> <AREA>` parses a DETECTION.md into a catalog spec.

## Workflow
1. (Fresh DB only) run `00_rootcause_schema.sql`.
2. Fill a spec: copy `specs/_template.json` → `specs/<module>.json`, add one
   object per root cause; put the real per-vendor SQL in `detect.<vendor>`
   (leave `null` for vendors not done yet — they're skipped).
3. Generate:
   ```
   python gen_rootcause_module.py specs/<module>.json > insert_<module>_rootcause.sql
   ```
4. Review, then load (psql as a role that owns the `rootcause`/`monitoring`
   schemas), or drop it into the service `sql_scripts/` folder so
   `sql_script_runner` applies it on startup.

## What each generated script produces (per the existing pattern)
- `rootcause.root_causes` (upsert on `root_cause_id`)
- `rootcause.detection_steps` — one per vendor with non-null `detect` SQL (`content->>'sql'`)
- `rootcause.detection_paths` + `detection_path_steps`
- `rootcause.resolution_steps` + `resolution_paths` + `resolution_path_steps`
- `monitoring.v_<rc>` view (expands `metric_metadata` to the spec's `columns`)
- a verify `SELECT`

## Fastest path to *complete* coverage
If you can provide the `*_detection.json` knowledge files (or point me at the
dbexpertai backend), I can extend `gen_rootcause_module.py` to convert them
directly — producing every root cause and per-vendor detection path faithfully,
instead of hand-filling the specs.
