# DBDOME Installation Guide

**Product:** DBDOME Database Security and Monitoring Platform
**Applies to:** DBDOME 2.02.x
**Document version:** 1.0
**Date:** 2026-08-23
**Audience:** System administrators and DBAs performing installation
**Classification:** Customer deliverable

---

## 1. Scope

This guide covers a fresh installation, an in-place upgrade, verification and
rollback of DBDOME on a Windows Server host. It documents the offline
(air-gapped) installation path, which is the supported default: **no internet
access is required at any point.**

Read Section 3 (Prerequisites) and Section 5 (Pre-install checklist) in full
before running any installer. Most failed installations are traced to a
prerequisite in Section 3 rather than to the installer itself.

---

## 2. What DBDOME installs

| Component | Windows service | Port | Purpose |
|---|---|---|---|
| DBDOME collection engine | `DBDOME_dbanalytics` | — | Collects metrics, evaluates rules, raises alerts |
| DBDOME web interface | `DBDOME_web` | 8080/HTTPS | Configuration UI, APIs |
| Grafana OSS 12.2.0 | `DBDOME_Grafana` | 3000 | Dashboards, alert views |
| Ollama runtime | `DBDOME_Ollama` | 11434 (loopback) | Serves the local AI model |
| PostgreSQL 18 | `postgresql-x64-18` | 5432 | DBDOME repository database |

**Standard paths**

```
C:\ProgramData\DBDOME\bin              program files, .env, legal notices
C:\ProgramData\DBDOME\data             Grafana data, dashboards, plugins
C:\ProgramData\DBDOME\ollama\models    AI model store (machine-wide)
C:\ProgramData\DBDOME\bin\logs         service logs
```

---

## 3. Prerequisites

### 3.1 Hardware

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores | 8 cores |
| RAM | 16 GB | 32 GB |
| Free disk | 60 GB | 120 GB |

The AI security agent holds roughly **3.6 GB resident** while the model is
loaded. Size RAM accordingly, or leave the agent disabled (Section 8).

Disk sizing must account for the repository database growing with the number of
monitored servers and the retention period. Alert and metric tables are
partitioned, but partitions still consume space.

### 3.2 Operating system

* Windows Server 2019, 2022 or 2025 (x64). Windows 10/11 x64 is supported for
  evaluation only.
* An account with **local Administrator** rights.
* PowerShell 5.1 or later.

> **Elevation is mandatory.** Service registration, firewall rules,
> `setx /M` and `icacls` all fail silently or partially from a non-elevated
> shell. Right-click the installer and choose **Run as administrator**.

### 3.3 Network and ports

| Port | Direction | Purpose |
|---|---|---|
| 8080/TCP | inbound | DBDOME web UI (HTTPS) |
| 3000/TCP | inbound | Grafana |
| 5432/TCP | local | PostgreSQL |
| 11434/TCP | **loopback only** | Ollama. Must not be exposed. |
| target DB ports | outbound | 1433 MSSQL, 1521 Oracle, 3306 MySQL/MariaDB, 5432 PostgreSQL, 27017 MongoDB, 8123 ClickHouse |
| 25/587/465 | outbound | SMTP for alert mail, if used |
| 514 | outbound | Syslog/SIEM, if used |

### 3.4 Accounts required

* **Local Administrator** on the DBDOME host.
* A **read-only monitoring login on each target database.** DBDOME requires only
  the privileges needed to read system and dynamic management views. Do not
  grant `sysadmin`, `DBA` or ownership. Blocking and masking features, if
  enabled later, require additional privileges — grant those only when the
  feature is deliberately adopted.

### 3.5 Legal prerequisite

Read `EULA.txt` and `THIRD_PARTY_NOTICES.txt` at the root of the installation
media **before installing.** Installation constitutes acceptance of the DBDOME
EULA and of the Microsoft license terms governing the bundled ODBC driver.

Confirm you have a lawful basis for monitoring before you point DBDOME at a
production database — DBDOME observes statement text, login identities and
client program names. In many jurisdictions this requires prior notification of
employees, and may require works-council consultation or a data protection
impact assessment. This is the customer's responsibility under EULA Section 4.1,
and it must be settled before, not after, go-live.

---

