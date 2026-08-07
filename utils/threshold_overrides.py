"""Per-server alert-threshold overrides (see sql_scripts/7420_alert_threshold_tuning.sql).

rootcause.detection_steps.parameters is global - the same jsonb is used for every
server and every target. When a root cause keeps alerting on one noisy server,
rootcause.tune_alert_thresholds() records a raised value for THAT server only, in
rootcause.parameter_tuning.

The collectors read parameters before they know which server they are about to
collect, so the overlay happens here: call apply_parameter_overrides() with the
server key right after loading the metric rows and before calc_query is computed.

No-ops entirely when no overrides exist for the server, so it is safe to call
unconditionally on every cycle.
"""
import json

from sqlalchemy import text

from utils.log4dbexpert import db_write_log

_PROC = "threshold_overrides"


def _as_dict(raw):
    """step_parameters arrives as dict, JSON string, or None."""
    if raw is None:
        return None
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else None
        except (json.JSONDecodeError, ValueError):
            return None
    return None


def load_overrides(pg_engine, server):
    """{(root_cause_id, step_name): {param_name: value}} for one server."""
    if not server:
        return {}
    try:
        with pg_engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT root_cause_id, step_name, param_name, current_value
                    FROM rootcause.parameter_tuning
                    WHERE server = :server
                      AND is_active
                      AND current_value IS NOT NULL
                """),
                {"server": server},
            ).fetchall()
    except Exception as ex:
        # Missing table (migration not applied yet) must never stop collection.
        db_write_log(f"parameter_tuning lookup skipped: {ex}", 0, _PROC, server)
        return {}

    out = {}
    for rc_id, step_name, param_name, value in rows:
        key = (rc_id, step_name)
        bucket = out.setdefault(key, {})
        # numeric() -> Decimal; keep it JSON/str-substitution friendly
        bucket[param_name] = float(value) if value is not None else None
    return out


def apply_parameter_overrides(pg_engine, server, queries_df):
    """Overlay this server's learned thresholds onto queries_df['step_parameters'].

    Returns the number of rows whose parameters were changed. The dataframe is
    modified in place; the caller must recompute calc_query afterwards.
    """
    if queries_df is None or queries_df.empty:
        return 0

    overrides = load_overrides(pg_engine, server)
    if not overrides:
        return 0

    changed = 0
    for idx, row in queries_df.iterrows():
        params = _as_dict(row.get("step_parameters"))
        if not params:
            continue

        over = overrides.get((row.get("root_cause_id"), row.get("step_name")))
        if not over:
            continue

        merged = dict(params)
        touched = []
        for param_name, new_value in over.items():
            if param_name in merged and new_value is not None and merged[param_name] != new_value:
                merged[param_name] = new_value
                touched.append(f"{param_name}: {params[param_name]} -> {new_value}")

        if touched:
            queries_df.at[idx, "step_parameters"] = merged
            changed += 1
            db_write_log(
                f"threshold override applied for {row.get('root_cause_id')} / "
                f"{row.get('step_name')}: {', '.join(touched)}",
                0, _PROC, server)

    return changed
