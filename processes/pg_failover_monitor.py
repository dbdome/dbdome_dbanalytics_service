"""PostgreSQL primary-down detector for DBDOME's own store (HA/DR, Tier 1).

Companion to the ``PG_HOST=primary,alternate`` multi-host failover DSN
(utils.config_dotenv.build_pg_host). libpq already fails *connections* over to a
node that accepts writes; this process watches the PRIMARY and, when it goes
down, tells a human exactly what to do -- it NEVER promotes anything itself.
That keeps it free of split-brain risk: there is no automatic ``pg_promote()``.

On each run it:
  * probes the primary directly (``SELECT pg_is_in_recovery()``),
  * on a healthy primary, refreshes a LOCAL cache file with the SMTP settings,
    recipients and config, and resets the outage counter,
  * on N consecutive failures, inspects the standby (is it a replica? how far
    behind?), decides whether it looks SAFE TO PROMOTE, and emails the alert
    with the precise promote command to run -- plus the post-failover steps.

Why the local cache: when the primary (which holds config.mail_config and this
very table) is down, the DB can't tell us how to send mail or record the event.
So healthy runs cache what the outage path needs, and the outage alert goes out
over SMTP, which does not depend on the database being up. The event is also
queued locally and flushed to log.pg_failover_events once a node is writable.

Config + state live in config.pg_failover_monitor (migration 7690); the ledger
is log.pg_failover_events. Registered as the 'pg_failover_monitor' scheduled
process. Tier 2 (armed auto-promote) is intentionally NOT implemented here.
"""
import os
import sys
import json
import socket
import smtplib
from datetime import datetime, timezone
from email.message import EmailMessage

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret

CACHE_NAME = "pg_failover_state.json"


# --------------------------------------------------------------------------- #
# Local cache (survives the primary being down)
# --------------------------------------------------------------------------- #
def _app_dir():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _cache_path():
    return os.path.join(_app_dir(), CACHE_NAME)