## 4. Installation media

| Media | Size | Use |
|---|---|---|
| `dbdome_setup` | ~6.5 GB | Fresh installation |
| `dbdome_update` | ~6.5 GB | Upgrade of an existing installation |

Both are fully self-contained: PostgreSQL, the Microsoft ODBC driver, Grafana,
the Ollama installer, the AI model in both runtime formats, and all SQL scripts.

**Verify the media before use.** Confirm the total size is within ~50 MB of the
figure above. A short copy — common when media is transferred over an unreliable
link — typically truncates the largest files, which are the AI model and the
Ollama installer, and surfaces much later as an unexplained agent failure.

---

## 5. Pre-install checklist

Complete every line before starting.

- [ ] Installer will be run **as Administrator**
- [ ] Host meets Section 3.1 sizing
- [ ] Ports in Section 3.3 are free (`netstat -ano | findstr ":8080 :3000 :5432"`)
- [ ] No existing PostgreSQL on 5432 that must be preserved
- [ ] Read-only monitoring credentials obtained for each target
- [ ] Target databases reachable from this host (test with `Test-NetConnection`)
- [ ] Host has a **static LAN IP**, or a permanent DHCP reservation
- [ ] Full backup / VM snapshot taken (upgrades especially)
- [ ] EULA and third-party notices reviewed
- [ ] Lawful basis for monitoring confirmed
- [ ] Maintenance window agreed

> **Static IP matters.** DBDOME records the host's LAN IP in `.env` as `ORG_IP`
> and in the database as `config.local_ip`. Grafana datasources and ingest URLs
> are built from it. If the address changes, dashboards and ingest break until
> it is refreshed. The updater refreshes it automatically (update step 13); a
> fresh install does not, so get it right at install time.

---

## 6. Fresh installation

### 6.1 Procedure

1. Copy the `dbdome_setup` media to a local drive. **Do not run it from a network
   share or mounted ISO** — several steps write back into the payload directory.
2. Right-click `dbdome_setup.exe` → **Run as administrator**.
3. Accept the EULA when prompted.
4. Provide the installation path (default `C:\ProgramData\DBDOME`) and the
   PostgreSQL superuser password when asked. **Record that password**; it cannot
   be recovered from the installation.
5. Let the installer run to completion without interruption.

### 6.2 What the installer does

The installer prints numbered steps to the console and to its log. Note that the
**printed step numbers do not run in numeric order** — steps 16 and 17 were added
later and execute out of sequence. This is cosmetic; follow the console order,
not the numbers.

| Order | Step | Action |
|---|---|---|
| 1 | 1 | Copy DBDOME files |
| 2 | 2 | Install Microsoft ODBC Driver for SQL Server |
| 3 | 3 | Install PostgreSQL 18.3 |
| 4 | 4 | Configure `pg_hba.conf` |
| 5 | 5 | Create database and users |
| 6 | 6 | Restore the `dbanalytics` baseline database |
| 7 | 7 | Configure Grafana |
| 8 | 8 | Create configuration files (`.env`) |
| 9 | **17** | Provision the security-agent model (Ollama + model store) |
| 10 | 9 | Configure Windows Firewall |
| 11 | **16** | Trust the DBDOME code-signing certificate |
| 12 | 10 | Install DBDOME dbanalytics Windows service(s) |
| 13 | 11 | Start DBDOME services |
| 14 | 12 | Validate installation |
| 15 | 13 | Create desktop shortcut |
| 16 | 14 | Install the DBDOME Grafana Windows service |
| 17 | 15 | Restart Grafana to clear plugin issues |

### 6.3 Expected duration

25–50 minutes, dominated by the PostgreSQL install, the database restore and the
Ollama/model provisioning step.

---

## 7. Post-install verification

Run every check. An installer that reported success is not proof that the
platform is collecting.

### 7.1 Services

```powershell
Get-Service DBDOME_dbanalytics, DBDOME_web, DBDOME_Grafana, DBDOME_Ollama, postgresql-x64-18 |
  Format-Table Name, Status, StartType
```

All five must be **Running** and **Automatic**.

### 7.2 Web interfaces

* `https://<host>:8080` — DBDOME configuration UI
* `http://<host>:3000` — Grafana

