"""ldap_group_sync: replicate Active Directory users/groups into DBDOME Grafana.

WHY THIS EXISTS
    Grafana OSS has no background LDAP sync - `active_sync_enabled` is an
    Enterprise feature. OSS resolves group -> org role only inside the login
    handler, so:
      * a user who has never logged in does not exist in Grafana at all, and
      * an AD group change takes effect at that user's NEXT login, never before.
    This process closes both gaps by reconciling AD into Grafana on a timer via
    Grafana's admin HTTP API.

WHAT IT DOES, EACH RUN
    1. enumerate every user matched by config.ldap_settings.group_mappings
       (utils.ldap_settings.fetch_directory_users - nested groups included)
    2. create users Grafana does not have yet
    3. set each user's org role, and the Grafana-admin flag, from the mapping
    4. deprovision users that no longer match any mapping, per the configured
       policy (none | viewer | remove | disable)

    Role decisions come from utils.ldap_settings.resolve_role - the same function
    behind the "Test connection" preview, and the same mappings rendered into
    ldap.toml for Grafana's own login. If the sync and the login handler ever
    disagreed they would overwrite each other every cycle.

SAFETY
    * dry_run is ON by default (config.ldap_settings.sync_dry_run): the process
      logs exactly what it WOULD do and writes nothing.
    * PROTECTED_LOGINS are never touched - the package's own accounts. Same
      reasoning as the grafana.db user migration in dbdome_update: those are ours,
      not the customer's, and an AD sync must not be able to lock the product out
      of its own UI by deprovisioning admin.
    * a failure talking to LDAP or Grafana aborts the run without deprovisioning
      anyone. Half a directory read looks exactly like "everyone was removed from
      their groups", and acting on that would mass-revoke access.
"""
import json

import psycopg2
import requests

from utils.config_dotenv import get_connection_string
from utils.ldap_settings import fetch_directory_users
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret

ROUTINE = "run_ldap_group_sync"

# Never created, never modified, never deprovisioned by the sync.
PROTECTED_LOGINS = {"admin", "dbdome_user"}

_ORG_ID = 1
_TIMEOUT = 20


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def _load_config():
    """Sync settings from config.ldap_settings (added by 7510)."""
    with psycopg2.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT enabled, sync_enabled, sync_dry_run, sync_deprovision, "
                "       grafana_url, grafana_token, grafana_admin_user, grafana_admin_password, "
                "       group_mappings "
                "FROM config.ldap_settings WHERE row_id = 1")
            row = cur.fetchone()
    if not row:
        return None
    keys = ["enabled", "sync_enabled", "sync_dry_run", "sync_deprovision",
            "grafana_url", "grafana_token", "grafana_admin_user", "grafana_admin_password",
            "group_mappings"]
    c = dict(zip(keys, row))
    if isinstance(c["group_mappings"], str):
        c["group_mappings"] = json.loads(c["group_mappings"])
    c["grafana_token"] = decrypt_secret(c["grafana_token"]) if c["grafana_token"] else ""
    c["grafana_admin_password"] = (decrypt_secret(c["grafana_admin_password"])
                                   if c["grafana_admin_password"] else "")
    return c


def _record_result(stats, error=None):
    with psycopg2.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE config.ldap_settings "
                "SET last_sync_at = now(), last_sync_result = %s::jsonb, last_sync_error = %s "
                "WHERE row_id = 1",
                (json.dumps(stats, default=str), error))


# ---------------------------------------------------------------------------
# Grafana admin API
# ---------------------------------------------------------------------------

