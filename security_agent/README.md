# Security agent - installing on another server

The agent reads the query that tripped a detection rule, looks up what that
server has actually been observed running, asks a **local** language model
whether the query is a genuine security finding or normal application traffic,
and writes the answer into `alerts.alert_log.metadata` as `reason`.

It **never suppresses an alert**. Every alert fires exactly as it would without
the agent; it only adds an explanation. Suppression exists behind a separate
switch that is off by default and should stay off until the verdicts have been
reviewed against real traffic.

Triage runs **after** the alert is dispatched, not inside it. Alert latency is
never affected by the model.

---

## 1. What ships in the payload

| Path | What it is |
|---|---|
| `dbdome_service.exe`, `dbdome_dbanalytics.exe` | the service (agent code is compiled in) |
| `OllamaSetup.exe` | 1.49 GB - Ollama installer, so the install needs no internet |
| `ollama_models\` | 2.03 GB - pre-pulled `phi3:mini-128k` store |
| `secagent\dbdome_secagent.exe` | llama.cpp sidecar (its own `_internal`, do not merge) |
| `security_agent\models\Phi-3.1-mini-128k-instruct-Q4_K_M.gguf` | 2.23 GB - sidecar model, used only when Ollama is unavailable |
| `_internal\security_agent\rules.json` | threat rules + the root-cause catalogue |
| `_internal\sql_scripts\76*.sql` | database objects (see step 3) |

## 2. Turn it on

One line in `<bin>\.env`:

```
SECURITY_AGENT_ENABLED=true
```

That is the whole minimum. Everything else has a working default.

## 3. Apply the database objects

Run these once against the DBDOME database. All are idempotent.

```
sql_scripts\7600_security_agent_verdict.sql          -- verdict audit trail (REQUIRED)
sql_scripts\7620_gmmr_server_entry_index.sql         -- (server, entry_date) index (STRONGLY recommended)
sql_scripts\7630_security_agent_resultset.sql        -- read the verdict back out (REQUIRED)
sql_scripts\7640_security_agent_annotate_process.sql -- registers the sweep (REQUIRED, needs 7630)
sql_scripts\7610_ransomware_sequence.sql             -- ransomware sequence rule (optional)
```

**7600** is required or no verdict records at all.

**7620** is close to required in practice. Without it the precedent lookup was
measured at 3.19 s warm and roughly 50 minutes cold, because the plan walked
678,529 rows of one partition to find none for the server. With it: 0.023 s.
It takes a `SHARE` lock while building, so apply it during a collection pause.

**7630 + 7640** are what make the agent actually run. 7640 registers the
annotation sweep and refuses to install without 7630, because the sweep uses
`monitoring.fn_metadata_object()` from it.

**7610** registers `ransomware_sequence_detect` as INACTIVE. Review
`ransomware_min_distinct_ops` (4) and `ransomware_window_minutes` (5) in
`config.global_params` against the site's real traffic before enabling it, or a
nightly maintenance job will alert every night.

## 4. Runtime - nothing to choose

The media carries **both** runtimes, so there is no decision to make and no
network needed:

* the installer sets Ollama up from `OllamaSetup.exe`, stages the pre-pulled
  model store machine-wide, and registers it as the `DBDOME_Ollama` service.
  This is what normally serves the model.
* `security_agent\models\Phi-3.1-mini-128k-instruct-Q4_K_M.gguf` backs the
  bundled llama.cpp sidecar, for machines where Ollama cannot be installed.

`SECURITY_AGENT_BACKEND=auto` (the default) prefers Ollama when it is reachable
with the model present, and falls back to the sidecar otherwise. Both installers
warn loudly if neither is usable: an agent with no model fails open, so alerts
still fire, they just arrive without a reason.

To force one, set `SECURITY_AGENT_BACKEND=ollama` or `=sidecar`. For the sidecar
also set
`SECURITY_AGENT_MODEL=security_agent/models/Phi-3.1-mini-128k-instruct-Q4_K_M.gguf`.

**Q4_K_M rather than plain q4 is deliberate.** The plain-q4 build was observed
emitting stray tokens inside its JSON (`"confidence": 0 Cookies`), which the
classifier then has to repair field by field. K_M quantization behaves better
for structured output.

Measured on the dev box, same three cases, same prompt:

| | sidecar | Ollama `phi3:mini-128k` |
|---|---|---|
| warm latency | 60.7 s | **20.8-29.2 s** |
| cold (first call) | 126.5 s | 47.8 s |
| malformed JSON | needed field salvage | none |
| extra resident memory | ~2.3 GB | ~3.6 GB while loaded |

### Why Ollama runs as a service

The vendor installer is **per-user** and drops `Ollama.lnk` into the installing
account's Startup folder. That launches the tray app, which spawns
`ollama serve` under the logged-in user and binds 11434 - while DBDOME services
run as LocalSystem. Whenever that session was not running Ollama, the agent fell
back to the sidecar and reloaded the model per alert: 11 timeouts averaging
135 s, against 20.8 s warm.

The installers therefore disable the tray autostart, move the store to
`C:\ProgramData\DBDOME\ollama\models` with `OLLAMA_MODELS` set machine-wide, and
register `DBDOME_Ollama` via nssm (auto-start, LocalSystem, `keep_alive 24h`).

Disabling the shortcut is the part that matters. Registering the service alone
achieved nothing on the dev box: it reported healthy and `/api/tags` answered,
while the listener was still owned by the interactive user. **Check who owns the
port, not the service state:**

```
Get-NetTCPConnection -LocalPort 11434 -State Listen
```

The owning process should run as SYSTEM.

### Provisioning Ollama on an air-gapped server by hand

Only needed if the installer's Ollama step failed. The store is
content-addressed, so it can simply be copied - Ollama resolves the tag from the
manifest and never contacts the registry.

```
robocopy <bin>\ollama_models  C:\ProgramData\DBDOME\ollama\models  /E
setx /M OLLAMA_MODELS C:\ProgramData\DBDOME\ollama\models
```

Both subtrees matter: `blobs\` holds the weights, `manifests\` maps the tag
`phi3:mini-128k` onto them. Copying only `blobs\` leaves the tag unresolvable.

## 5. Verify

```
python -m security_agent.runner
```

Reports the resolved backend, whether the model is reachable, the rules version
and catalogue size. `available: True` means it will actually classify; `False`
means every alert fails open with a deterministic reason - safe, but the agent
contributes nothing.

After the first alerts:

```sql
SELECT decided_by, count(*), round(avg(elapsed_ms))
FROM alerts.security_agent_verdict GROUP BY 1;