> **If 8080 is unreachable from another machine but works locally**, the cause is
> almost always the Windows Firewall profile. When the network adapter is
> classified as **Public**, the DBDOME rule may be scoped to Private/Domain only
> and the port is silently dropped. Check with:
>
> ```powershell
> Get-NetConnectionProfile
> Get-NetFirewallRule -DisplayName "*DBDOME*" | Get-NetFirewallProfile
> ```
>
> Either reclassify the adapter as Private, or widen the rule's profile.

### 7.3 Database

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d dbanalytics -c "\dn"
```

Expect schemas including `monitoring`, `alerts`, `metrics`, `config`,
`rootcause`, `log`.

### 7.4 Collection is actually running

This is the check that matters. Roughly 10 minutes after start-up:

```sql
SELECT max(entry_date) FROM monitoring.general_metric_metadata_results;
```

The timestamp must be recent and must keep advancing. If it is static, no
collection is occurring regardless of service state.

### 7.5 Local IP recorded correctly

```powershell
Select-String -Path "C:\ProgramData\DBDOME\bin\.env" -Pattern "^ORG_IP="
```

It must equal the host's LAN IP, not `127.0.0.1` and not a stale address.

---

## 8. Security agent (AI triage) — optional

The agent reads the query that tripped a rule, compares it against what that
server has been observed running, and writes a plain-language reason onto the
alert. It runs **after** the alert is dispatched, so it never delays alerting.

### 8.1 Enable

In `C:\ProgramData\DBDOME\bin\.env`:

```
SECURITY_AGENT_ENABLED=true
```

Restart `DBDOME_dbanalytics`. That is the entire minimum configuration —
everything else has a working default.

### 8.2 Required database objects

Apply once, in this order. All are idempotent.

| Script | Status |
|---|---|
| `7600_security_agent_verdict.sql` | **Required** — verdict audit trail |
| `7620_gmmr_server_entry_index.sql` | **Strongly recommended** — see below |
| `7630_security_agent_resultset.sql` | **Required** — reads verdicts back |
| `7640_security_agent_annotate_process.sql` | **Required** — registers the sweep; needs 7630 |
| `7610_ransomware_sequence.sql` | Optional — ransomware sequence rule |

**7620 is close to mandatory in practice.** Without it the precedent lookup was
measured at 3.19 s warm and roughly 50 minutes cold, because the query plan
walked 678,529 rows of a partition to find none for that server. With the index:
0.023 s. It takes a `SHARE` lock while building — apply it during a collection
pause.

**7610 installs INACTIVE by design.** Review `ransomware_min_distinct_ops` (4)
and `ransomware_window_minutes` (5) in `config.global_params` against the site's
real traffic before enabling, or routine nightly maintenance will alert every
night.

### 8.3 Verify the agent

```powershell
cd C:\ProgramData\DBDOME\bin
.\dbdome_dbanalytics.exe --check-security-agent
```

Reports the resolved backend and model availability. `available: True` means it
will classify. `False` means every alert **fails open** — alerts still fire, they
simply arrive without a reason attached. That is safe, but the agent contributes
nothing.

After the first alerts:

```sql
SELECT decided_by, count(*), round(avg(elapsed_ms))
FROM alerts.security_agent_verdict GROUP BY 1;
```

`decided_by='model'` is a genuine verdict. Any other value means the agent failed
open, and the value states why.

### 8.4 Confirm Ollama is owned by the service

The Ollama vendor installer is **per-user** and adds a tray shortcut to the
installing account's Startup folder. That tray app binds port 11434 as the
logged-in user, while DBDOME runs as LocalSystem. When that user is not logged
in, the port is unowned and the agent falls back to the slower sidecar.

Checking the service state is **not sufficient** — it will report Running and
`/api/tags` will answer while the port belongs to the interactive user. Check
port ownership instead:

```powershell
Get-NetTCPConnection -LocalPort 11434 -State Listen |
  ForEach-Object { (Get-Process -Id $_.OwningProcess).ProcessName }