class _Grafana:
    """Thin admin-API client. Prefers a service-account token; falls back to
    basic auth with the admin account when no token is configured."""

    def __init__(self, cfg):
        self.base = (cfg["grafana_url"] or "http://127.0.0.1:3000").rstrip("/")
        self.s = requests.Session()
        if cfg["grafana_token"]:
            self.s.headers["Authorization"] = f"Bearer {cfg['grafana_token']}"
        elif cfg["grafana_admin_user"]:
            self.s.auth = (cfg["grafana_admin_user"], cfg["grafana_admin_password"])
        else:
            raise RuntimeError("no Grafana credential configured - set a service-account "
                               "token (preferred) or an admin user/password on /ldap_settings")

    def _req(self, method, path, **kw):
        r = self.s.request(method, self.base + path, timeout=_TIMEOUT, **kw)
        if r.status_code >= 400:
            raise RuntimeError(f"grafana {method} {path} -> {r.status_code} {r.text[:200]}")
        return r.json() if r.content else {}

    def whoami(self):
        return self._req("GET", "/api/user")

    def lookup(self, login):
        r = self.s.get(self.base + "/api/users/lookup", params={"loginOrEmail": login},
                       timeout=_TIMEOUT)
        if r.status_code == 404:
            return None
        if r.status_code >= 400:
            raise RuntimeError(f"grafana lookup {login} -> {r.status_code} {r.text[:200]}")
        return r.json()

    def create_user(self, u, password):
        return self._req("POST", "/api/admin/users", json={
            "name": u["name"], "email": u["email"] or f"{u['login']}@invalid.local",
            "login": u["login"], "password": password})

    def org_users(self):
        return self._req("GET", f"/api/orgs/{_ORG_ID}/users")

    def add_to_org(self, login, role):
        return self._req("POST", f"/api/orgs/{_ORG_ID}/users",
                         json={"loginOrEmail": login, "role": role})

    def set_org_role(self, user_id, role):
        return self._req("PATCH", f"/api/orgs/{_ORG_ID}/users/{user_id}", json={"role": role})

    def remove_from_org(self, user_id):
        return self._req("DELETE", f"/api/orgs/{_ORG_ID}/users/{user_id}")

    def set_grafana_admin(self, user_id, is_admin):
        return self._req("PUT", f"/api/admin/users/{user_id}/permissions",
                         json={"isGrafanaAdmin": bool(is_admin)})

    def set_disabled(self, user_id, disabled):
        verb = "disable" if disabled else "enable"
        return self._req("POST", f"/api/admin/users/{user_id}/{verb}")


def _random_password():
    # LDAP authenticates these users; the local password must exist (Grafana
    # requires one at creation) but must never be usable or predictable.
    import secrets
    return secrets.token_urlsafe(32)


# ---------------------------------------------------------------------------
# Reconcile
# ---------------------------------------------------------------------------

def _skip_reason(cfg, manual):
    """Why this run cannot do anything, or None. Kept explicit because a silent
    early return is indistinguishable from 'ran fine, found nothing' - which is
    exactly how a skipped run got reported to the UI as 'Sync complete, 0 users'."""
    if not cfg:
        return "config.ldap_settings row is missing (run 7400_ldap_settings.sql)"
    if not cfg["enabled"]:
        return ("LDAP is disabled - configure and enable LDAP login first "
                "(there is nothing to sync from yet)")
    # The timer switch does NOT gate a manual run: 'Sync now' exists precisely so a
    # cycle can be inspected BEFORE the schedule is turned on.
    if not manual and not cfg["sync_enabled"]:
        return "scheduled sync is disabled"
    if not (cfg.get("group_mappings") or []):
        return ("no group mappings configured - add at least one AD group DN under "
                "'Group -> role mappings'")
    if all((m.get("group_dn") or "").strip() == "*" for m in cfg["group_mappings"]):
        return ("only a '*' mapping is configured - that means 'any authenticated user' "
                "and has no member list to enumerate; add explicit group DNs to sync")
    return None


