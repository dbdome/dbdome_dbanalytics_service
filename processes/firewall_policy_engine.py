"""
GRC Firewall Policy Engine
Evaluates captured queries/sessions against config.firewall_policies.

Matching order (lowest priority number = evaluated first):
  1. query_pattern  — regex against sql_statement
  2. user           — exact or pipe-separated alternatives
  3. role           — checks against a supplied roles list
  4. ip             — exact or CIDR match
  5. table_name     — regex against sql_statement
  6. schema_name    — regex against sql_statement
  7. time_range     — HH:MM-HH:MM window (server local time)

Returns the first matched policy's action.
If no policy matches, returns ALLOW with risk_score=0.
"""

import re
import time
import ipaddress
from functools import lru_cache
from utils.log4dbexpert import _get_pool
from utils.firewall_audit_writer import write_audit_event


# ── Policy cache (reloaded every 60 s) ──────────────────────────────────────

_policy_cache: list = []
_cache_loaded_at: float = 0.0
_CACHE_TTL = 60  # seconds

# ── Exception cache (reloaded every 60 s) ───────────────────────────────────

_exception_cache: list = []
_exception_cache_loaded_at: float = 0.0


def _load_policies() -> list:
    """Load active policies from DB, ordered by priority ASC."""
    global _policy_cache, _cache_loaded_at
    try:
        pool = _get_pool()
        conn = pool.getconn()
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT policy_id, policy_name, vendor, action,
                       condition_type, condition_value,
                       severity, regulation, priority
                FROM   config.firewall_policies
                WHERE  is_active = TRUE
                ORDER  BY priority ASC
                """
            )
            rows = cur.fetchall()
            cur.close()
            _policy_cache = [
                {
                    "policy_id":      r[0],
                    "policy_name":    r[1],
                    "vendor":         r[2],
                    "action":         r[3],
                    "condition_type": r[4],
                    "condition_value":r[5],
                    "severity":       r[6],
                    "regulation":     r[7],
                    "priority":       r[8],
                }
                for r in rows
            ]
            _cache_loaded_at = time.time()
        finally:
            pool.putconn(conn)
    except Exception as e:
        print(f"firewall_policy_engine: failed to load policies: {e}")
    return _policy_cache


def _get_policies() -> list:
    if time.time() - _cache_loaded_at > _CACHE_TTL:
        _load_policies()
    return _policy_cache


def _load_exceptions() -> list:
    """Load active policy exceptions from config.v_active_policy_exceptions."""
    global _exception_cache, _exception_cache_loaded_at
    try:
        pool = _get_pool()
        conn = pool.getconn()
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT exception_id, policy_id, server_name,
                       db_user, client_ip_cidr
                FROM   config.v_active_policy_exceptions
                """
            )
            rows = cur.fetchall()
            cur.close()
            _exception_cache = [
                {
                    "exception_id":  r[0],
                    "policy_id":     r[1],
                    "server_name":   r[2],
                    "db_user":       r[3],
                    "client_ip_cidr":r[4],
                }
                for r in rows
            ]
            _exception_cache_loaded_at = time.time()
        finally:
            pool.putconn(conn)
    except Exception as e:
        print(f"firewall_policy_engine: failed to load exceptions: {e}")
    return _exception_cache


def _get_exceptions() -> list:
    if time.time() - _exception_cache_loaded_at > _CACHE_TTL:
        _load_exceptions()
    return _exception_cache


def _has_exception(policy_id, server_name: str, db_user: str, client_ip: str) -> bool:
    """Return True if an active exception covers this policy+context combination."""
    for exc in _get_exceptions():
        # policy scope: None means exception covers all policies
        if exc["policy_id"] is not None and exc["policy_id"] != policy_id:
            continue
        # server scope: None means any server
        if exc["server_name"] and exc["server_name"] != server_name:
            continue
        # user scope: None means any user
        if exc["db_user"] and exc["db_user"] != db_user:
            continue
        # IP scope: None means any IP; supports exact or CIDR
        if exc["client_ip_cidr"] and client_ip:
            try:
                addr = ipaddress.ip_address(client_ip)
                cidr = exc["client_ip_cidr"]
                if "/" in cidr:
                    if addr not in ipaddress.ip_network(cidr, strict=False):
                        continue
                elif cidr != client_ip:
                    continue
            except ValueError:
                continue
        elif exc["client_ip_cidr"] and not client_ip:
            continue
        return True
    return False


# ── Condition matchers ───────────────────────────────────────────────────────

def _match_user(condition_value: str, db_user: str) -> bool:
    if not db_user:
        return False
    alternatives = [v.strip().lower() for v in condition_value.split("|")]
    return db_user.lower() in alternatives


def _match_role(condition_value: str, roles: list) -> bool:
    if not roles:
        return False
    wanted = {v.strip().lower() for v in condition_value.split("|")}
    return bool(wanted & {r.lower() for r in roles})


def _match_ip(condition_value: str, client_ip: str) -> bool:
    if not client_ip:
        return False
    try:
        addr = ipaddress.ip_address(client_ip)
        for token in condition_value.split("|"):
            token = token.strip()
            if "/" in token:
                if addr in ipaddress.ip_network(token, strict=False):
                    return True
            elif token == client_ip:
                return True
    except ValueError:
        pass
    return False


def _match_query_pattern(condition_value: str, sql_statement: str) -> bool:
    if not sql_statement:
        return False
    try:
        return bool(re.search(condition_value, sql_statement, re.IGNORECASE | re.DOTALL))
    except re.error:
        return False


def _match_table_name(condition_value: str, sql_statement: str) -> bool:
    return _match_query_pattern(condition_value, sql_statement)


def _match_schema_name(condition_value: str, sql_statement: str) -> bool:
    return _match_query_pattern(condition_value, sql_statement)