```

The owning process must run as **SYSTEM**. If not, disable the `Ollama.lnk`
Startup shortcut, end `ollama app.exe`, then restart `DBDOME_Ollama`.

### 8.5 Operating limits — read before relying on it

* Verdicts are **not yet trustworthy enough to suppress alerts.** Benign queries
  have been misclassified, and reasons have contained factual slips about the
  query. Annotate-only is the supported mode; suppression is off by default and
  should stay off.
* The agent needs precedent. With no recent rows in
  `monitoring.general_metric_metadata_results` it has nothing to compare against
  and will flag everything — correct by its own logic, useless in practice.
  Collection must be healthy first.
* Triage takes 20–60 s per alert depending on backend. This never delays the
  alert itself.

---

## 9. Upgrading an existing installation

### 9.1 Before you start

- [ ] **Full database backup**, verified restorable
- [ ] VM snapshot if available
- [ ] Current version and `.env` recorded
- [ ] Maintenance window agreed — collection stops during the upgrade

### 9.2 Procedure

1. Copy the `dbdome_update` media locally.
2. Right-click `dbdome_update.exe` → **Run as administrator**.
3. Let it run to completion.

The updater performs, in printed order:

| Step | Action |
|---|---|
| 1 | Preflight checks |
| 2 | Stop DBDOME services |
| 3 | Replace files, reinstall services |
| 4 | Start DBDOME services |
| 5 | Stop Grafana |
| 6 | Replace `grafana.db` |
| 7 | Start Grafana |
| 8 | Base schema install |
| 9 | Run numbered SQL scripts |
| 10 | Encrypt secrets (`.env` and stored passwords) |
| 11 | Trust code-signing certificate |
| 13 | Refresh local IP in `.env` and `config.local_ip` |
| 12 | Provision security-agent model |

As with setup, printed step numbers are not in execution order.

### 9.3 Preserving local customization

> **`.env` is not fully preserved by a file replace.** The payload ships a
> template `.env`. The updater merges managed keys, but any key you added
> manually should be recorded before upgrading and re-checked afterwards.

Back up before upgrading:

```powershell
Copy-Item C:\ProgramData\DBDOME\bin\.env `
          "C:\ProgramData\DBDOME\bin\.env.backup_$(Get-Date -f yyyyMMdd)"
```