def run_ldap_group_sync(manual=False):
    cfg = _load_config()
    reason = _skip_reason(cfg, manual)
    if reason:
        # A manual click must never look like a successful no-op.
        if manual:
            raise RuntimeError(reason)
        return

    dry = bool(cfg["sync_dry_run"])
    stats = {"dry_run": dry, "seen": 0, "created": 0, "role_set": 0,
             "admin_set": 0, "deprovisioned": 0, "skipped_protected": 0, "errors": 0}
    try:
        # 1. AD side. Any failure here must abort BEFORE deprovisioning: a partial
        #    read is indistinguishable from "everybody left their groups".
        desired = fetch_directory_users()
        stats["seen"] = len(desired)
        if not desired:
            db_write_log("ldap_group_sync: directory returned 0 users for the configured "
                         "mappings - skipping run (refusing to treat this as 'remove everyone')",
                         1, ROUTINE, None)
            _record_result(stats, "directory returned no users")
            return

        g = _Grafana(cfg)
        g.whoami()                       # fail fast on a bad credential

        existing = {u["login"].lower(): u for u in g.org_users()}

        # 2/3. create + set role/admin
        for key, u in desired.items():
            if key in PROTECTED_LOGINS:
                stats["skipped_protected"] += 1
                continue
            try:
                cur = existing.get(key)
                if cur is None:
                    found = g.lookup(u["login"])
                    if found is None:
                        if dry:
                            db_write_log(f"ldap_group_sync[dry]: would CREATE {u['login']} "
                                         f"({u['org_role']})", 0, ROUTINE, None)
                        else:
                            g.create_user(u, _random_password())
                        stats["created"] += 1
                    if not dry:
                        g.add_to_org(u["login"], u["org_role"])
                        stats["role_set"] += 1
                    elif found is not None:
                        db_write_log(f"ldap_group_sync[dry]: would ADD {u['login']} to org "
                                     f"as {u['org_role']}", 0, ROUTINE, None)
                elif cur.get("role") != u["org_role"]:
                    if dry:
                        db_write_log(f"ldap_group_sync[dry]: would CHANGE {u['login']} "
                                     f"{cur.get('role')} -> {u['org_role']}", 0, ROUTINE, None)
                    else:
                        g.set_org_role(cur["userId"], u["org_role"])
                    stats["role_set"] += 1

                uid = (cur or {}).get("userId")
                if uid and u["grafana_admin"] and not cur.get("isAdmin"):
                    if not dry:
                        g.set_grafana_admin(uid, True)
                    stats["admin_set"] += 1
            except Exception as e:                       # one bad user must not stop the rest
                stats["errors"] += 1
                db_write_log(f"ldap_group_sync: {u['login']}: {e}", 1, ROUTINE, None)

        # 4. deprovision - only users the sync could have provisioned
        mode = (cfg["sync_deprovision"] or "none").lower()
        if mode != "none":
            for key, cur in existing.items():
                if key in PROTECTED_LOGINS or key in desired:
                    continue
                try:
                    if dry:
                        db_write_log(f"ldap_group_sync[dry]: would {mode.upper()} "
                                     f"{cur['login']} (no longer in any mapped group)",
                                     0, ROUTINE, None)
                    elif mode == "viewer":
                        g.set_org_role(cur["userId"], "Viewer")
                    elif mode == "remove":
                        g.remove_from_org(cur["userId"])
                    elif mode == "disable":
                        g.set_disabled(cur["userId"], True)
                    stats["deprovisioned"] += 1
                except Exception as e:
                    stats["errors"] += 1
                    db_write_log(f"ldap_group_sync: deprovision {cur.get('login')}: {e}",
                                 1, ROUTINE, None)

        _record_result(stats)
        db_write_log(
            "ldap_group_sync{}: {seen} in AD, {created} created, {role_set} roles set, "
            "{admin_set} admin flags, {deprovisioned} deprovisioned, {errors} errors".format(
                "[dry]" if dry else "", **stats), 0, ROUTINE, None)
    except Exception as e:
        db_write_log(f"ldap_group_sync failed: {e}", 1, ROUTINE, None)
        try:
            _record_result(stats, str(e))
        except Exception:
            pass