def _match_time_range(condition_value: str) -> bool:
    """condition_value format: 'HH:MM-HH:MM' (e.g. '00:00-06:00')."""
    try:
        start_str, end_str = condition_value.split("-")
        sh, sm = map(int, start_str.split(":"))
        eh, em = map(int, end_str.split(":"))
        now = time.localtime()
        now_mins = now.tm_hour * 60 + now.tm_min
        start_mins = sh * 60 + sm
        end_mins = eh * 60 + em
        if start_mins <= end_mins:
            return start_mins <= now_mins < end_mins
        # overnight range (e.g. 22:00-06:00)
        return now_mins >= start_mins or now_mins < end_mins
    except Exception:
        return False


# ── Main evaluation entry point ──────────────────────────────────────────────

def evaluate_query(
    server_name: str,
    vendor: str,
    db_user: str,
    client_ip: str,
    db_name: str,
    sql_statement: str,
    roles: list = None,
    session_id: str = None,
) -> dict:
    """
    Evaluate a captured query against all active firewall policies.

    Returns:
        {
          "action":      "ALLOW" | "BLOCK" | "ALERT" | "MASK",
          "policy_id":   int | None,
          "policy_name": str | None,
          "regulation":  str | None,
          "severity":    str | None,
          "risk_score":  int,          # 0-100
        }
    Also writes one row to log.firewall_audit_log.
    """
    if roles is None:
        roles = []

    # ── Phase 6: check dynamic blocklist before evaluating policies ──────────
    try:
        from processes.threat_response_engine import get_blocked_ips, is_user_suspended
        if client_ip and client_ip in get_blocked_ips():
            write_audit_event(
                server_name=server_name, vendor=vendor, db_user=db_user,
                client_ip=client_ip, db_name=db_name, sql_statement=sql_statement,
                action_taken="BLOCKED", policy_id=None,
                regulation="internal", session_id=session_id, risk_score=100,
            )
            return {"action": "BLOCK", "policy_id": None,
                    "policy_name": "dynamic:blocked_ip", "regulation": "internal",
                    "severity": "CRITICAL", "risk_score": 100}
        if db_user and server_name and is_user_suspended(server_name, db_user):
            write_audit_event(
                server_name=server_name, vendor=vendor, db_user=db_user,
                client_ip=client_ip, db_name=db_name, sql_statement=sql_statement,
                action_taken="BLOCKED", policy_id=None,
                regulation="internal", session_id=session_id, risk_score=100,
            )
            return {"action": "BLOCK", "policy_id": None,
                    "policy_name": "dynamic:suspended_user", "regulation": "internal",
                    "severity": "CRITICAL", "risk_score": 100}
    except Exception:
        pass  # degrade gracefully if Phase 6 not yet migrated
    # ─────────────────────────────────────────────────────────────────────────

    matched_policy = None
    action = "ALLOW"
    risk_score = 0

    for policy in _get_policies():
        # Skip if vendor doesn't match
        if policy["vendor"] not in ("all", vendor or ""):
            continue

        ct = policy["condition_type"]
        cv = policy["condition_value"]
        matched = False

        if ct == "user":
            matched = _match_user(cv, db_user)
        elif ct == "role":
            matched = _match_role(cv, roles)
        elif ct == "ip":
            matched = _match_ip(cv, client_ip)
        elif ct == "query_pattern":
            matched = _match_query_pattern(cv, sql_statement)
        elif ct == "table_name":
            matched = _match_table_name(cv, sql_statement)
        elif ct == "schema_name":
            matched = _match_schema_name(cv, sql_statement)
        elif ct == "time_range":
            matched = _match_time_range(cv)

        if matched:
            matched_policy = policy
            action = policy["action"]
            # Risk score by severity
            risk_score = {"LOW": 20, "MEDIUM": 40, "HIGH": 70, "CRITICAL": 100}.get(
                policy.get("severity", "MEDIUM"), 40
            )
            break  # first match wins (policies ordered by priority)

    # ── Exception bypass: downgrade BLOCK/ALERT to ALLOW when an active
    #    policy exception covers this server+user+IP combination ─────────────
    if action in ("BLOCK", "ALERT") and matched_policy is not None:
        if _has_exception(matched_policy["policy_id"], server_name, db_user, client_ip):
            action = "ALLOW"
            risk_score = 0
    # ─────────────────────────────────────────────────────────────────────────

    # Map action to audit action_taken label
    action_taken_map = {
        "ALLOW": "ALLOWED",
        "BLOCK": "BLOCKED",
        "ALERT": "ALERTED",
        "MASK":  "MASKED",
    }
    action_taken = action_taken_map.get(action, "ALLOWED")

    write_audit_event(
        server_name=server_name,
        vendor=vendor,
        db_user=db_user,
        client_ip=client_ip,
        db_name=db_name,
        sql_statement=sql_statement,
        action_taken=action_taken,
        policy_id=matched_policy["policy_id"] if matched_policy else None,
        regulation=matched_policy["regulation"] if matched_policy else None,
        session_id=session_id,
        risk_score=risk_score,
    )

    return {
        "action":      action,
        "policy_id":   matched_policy["policy_id"]   if matched_policy else None,
        "policy_name": matched_policy["policy_name"] if matched_policy else None,
        "regulation":  matched_policy["regulation"]  if matched_policy else None,
        "severity":    matched_policy["severity"]    if matched_policy else None,
        "risk_score":  risk_score,
    }


def reload_policy_cache():
    """Force an immediate cache refresh — call after UI policy or exception changes."""
    global _cache_loaded_at, _exception_cache_loaded_at
    _cache_loaded_at = 0.0
    _exception_cache_loaded_at = 0.0
    _load_policies()
    _load_exceptions()