SELECT * FROM alerts.v_security_agent_summary;
```

`decided_by='model'` is a real verdict. Anything else means the agent failed
open, and the value says why.

The Alerts dashboard also has two panels at the bottom: **Security Agent
Verdict** and **Alert Value**, both driven by the `$alert_id` variable.

---

## Settings

All in `<bin>\.env`. Changes need a `DBDOME_dbanalytics` restart, except
`rules.json`, which is re-read when it changes.

| Variable | Default | Notes |
|---|---|---|
| `SECURITY_AGENT_ENABLED` | `false` | the only one you must set |
| `SECURITY_AGENT_BACKEND` | `auto` | `auto` / `ollama` / `sidecar` |
| `SECURITY_AGENT_SUPPRESS` | `false` | **leave off.** Lets a verdict stop an alert |
| `SECURITY_AGENT_ANNOTATE_INLINE` | `false` | **leave off.** `true` puts triage back in the alert path |
| `SECURITY_AGENT_ANNOTATE_BATCH` | `25` | alerts annotated per sweep |
| `SECURITY_AGENT_ANNOTATE_LOOKBACK_MIN` | `120` | how far back the sweep looks |
| `SECURITY_AGENT_OLLAMA_MODEL` | `phi3:mini-128k` | |
| `SECURITY_AGENT_OLLAMA_URL` | `http://127.0.0.1:11434` | loopback; nothing leaves the box |
| `SECURITY_AGENT_OLLAMA_KEEP_ALIVE` | `24h` | `-1` keeps it loaded forever |
| `SECURITY_AGENT_TIMEOUT_SECS` | `90` | per alert; exceeded means no reason attached |
| `SECURITY_AGENT_MODEL` | bundled GGUF | sidecar backend only |
| `SECURITY_AGENT_DOMAINS` | `*` | which alert domains get annotated |
| `SECURITY_AGENT_MIN_CONFIDENCE` | `0.75` | only consulted if suppression is on |

## Rules

`_internal\security_agent\rules.json` is editable **on the installed box** and
re-read when its timestamp changes - no restart, no rebuild. It holds the
hand-written threat shapes (ransomware, injection, exfiltration, recon) plus a
catalogue of the product's own root causes, injected one entry at a time for the
alert being judged.

Regenerate the catalogue from a site's own root causes:

```
python -m security_agent.build_rules --domains SEC
```

It reports the resulting prompt size in tokens and refuses to exceed the budget,
because rules that crowd out the evidence make every verdict worse.

## Known limitations

* **Latency is real** - 20-60 s per alert depending on backend. It runs after
  the alert is dispatched, so nothing waits on it.
* **Verdicts are not yet trustworthy enough to suppress.** Benign queries have
  been classified as alerts, and reasons have contained factual slips about the
  query. Annotate-only is the supported mode.
* **The agent needs precedent to be useful.** With no recent rows in
  `monitoring.general_metric_metadata_results` there is nothing to compare
  against, and it will alert on everything - correctly by its own logic, but
  uselessly. Collection must be running.
