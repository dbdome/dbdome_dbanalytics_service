# rootcause Security — Phase 0 Cutover Runbook (RBAC lockdown)

**Goal:** make `6690_harden_rootcause_schema.sql` *effective* — move the application
off the superuser `dbdome_mon_usr` onto the least-privilege `dbdome_engine`, give
Grafana a read-only role with **no** `rootcause` access, and demote the old
superusers. Until this cutover runs, `rootcause` is still readable by the
monitoring role and Phase 1 encryption only protects dumps, not live SQL access.

> Do this on **one appliance at a time**, during a maintenance window. Every step
> has a verification and a rollback. The only irreversible-feeling step (SECTION 8
> demotion) has a one-line recovery.

---

## Pre-flight

- [ ] Confirm `6690_harden_rootcause_schema.sql` and `7300_rootcause_content_encryption.sql`
      have been applied (Phase 1 objects exist):
  ```sql
  SELECT to_regprocedure('rootcause.dec(jsonb)') IS NOT NULL AS phase1_ready;
  SELECT 1 FROM pg_roles WHERE rolname='dbdome_engine';   -- exists?
  ```
- [ ] Note the current app role from the service `.env` (`PG_USER=`, typically
      `dbdome_mon_usr`).
- [ ] Back up globals + the DB (so a bad grant is recoverable):
  ```
  pg_dumpall -U postgres --globals-only > globals_before.sql
  pg_dump    -U postgres -d dbanalytics -Fc -f dbanalytics_before.dump
  ```
- [ ] Have a `postgres` superuser psql session open the whole time (your recovery
      channel).

---

## Step A — set real passwords on the new roles

The roles ship with `CHANGE_ME_*` placeholders. As `postgres`:

```sql
ALTER ROLE dbdome_engine     PASSWORD '<STRONG_ENGINE_PW>';
ALTER ROLE dbdome_grafana_ro PASSWORD '<STRONG_GRAFANA_PW>';
```

**Verify:** `\du dbdome_engine` shows the role; you can log in with the new password:
```
psql "host=localhost dbname=dbanalytics user=dbdome_engine password=<STRONG_ENGINE_PW>" -c "select current_user"
```

---

## Step B — point the service at `dbdome_engine`

Edit the service `.env` (`C:\ProgramData\DBDOME\bin\.env`):

```
PG_USER=dbdome_engine
PG_PASSWORD=<STRONG_ENGINE_PW>      # will be re-encrypted to enc:v1: on next write
```

- [ ] Keep `DBDOME_SECRET_KEY=` unchanged — it is the pgcrypto passphrase the
      engine injects (`options=-c rootcause.k=...`) to decrypt detection logic.
      **If this key is missing or wrong, every detection returns NULL content.**
- [ ] Restart the services (`DBDOME_scheduler`, `DBDOME_web`).

**Verify — the engine can read AND decrypt rootcause (this is the Phase 0 × Phase 1 join):**
```sql
-- as dbdome_engine, via the app's own connection (key injected):
SELECT count(*) FROM rootcause.detection_steps;                 -- > 0
SELECT rootcause.dec(content) ? 'sql' FROM rootcause.detection_steps
 WHERE step_type='query' LIMIT 1;                                -- t  (decrypts)
```
Watch `bin\logs` for a clean scheduler cycle (detections run, no "permission denied
for schema rootcause" and no NULL-content errors).

**Rollback:** set `.env` back to `PG_USER=dbdome_mon_usr` + its password, restart.

---

## Step C — repoint the Grafana datasource(s) to `dbdome_grafana_ro`

In Grafana (or `grafana.db` provisioning), change the PostgreSQL datasource user to
`dbdome_grafana_ro` / `<STRONG_GRAFANA_PW>`.

**Verify — Grafana works on customer schemas but is BLOCKED from rootcause (defense in depth):**
```sql
SET ROLE dbdome_grafana_ro;
SELECT * FROM monitoring.<some_dashboard_view> LIMIT 1;   -- must WORK
SELECT * FROM rootcause.root_causes LIMIT 1;              -- must FAIL: permission denied
SELECT rootcause.dec('{"sql":"x"}'::jsonb);               -- N/A: no USAGE on schema anyway
RESET ROLE;
```
Even if a rootcause object were reachable, `dbdome_grafana_ro` has **no** session key,
so `dec()` would withhold plaintext — two independent barriers.

Reload dashboards; confirm panels render.

**Rollback:** repoint the datasource back to the previous user, reload.

---

## Step D — SECTION 8: demote the old superusers (the step that makes it real)

Only after A–C are verified healthy. As `postgres`:

```sql
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dbdome_mon_usr'  AND rolsuper) THEN
        ALTER ROLE dbdome_mon_usr  NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='dbexpert_mon_usr' AND rolsuper) THEN
        ALTER ROLE dbexpert_mon_usr NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END $$;
```

**Verify:**
```sql
SELECT rolname, rolsuper FROM pg_roles WHERE rolcanlogin ORDER BY 1;  -- no app superuser
```
Then re-run the Step B/C verifications once more (app still collects; Grafana still
renders; rootcause still blocked for grafana_ro).

**Rollback (immediate):** `ALTER ROLE dbdome_mon_usr SUPERUSER;` — restores the old
path instantly if anything regressed.

---

## Post-cutover state

| Principal | rootcause | detection logic | customer schemas |
|---|---|---|---|
| `dbdome_engine` (app) | owner / full | **decrypts** (has session key) | full read/write |
| `dbdome_grafana_ro` (Grafana) | **no access** | withheld (no key) | read-only |
| `dbdome_mon_usr` / `dbexpert_mon_usr` | revoked, **no longer superuser** | withheld | per grants |
| `pg_dump` / stolen datafile | ciphertext only | withheld (no key in dump) | — |

## Interaction with Phase 1 (encryption)

- Deploy order is **6690 → 7300 → `encrypt_detection_logic.py` → this cutover**.
- The engine decrypts because `get_connection_string()` injects
  `options=-c rootcause.k=<DBDOME_SECRET_KEY>` on every connection.
- Losing/rotating `DBDOME_SECRET_KEY` makes existing ciphertext undecryptable —
  treat it like the master secret it is (back it up with the appliance, out of band
  from any DB backup).
