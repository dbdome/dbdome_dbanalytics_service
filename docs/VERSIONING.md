# DBDOME versioning

## The number

```
2 . 01 . 043
│    │    └── Build_No — entered by the operator at every rebuild
│    └─────── MINOR    — product decision, zero-padded to 2 digits
└──────────── MAJOR    — product decision
```

`MAJOR` and `MINOR` live in exactly one place, `utils/version.py`
(`VERSION_MAJOR = 2`, `VERSION_MINOR = 1`). Nothing else hardcodes them — the
installers and the SQL formatter derive from the same pair. Changing the
product version is a one-line edit there.

`Build_No` is **not** derived, auto-incremented or taken from git. It is typed
in at build time, on purpose: the number is a human statement of "this is the
build I am shipping", and the prompt is the moment you decide it.

Zero padding is cosmetic but load-bearing — `2.01.043` sorts and reads
consistently, and `config.format_version()` produces the identical string in
SQL so the DB and the binary can never disagree about formatting.

---

## The build process

```powershell
cd C:\dev\dbdome_dbanalytics_service
.\build.ps1
```

```
=== DBDOME versioned build ===
  Last build: 2.01.042  (2026-08-06 16:28)
              LDAP transport diagnosis
  Build_No [043]: ⏎              <- Enter accepts, or type any number
  Notes    : adaptive thresholds

  -> building 2.01.043
```

What it does, in order:

| # | Step | Detail |
|---|------|--------|
| 1 | Ask | Reads `config.next_build_no()`, pre-fills last+1, prompts for `Build_No` and notes |
| 2 | Stamp | Writes `utils/version_build.json` — the spec bundles it into the exe |
| 3 | Service | PyInstaller → `dist_rd\dbdome_dbanalytics\`, aborts if an exe is under 30 MB (wrong venv) |
| 4 | Installers | Same stamp copied to both installer repos, then `dbdome_setup.exe` + `dbdome_update.exe` |
| 5 | Sign | Authenticode with the `dbdome` cert, if `signtool` and the cert are present |
| 6 | Record | `config.set_version()` for all three components |

Flags: `-BuildNo 44 -Notes "..."` to skip the prompts (CI), `-SkipInstallers`
for a service-only build.

Deployment is deliberately **not** part of `build.ps1`. Build, inspect, then
deploy to the bins, refresh the media and rebuild the ISOs.

### Where the number is baked in

`utils/version.py` resolves `Build_No` in this order:

1. `DBDOME_BUILD_NO` in the environment — a one-off override
2. `version_build.json`, looked for beside the module, inside `_internal`, and
   next to the exe (so a wrong number can be corrected in the field without a
   rebuild)
3. `0`

**Build `000` means the binary was not produced by `build.ps1`.** A dev
checkout reports `2.01.000`, and so does any ad-hoc `pyinstaller` run. That is
the intended signal, not a bug.

---

## The table — `config.app_version`

Created by `sql_scripts/7440_app_version.sql`. One row per build, so it is
simultaneously the current-version record and the build history.

| Column | Type | Notes |
|--------|------|-------|
| `row_id` | serial | PK |
| `version` | text | `'2.01.043'`, unique |
| `major` / `minor` / `build_no` | smallint / smallint / int | the parts |
| `built_at` | timestamptz | when the build ran |
| `built_by` | text | OS user that ran `build.ps1` |
| `component` | text | `service` \| `setup` \| `update` |
| `notes` | text | what shipped |
| `is_current` | boolean | one true row per component (partial unique index) |

### Accessors

| Function | Returns | Used by |
|----------|---------|---------|
| `config.get_version(component)` | `'2.01.043'` | API, scripts |
| `config.get_version_label(component)` | `'DBDOME v2.01.043 - built 2026-08-08'` | **the dashboards** |
| `config.format_version(maj,min,bld)` | `'2.01.043'` | shared formatting |
| `config.set_version(maj,min,bld,by,notes,comp)` | the version string | `build.ps1`, service startup |
| `config.next_build_no(component)` | `44` | the build prompt |
| `config.v_app_version` | history, newest first | support / About panel |

`get_version_label()` returns `'DBDOME - version not registered'` rather than
NULL when nothing is recorded — a NULL would render as the word "null" in a
Grafana text panel.

### Who writes it

- **The running service**, at startup: `dbdome_main.py` runs the migrations and
  then `utils.version.register()` in the same thread. This ordering matters —
  `config.set_version` ships in 7440, so on an upgrade it does not exist until
  the migrations have been applied.
- **`build.ps1`**, at step 6.

Because the service registers itself, the table describes the binary that is
**actually running**, not merely the last one somebody built.

---

## Where to find the version

### 1. On every dashboard — bottom of the left nav rail

All 102 dashboards carry it. Scroll to the bottom of the left-hand navigation
panel:

```
  **Dashboards**
  **By sequence**
  - 1. Alerts
  - 2. Data Discovery & Classification
    ...
  ─────────────────────────────
  DBDOME v2.01.043 - built 2026-08-08