def _load_cache():
    try:
        with open(_cache_path(), "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _save_cache(data):
    try:
        tmp = _cache_path() + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            # default=str so a stray Decimal/datetime can never silently sink the
            # whole cache -- losing it would leave the outage path with no SMTP.
            json.dump(data, f, default=str)
        os.replace(tmp, _cache_path())
    except Exception as e:
        db_write_log(f"pg_failover_monitor cache write failed: {e}", 0,
                     "pg_failover_monitor", "")


# --------------------------------------------------------------------------- #
# Host parsing -- PG_HOST is "primary[,alternate...]" (see build_pg_host)
# --------------------------------------------------------------------------- #
def _split_host(entry, default_port):
    entry = str(entry).strip()
    if ":" in entry:
        h, _, p = entry.rpartition(":")
        return h, int(p)
    return entry, int(default_port)


def _resolve_hosts(cfg):
    """Return (primary_host, primary_port, standby_host, standby_port).

    Config overrides win; otherwise derive from PG_HOST (first=primary,
    second=standby). standby_* is (None, None) when no DR node is known.
    """
    pg_host = os.getenv("PG_HOST", "localhost")
    pg_port = os.getenv("PG_PORT", "5432")
    parts = [h.strip() for h in pg_host.split(",") if h.strip()]
    ph, pp = _split_host(parts[0] if parts else "localhost", pg_port)
    sh, spt = (None, None)
    if len(parts) > 1:
        sh, spt = _split_host(parts[1], pg_port)
    # explicit overrides from config
    if cfg.get("primary_host"):
        ph, pp = cfg["primary_host"], int(cfg.get("primary_port") or pp)
    if cfg.get("standby_host"):
        sh, spt = cfg["standby_host"], int(cfg.get("standby_port") or (spt or pg_port))
    return ph, int(pp), sh, (int(spt) if spt else None)


def _conn_to(host, port, timeout):
    """Direct connection to one specific node (no failover list)."""
    return psycopg2.connect(
        host=host, port=port,
        dbname=os.getenv("PG_DB", "dbanalytics"),
        user=os.getenv("PG_USER"),
        password=os.getenv("PG_PASSWORD"),
        connect_timeout=int(timeout or 5),
    )


# --------------------------------------------------------------------------- #
# SMTP send that does NOT need the database (uses cached config)
# --------------------------------------------------------------------------- #
def _smtp_send(smtp, recipients, subject, body):
    if not smtp or not recipients:
        raise RuntimeError("no cached SMTP config or recipients for outage alert")
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = (smtp.get("sender") or smtp.get("user") or "dbdome@localhost").strip()
    msg["To"] = ", ".join(recipients)
    msg.set_content(body)
    s = smtplib.SMTP(smtp["server"], int(smtp["port"]), timeout=30)
    try:
        s.ehlo()
        if smtp.get("tls"):
            s.starttls()
            s.ehlo()
        if smtp.get("user"):
            pw = smtp.get("password") or ""
            try:
                pw = decrypt_secret(pw)
            except Exception:
                pass
            s.login(smtp["user"], pw)
        s.send_message(msg, to_addrs=recipients)
    finally:
        try:
            s.quit()
        except Exception:
            pass


def _read_mail_cache(cur):
    """Read SMTP config + recipients from the (healthy) DB for caching."""
    cur.execute("""SELECT mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server
                   FROM config.mail_config LIMIT 1""")
    mc = cur.fetchone()
    smtp = None
    if mc:
        smtp = {"sender": mc[0], "port": mc[1], "user": mc[2],
                "password": mc[3], "tls": mc[4], "server": mc[5]}
    cur.execute(r"""
        SELECT string_agg(DISTINCT trim(r.v), ',')
        FROM config.mail_groups mg
        CROSS JOIN LATERAL regexp_split_to_table(mg.recipients, '[,;\s]+') AS r(v)
        WHERE mg.is_active IS TRUE AND length(trim(r.v)) > 0
    """)
    row = cur.fetchone()
    rcpts = [x for x in (((row[0] if row else None) or "").split(",")) if x]
    return smtp, rcpts


# --------------------------------------------------------------------------- #
# Standby inspection + promote-command preview
# --------------------------------------------------------------------------- #
def _inspect_standby(host, port, timeout):
    """Return a dict describing the standby's readiness to be promoted."""
    info = {"reachable": False, "in_recovery": None, "replay_lag_bytes": None,
            "replay_delay_secs": None, "wal_receiver": None}
    try:
        c = _conn_to(host, port, timeout)
    except Exception as e:
        info["error"] = str(e)
        return info
    try:
        info["reachable"] = True
        cur = c.cursor()
        cur.execute("SELECT pg_is_in_recovery()")
        info["in_recovery"] = cur.fetchone()[0]
        if info["in_recovery"]:
            # bytes of WAL received but not yet replayed, and replay time lag
            cur.execute("""
                SELECT COALESCE(pg_wal_lsn_diff(pg_last_wal_receive_lsn(),
                                                pg_last_wal_replay_lsn()), 0)::bigint,
                       EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::bigint
            """)
            lag_bytes, delay = cur.fetchone()
            info["replay_lag_bytes"] = int(lag_bytes or 0)
            info["replay_delay_secs"] = int(delay) if delay is not None else None
            try:
                cur.execute("SELECT status FROM pg_stat_wal_receiver LIMIT 1")
                r = cur.fetchone()
                info["wal_receiver"] = r[0] if r else "none"
            except Exception:
                info["wal_receiver"] = "unknown"
    except Exception as e:
        info["error"] = str(e)
    finally:
        try:
            c.close()
        except Exception:
            pass
    return info


def _build_alert(primary, standby_host, standby_port, st, cfg):
    """Return (subject, body, recommended_action, state)."""
    datadir = cfg.get("standby_datadir") or "<standby data directory>"
    lag_mb = round((st.get("replay_lag_bytes") or 0) / (1024 * 1024), 2)
    max_lag = float(cfg.get("max_replay_lag_mb") or 50)

    safe = (st.get("reachable") and st.get("in_recovery") is True
            and (st.get("replay_lag_bytes") or 0) <= max_lag * 1024 * 1024)

    if not standby_host:
        verdict = "NO STANDBY CONFIGURED -- cannot fail over. Investigate the primary."
        state = "no_standby"
    elif not st.get("reachable"):
        verdict = f"STANDBY UNREACHABLE at {standby_host}:{standby_port} -- do NOT promote blindly."
        state = "standby_not_ready"
    elif st.get("in_recovery") is not True:
        verdict = "STANDBY IS NOT IN RECOVERY -- it may already be a primary. Investigate for split-brain BEFORE acting."
        state = "standby_not_ready"
    elif not safe:
        verdict = (f"STANDBY IS BEHIND ({lag_mb} MB / {st.get('replay_delay_secs')}s unreplayed, "
                   f"limit {max_lag} MB) -- promoting now may lose writes. Review before promoting.")
        state = "standby_not_ready"
    else:
        verdict = f"STANDBY LOOKS SAFE TO PROMOTE ({lag_mb} MB unreplayed, within {max_lag} MB)."
        state = "preview_emitted"

    cmd = (f"-- On the standby host ({standby_host}), as the postgres OS user:\n"
           f"psql -h {standby_host} -p {standby_port} -c \"SELECT pg_promote(wait => true);\"\n"
           f"--   or:  pg_ctl promote -D {datadir}\n")
    post = ("After promotion:\n"
            "  1. The DBDOME services pick up the new primary automatically via the\n"
            "     PG_HOST=primary,alternate failover DSN (it only connects to a\n"
            "     read-write node). No .env change is required to resume writes.\n"
            "  2. Reorder PG_HOST so the new primary is listed first.\n"
            "  3. Do NOT restart the old primary as a primary -- rebuild it as a\n"
            "     standby of the new primary with pg_rewind, then re-add it.\n")

    subject = f"[DBDOME] PostgreSQL PRIMARY DOWN: {primary}"
    body = (f"DBDOME's database primary is not reachable.\n\n"
            f"  Primary : {primary} (DOWN)\n"
            f"  Standby : {standby_host or 'none'}"
            + (f":{standby_port}" if standby_host else "") + "\n"
            f"  Standby in recovery : {st.get('in_recovery')}\n"
            f"  Unreplayed WAL      : {lag_mb} MB\n"
            f"  Replay delay        : {st.get('replay_delay_secs')} s\n"
            f"  WAL receiver        : {st.get('wal_receiver')}\n\n"
            f"ASSESSMENT: {verdict}\n\n"
            f"RECOMMENDED PROMOTE COMMAND (run manually -- DBDOME does NOT auto-promote):\n"
            f"{cmd}\n{post}")
    return subject, body, verdict, state


# --------------------------------------------------------------------------- #
# Event ledger (best-effort; queued locally if no node is writable)
# --------------------------------------------------------------------------- #
def _record_event(state, primary, standby, fails, lag, action):
    row = {"ts": datetime.now(timezone.utc).isoformat(), "state": state,
           "primary_host": primary, "standby_host": standby,
           "consecutive_failures": fails, "replay_lag_bytes": lag,
           "recommended_action": action}
    # try to write straight to the ledger (works when a node is writable)
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute("""INSERT INTO log.pg_failover_events
                    (state, primary_host, standby_host, consecutive_failures,
                     replay_lag_bytes, recommended_action, detail)
                    VALUES (%s,%s,%s,%s,%s,%s, CAST(%s AS jsonb))""",
                    (state, primary, standby, fails, lag, action, json.dumps(row)))
            # flush any locally-queued events now that a node is writable
            cache = _load_cache()
            for q in cache.get("pending_events", []):
                cur.execute("""INSERT INTO log.pg_failover_events
                        (event_time, state, primary_host, standby_host,
                         consecutive_failures, replay_lag_bytes, recommended_action, detail)
                        VALUES (%s,%s,%s,%s,%s,%s,%s, CAST(%s AS jsonb))""",
                        (q.get("ts"), q.get("state"), q.get("primary_host"),
                         q.get("standby_host"), q.get("consecutive_failures"),
                         q.get("replay_lag_bytes"), q.get("recommended_action"),
                         json.dumps(q)))
            if cache.get("pending_events"):
                cache["pending_events"] = []
                _save_cache(cache)
            conn.commit()
        finally:
            conn.close()
        return True
    except Exception:
        # no writable node -- queue it in the cache for later
        cache = _load_cache()
        cache.setdefault("pending_events", []).append(row)
        _save_cache(cache)
        return False


# --------------------------------------------------------------------------- #
# Entry point (registered scheduled process)
# --------------------------------------------------------------------------- #
def run_pg_failover_monitor():
    host = socket.gethostname()
    cache = _load_cache()
    cfg = dict(cache.get("cfg") or {})

    # --- probe the primary directly -------------------------------------------------
    # First establish the primary address. We need cfg for overrides; if the DB is
    # up we refresh cfg below, but for the probe we use env/cache.
    ph, pp, sh, spt = _resolve_hosts(cfg)
    timeout = int(cfg.get("connect_timeout_secs") or 5)
    primary_label = f"{ph}:{pp}"

    primary_up = False
    primary_in_recovery = None
    try:
        c = _conn_to(ph, pp, timeout)
        try:
            cur = c.cursor()
            cur.execute("SELECT pg_is_in_recovery()")
            primary_in_recovery = cur.fetchone()[0]
            primary_up = (primary_in_recovery is False)  # writable primary
            if primary_up:
                # refresh config + mail cache while the DB is healthy
                try:
                    cur.execute("""SELECT is_enabled, fail_threshold, connect_timeout_secs,
                                          max_replay_lag_mb, recurrency_hours, primary_host,
                                          primary_port, standby_host, standby_port,
                                          standby_datadir
                                   FROM config.pg_failover_monitor WHERE row_id = 1""")
                    r = cur.fetchone()
                    if r:
                        cfg = {"is_enabled": r[0], "fail_threshold": r[1],
                               "connect_timeout_secs": r[2],
                               "max_replay_lag_mb": float(r[3]) if r[3] is not None else None,
                               "recurrency_hours": r[4], "primary_host": r[5],
                               "primary_port": r[6], "standby_host": r[7],
                               "standby_port": r[8], "standby_datadir": r[9]}
                    smtp, rcpts = _read_mail_cache(cur)
                    cache["cfg"] = cfg
                    cache["smtp"] = smtp
                    cache["recipients"] = rcpts
                    # heartbeat in the single config row (not the ledger, which is
                    # for events only) so a healthy primary never bloats the log
                    cur.execute("""UPDATE config.pg_failover_monitor
                                   SET consecutive_failures = 0, tripped = false,
                                       last_state = 'primary_up', last_checked = now(),
                                       updated_at = now()
                                   WHERE row_id = 1""")
                    c.commit()
                except Exception as e:
                    db_write_log(f"pg_failover_monitor config refresh failed: {e}", 0,
                                 "pg_failover_monitor", host)
        finally:
            try:
                c.close()
            except Exception:
                pass
    except Exception:
        primary_up = False

    # honour the enable flag (from freshest cfg we have)
    if cfg.get("is_enabled") is False:
        cache["last_state"] = "disabled"
        _save_cache(cache)
        return 1

    # re-resolve hosts with the (possibly refreshed) cfg
    ph, pp, sh, spt = _resolve_hosts(cfg)
    primary_label = f"{ph}:{pp}"
    threshold = int(cfg.get("fail_threshold") or 3)

    # --- HEALTHY primary -------------------------------------------------------------
    if primary_up:
        was_tripped = bool(cache.get("tripped"))
        cache["consecutive_failures"] = 0
        cache["tripped"] = False
        cache["last_state"] = "primary_up"
        cache["last_checked"] = datetime.now(timezone.utc).isoformat()
        _save_cache(cache)
        # ledger gets events only (down / preview / recovered), never routine
        # heartbeats -- the heartbeat lives in config.pg_failover_monitor above.
        if was_tripped:
            # recovery notice (best effort; DB is up now)
            try:
                _record_event("recovered", primary_label, sh, 0, None,
                              "primary reachable again")
                smtp = cache.get("smtp"); rcpts = cache.get("recipients") or []
                if smtp and rcpts:
                    _smtp_send(smtp, rcpts, f"[DBDOME] PostgreSQL primary recovered: {primary_label}",
                               f"The primary {primary_label} is reachable and writable again.\n"
                               f"If you promoted the standby during the outage, remember to rebuild "
                               f"the old primary as a standby (pg_rewind) rather than running two primaries.")
            except Exception as e:
                db_write_log(f"pg_failover_monitor recovery notice failed: {e}", 0,
                             "pg_failover_monitor", host)
            db_write_log(f"pg_failover_monitor: primary {primary_label} recovered", 0,
                         "pg_failover_monitor", host)
        return 1

    # --- primary DOWN (or in recovery) -----------------------------------------------
    fails = int(cache.get("consecutive_failures") or 0) + 1
    cache["consecutive_failures"] = fails
    cache["last_state"] = "primary_down"
    cache["last_checked"] = datetime.now(timezone.utc).isoformat()
    _save_cache(cache)
    db_write_log(f"pg_failover_monitor: primary {primary_label} unreachable "
                 f"({fails}/{threshold})", 0, "pg_failover_monitor", host)

    if fails < threshold or cache.get("tripped"):
        return 1  # not yet tripped, or already alerted for this outage

    # trip: inspect the standby and emit the preview alert
    st = _inspect_standby(sh, spt, timeout) if sh else {"reachable": False}
    subject, body, action, state = _build_alert(primary_label, sh, spt, st, cfg)
    lag = st.get("replay_lag_bytes")

    sent = False
    smtp = cache.get("smtp"); rcpts = cache.get("recipients") or []
    try:
        _smtp_send(smtp, rcpts, subject, body)
        sent = True
    except Exception as e:
        db_write_log(f"pg_failover_monitor outage email failed: {e}", 0,
                     "pg_failover_monitor", host)

    _record_event(state, primary_label, sh, fails, lag, action)
    cache["tripped"] = True
    _save_cache(cache)
    db_write_log(f"pg_failover_monitor: PRIMARY DOWN alert "
                 f"({'emailed' if sent else 'email FAILED'}); assessment: {action}",
                 0, "pg_failover_monitor", host)
    return 1
