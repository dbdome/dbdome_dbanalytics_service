# Security agent — installing on another server

The agent reads the query that tripped a detection rule, looks up what that
server has actually been observed running, asks a **local** language model
whether the query is a genuine security finding or normal application traffic,
and writes the answer into `alerts.alert_log.metadata` as `reason`.

It **never suppresses an alert**. Every alert fires exactly as it would without
the agent; it only adds an explanation. Suppression exists behind a separate
switch that is off by default and should stay off until the verdicts have been
reviewed against real traffic.

---

## 1. What ships in the payload

Everything below is already in `<bin>\` after a normal deploy:

| Path | What it is |
|---|---|
| `dbdome_service.exe`, `dbdome_dbanalytics.exe` | the service (agent code is compiled in) |
| `secagent\dbdome_secagent.exe` | llama.cpp sidecar (its own `_internal`, do not merge) |
| `security_agent\models\Phi-3-mini-4k-instruct-q4.gguf` | 2.23 GB model for the sidecar |
| `_internal\security_agent\rules.json` | threat rules + the root-cause catalogue |
| `_internal\sql_scripts\7600,7610,7620*.sql` | database objects (see step 3) |

## 2. Turn it on

One line in `<bin>\.env`:

```
SECURITY_AGENT_ENABLED=true
```

That is the whole minimum. Everything else has a working default.

## 3. Apply the database objects

Run these once against the DBDOME database, in order. All are idempotent.

```
sql_scripts\7600_security_agent_verdict.sql     -- verdict audit trail (REQUIRED)
sql_scripts\7620_gmmr_server_entry_index.sql    -- (server, entry_date) index (STRONGLY recommended)
sql_scripts\7610_ransomware_sequence.sql        -- ransomware sequence rule (optional)
```

**7600 is required** — without it every verdict fails to record (caught and
logged, but the audit trail is empty).

**7620 is close to required in practice.** Without it the precedent lookup was
measured at 3.19 s warm and roughly 50 minutes cold, because the plan walked
678,529 rows of one partition to find none for the server. With it: 0.023 s.
It takes a `SHARE` lock while building, so apply it during a collection pause.

**7610 registers `ransomware_sequence_detect` as INACTIVE.** Review
`ransomware_min_distinct_ops` (4) and `ransomware_window_minutes` (5) in
`config.global_params` against the site's real traffic before enabling it, or a
nightly maintenance job will alert every night.

## 4. Runtime — Ollama is required

**The media no longer ships a model for the sidecar.** The installer installs
Ollama from `OllamaSetup.exe` in the payload and stages the pre-pulled
`phi3:mini-128k` store, so a normal install needs no action and no internet.

`SECURITY_AGENT_BACKEND=auto` (the default) still prefers Ollama and falls back
to the sidecar — but the sidecar now has **no model**, so if Ollama is missing
the agent is inert: alerts still fire, unannotated. Both installers warn loudly
when that happens; it is not a silent failure.

To fall back to the sidecar deliberately, drop a `.gguf` into
`<bin>\security_agent\models\` and set `SECURITY_AGENT_BACKEND=sidecar` plus
`SECURITY_AGENT_MODEL`. The sidecar executable still ships for exactly this.

Measured on the dev box, same three cases, same prompt:

| | sidecar (bundled GGUF) | Ollama `phi3:mini-128k` |
|---|---|---|
| warm latency | 60.7 s | **20.8–29.2 s** |
| cold (first call) | 126.5 s | 47.8 s |
| malformed JSON | needed field salvage | none |
| install needs internet | **no** | **yes**, for `ollama pull` |
| extra resident memory | — | ~3.6 GB while loaded |

**Air-gapped servers: still fine.** `OllamaSetup.exe` and the pre-pulled model
store both ship in the payload, so the installer needs no network — only the
build machine did, once, to fetch them.

If you are installing Ollama by hand instead:

```
winget install Ollama.Ollama --scope user     # or run bin\OllamaSetup.exe
ollama pull phi3:mini-128k                    # only if the machine has internet
```

Two caveats worth knowing:

* Ollama installs **per-user** under `%LOCALAPPDATA%\Programs\Ollama` and must
  be running. If the DBDOME service runs as a different account, point it at the
  server explicitly with `SECURITY_AGENT_OLLAMA_URL`, or install Ollama as a
  machine-wide service.
### Provisioning Ollama on an air-gapped server

`ollama pull` needs internet, which a customer database server usually does not
have. The model store is content-addressed, so it can simply be copied — Ollama
resolves the tag from the manifest and never contacts the registry.

The payload ships one: **`<bin>\ollama_models\`** (~2.03 GB), pulled and
verified on the build machine.

1. Install Ollama on the target (the installer itself is offline-capable —
   carry `OllamaSetup.exe`, or `winget install Ollama.Ollama --scope user` if
   the target has internet even though the model pull is disallowed).
2. Stop Ollama if it is running.
3. Copy the contents of `<bin>\ollama_models\` into the target's store:

   ```
   robocopy <bin>\ollama_models  %USERPROFILE%\.ollama\models  /E
   ```

   Both subtrees matter: `blobs\` holds the weights, `manifests\` maps the tag
   `phi3:mini-128k` onto them. Copying only `blobs\` leaves the tag unresolvable.
4. Start Ollama and confirm the tag is present:

   ```
   ollama list                       # phi3:mini-128k should appear
   curl http://127.0.0.1:11434/api/tags
   ```

   `/api/tags` is exactly what the agent's auto-detect probes, so if the tag
   shows there, the agent will select the Ollama backend on its next run.

**Account matters.** The store lives under the *user profile* of whoever runs
Ollama. If the DBDOME service runs as a different account, either copy the store
into that account's profile, run Ollama machine-wide as a service, or point the
agent at it explicitly with `SECURITY_AGENT_OLLAMA_URL`.

**Normally the installer does all of this for you** — this section is for
recovering an install where the Ollama step failed, or for moving the model to a
different account's profile.

## 5. Verify

```
python -m security_agent.runner            # from source
```

Reports the resolved backend, whether the model is reachable, the rules version
and catalogue size. `available: True` means it will actually classify;
`False` means every alert fails open with a deterministic reason — safe, but the
agent contributes nothing.

After the first alerts, review:

```sql
SELECT * FROM alerts.v_security_agent_summary;      -- verdicts per root cause
SELECT * FROM alerts.v_security_agent_suppressed;   -- empty unless suppression is on
```

---

## Settings

| Variable | Default | Notes |
|---|---|---|
| `SECURITY_AGENT_ENABLED` | `false` | the only one you must set |
| `SECURITY_AGENT_BACKEND` | `auto` | `auto` / `ollama` / `sidecar` |
| `SECURITY_AGENT_SUPPRESS` | `false` | **leave off.** Lets a verdict stop an alert |
| `SECURITY_AGENT_OLLAMA_MODEL` | `phi3:mini-128k` | |
| `SECURITY_AGENT_OLLAMA_URL` | `http://127.0.0.1:11434` | loopback; nothing leaves the box |
| `SECURITY_AGENT_TIMEOUT_SECS` | `90` | per alert; exceeded ⇒ alert fires unannotated |
| `SECURITY_AGENT_MODEL` | bundled GGUF | sidecar backend only |
| `SECURITY_AGENT_DOMAINS` | `*` | which alert domains get annotated |
| `SECURITY_AGENT_MIN_CONFIDENCE` | `0.75` | only consulted if suppression is on |

## Rules

`_internal\security_agent\rules.json` is editable **on the installed box** and
re-read when its timestamp changes — no restart, no rebuild. It holds the
hand-written threat shapes (ransomware, injection, exfiltration, recon) and a
catalogue of the product's own root causes, injected one entry at a time for the
alert being judged.

Regenerate the catalogue from a site's own root causes with:

```
python -m security_agent.build_rules --domains SEC
```

It reports the resulting prompt size in tokens and refuses to exceed the budget,
because rules that crowd out the evidence make every verdict worse.

## Known limitations

* **Latency is real** — 20–60 s per alert depending on backend. It runs after
  the collection sweep and never blocks collection, but it does delay alert
  dispatch.
* **Verdicts are not yet trustworthy enough to suppress.** Benign queries have
  been observed classified as alerts, and reasons have contained factual slips
  about the query. Annotate-only is the supported mode.
* **The agent needs precedent to be useful.** With no recent rows in
  `monitoring.general_metric_metadata_results` there is nothing to compare
  against, and it will alert on everything — correctly, by its own logic, but
  uselessly. Collection must be running.