`rules.json` under `bin\_internal\security_agent\` is editable on the installed
box and **is replaced by an upgrade.** Back it up if you have customized it.

### 9.4 After upgrading

Repeat every check in Section 7, plus:

```sql
SELECT max(entry_date) FROM monitoring.general_metric_metadata_results;
```

Confirm collection resumed. Then confirm the scheduler picked up all processes:

```sql
SELECT process_name, is_active FROM metrics.registered_processes ORDER BY 1;
```

> A process row can be `is_active=true` and still never run, if the build does
> not map that name to a function. The symptom is silence rather than an error.
> If a feature is enabled but producing nothing, check the service log for
> `Unknown process name` entries.

---

## 10. Rollback

1. Stop all DBDOME services.
2. Restore the VM snapshot, **or**: restore the database backup and restore the
   previous `bin` directory and `.env`.
3. Start services and verify with Section 7.

There is no automated downgrade. Rollback depends entirely on the backup taken
in Section 9.1 — this is why that step is not optional.

---

## 11. Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Services will not start | Non-elevated install, or PostgreSQL down | Check `bin\logs`; confirm `postgresql-x64-18` is running |
| 8080 works locally, not remotely | Firewall profile is Public | Section 7.2 |
| Grafana loads, panels empty | Datasource points at a stale IP | Check `ORG_IP`; re-run updater to refresh |
| No alerts at all | Collection not running | Section 7.4 |
| Alerts fire with no reason attached | Agent disabled, no model, or sweep not registered | Sections 8.1–8.3 |
| Agent slow, frequent timeouts | Ollama port owned by interactive user | Section 8.4 |
| `Login failed for <user> (18456)` plus `4060 Cannot open database None` | Target configured with a NULL database, not bad credentials | Set the database on the target definition; connections default to `master` |
| Installer fails on file copy, access denied | Payload ACLs restrict the running account | Re-run elevated; if it persists, grant modify rights on the payload directory |
| SQL script reports errors but exit 0 | Script partially applied | Read the end-of-run summary; a non-zero error-line count is a failure even at exit 0 |

**Log locations**

```
C:\ProgramData\DBDOME\bin\logs\        service logs
%TEMP%\dbdome_setup*.log               installer log
%TEMP%\dbdome_update*.log              updater log
```

Also check the `log` schema in the database, which records operational errors the
services could not write to disk.

---

## 12. Appendix A — `.env` reference

`C:\ProgramData\DBDOME\bin\.env`. Changes require a `DBDOME_dbanalytics` restart.

### Core

| Key | Purpose |
|---|---|
| `PG_HOST`, `PG_PORT`, `PG_DB`, `PG_USER`, `PG_PASSWORD` | Repository database connection |
| `ORG_IP` | **Host LAN IP.** Must be the real address, never loopback |
| `DBDOME_SECRET_KEY` | Encryption key for stored credentials |
| `GRAFANA_EXE`, `GRAFANA_WATCHDOG_INTERVAL` | Grafana process management |
| `ORACLE_CLIENT_LIB_DIR` | Oracle client path, if monitoring Oracle |
| `LLM` | Language-model integration setting |

> `PG_PASSWORD` and stored target passwords are encrypted at rest with the
> `enc:v1:` prefix. **`DBDOME_SECRET_KEY` is required to decrypt them.** Back it
> up somewhere other than the DBDOME host. Losing it means re-entering every
> stored credential.

### Security agent

| Key | Default | Notes |
|---|---|---|
| `SECURITY_AGENT_ENABLED` | `false` | The only key you must set |
| `SECURITY_AGENT_BACKEND` | `auto` | `auto` / `ollama` / `sidecar` |
| `SECURITY_AGENT_SUPPRESS` | `false` | **Leave off.** Lets a verdict withhold an alert |
| `SECURITY_AGENT_ANNOTATE_INLINE` | `false` | **Leave off.** Puts triage back in the alert path |
| `SECURITY_AGENT_ANNOTATE_BATCH` | `25` | Alerts annotated per sweep |
| `SECURITY_AGENT_ANNOTATE_LOOKBACK_MIN` | `120` | How far back the sweep looks |
| `SECURITY_AGENT_OLLAMA_MODEL` | `phi3:mini-128k` | |
| `SECURITY_AGENT_OLLAMA_URL` | `http://127.0.0.1:11434` | Loopback; nothing leaves the host |
| `SECURITY_AGENT_OLLAMA_KEEP_ALIVE` | `24h` | `-1` keeps the model loaded indefinitely |
| `SECURITY_AGENT_TIMEOUT_SECS` | `90` | Per alert; exceeded means no reason attached |
| `SECURITY_AGENT_MODEL` | bundled GGUF | Sidecar backend only |
| `SECURITY_AGENT_DOMAINS` | `*` | Which alert domains are annotated |
| `SECURITY_AGENT_MIN_CONFIDENCE` | `0.75` | Consulted only if suppression is on |

---

## 13. Appendix B — Licensing

DBDOME is proprietary software licensed under `EULA.txt`. It is distributed with
third-party components under their own licenses, documented in
`THIRD_PARTY_NOTICES.txt` with full texts in `bin\legal\licenses\`.

Points that affect installation decisions:

* **Microsoft ODBC Driver 18** is proprietary. Microsoft's own terms apply
  directly to you and are supplied verbatim on the media.
* **Grafana 12.2.0 and its plugins** are AGPL-3.0. They are redistributed
  unmodified. Your rights under the AGPL are not limited by the DBDOME EULA, and
  corresponding source is available on written offer.
* **Ollama and the Microsoft Phi-3 model** are MIT licensed.
* **PostgreSQL** is under the PostgreSQL License.
* **psycopg2 and paramiko** are LGPL. You may replace them with your own build.

Nothing in the DBDOME EULA restricts any right granted by an open source license.

---

## 14. Support

| | |
|---|---|
| Technical support | support@dbexpert.ai |
| Licensing | legal@dbexpert.ai |
| Open source requests | opensource@dbexpert.ai |

When raising an installation issue, attach the installer log from `%TEMP%`, the
output of the Section 7 verification commands, and the DBDOME version.

---

*Copyright (c) 2026 DBEXPERT. All rights reserved. DBDOME is a trademark of
DBEXPERT.*