```

Placement, always at the bottom of the page:

| Placement | Count | Which |
|-----------|-------|-------|
| Appended to the left nav rail (`x=0, w≤5`) | 93 | the standard nav rail |
| New full-width `24×1` footer panel at the bottom | 9 | Alerts, main, dbdome nav, RBAC, Anonymization, Static/Dynamic Masking, Tokenization, Ransomware Guard |

A text panel is only appended to when it genuinely sits at the bottom of the
board. That test matters: several dashboards (Alerts, the masking family) have
exactly one text panel and it is a **header** at `y=0` — appending there puts
the version inside a styled banner at the top of the page, which is not a
footer by any reading. Those get their own panel instead. A left rail is
exempt from the test because it runs the full height of the page, so its
bottom already is the bottom-left corner.

Every pass **strips any previous footer first, then places fresh**, so the tool
can move a footer when the rules change rather than layering on top of a bad
placement. Panels it created are tagged `dbdomeVersionPanel` and removed
cleanly; panels it appended to record `dbdomeVersionPad` so the extra rows are
handed back if the footer later moves elsewhere.

> **Grafana strips unknown panel keys.** Its dashboard schema migration runs on
> load and re-saves the board, dropping `dbdomeVersionPanel` / `dbdomeVersionPad`
> and normalising `gridPos` (seen on `Alerts`: tag gone, `y` 34 → 35). The tool
> therefore does not trust those tags — it also detects a footer panel
> structurally, as a text panel whose content is *nothing but* the footer. Without
> that fallback a re-run would strand an empty 1-row panel and add a second
> footer beside it.

**This does not need re-running on every build.** The footer contains
`$dbdome_version`, a hidden dashboard variable (`hide: 2`, `refresh: 1`) that
queries `config.get_version_label()` on every dashboard load — modelled on the
existing `$global_ip` / `config.get_local_ip()` variable. A new build updates
one DB row and all 102 dashboards follow.

Re-run the stamper only when dashboards are added or replaced:

```powershell
Stop-Service DBDOME_Grafana
python tools\add_version_footer_to_dashboards.py            # dry run
python tools\add_version_footer_to_dashboards.py --apply
Start-Service DBDOME_Grafana
```

It is idempotent and backs up `grafana.db` before writing. **Grafana must be
stopped** — it holds the SQLite file open and a live write can be lost.

### 2. From the API

```
GET https://<host>:8080/api/version
```

```json
{
  "ok": true,
  "running":    {"version": "2.01.043", "build_no": 43, "built_by": "yoram", "frozen": true},
  "registered": {"version": "2.01.043", "label": "DBDOME v2.01.043 - built 2026-08-08"},
  "in_sync": true
}
```

`in_sync: false` is the useful one: it means a bin was overlaid but the service
was never restarted, so the running code is not the code you think it is.

### 3. From the database

```sql
SELECT config.get_version_label();     -- current
SELECT * FROM config.v_app_version;    -- full history, newest first
```

### 4. In the service log

Startup writes one line:

```
[version] running DBDOME v2.01.043
```

### 5. In the installers

`dbdome_setup.exe` and `dbdome_update.exe` print the version in their banner and
derive it from the same stamp, so a build's three artifacts always agree.

---

## Checklist for a release

1. `.\build.ps1` — answer the prompt
2. Deploy `dist_rd\dbdome_dbanalytics\` to `C:\ProgramData\DBDOME\bin` (stop
   services, overlay exes + `_internal`, start services)
3. Overlay the same onto `C:\installs\dbdome_setup\dbdome\bin` and
   `C:\installs\dbdome_update\dbdome\bin`
4. Copy the signed installers to the media roots
5. Prune `.bak` scratch from the media trees — it ships otherwise
6. `C:\installs\runscript\runiso.cmd` (or the two DBDOME lines from it)
7. Confirm: `GET /api/version` shows `in_sync: true`, and the rail footer on any
   dashboard shows the new number
