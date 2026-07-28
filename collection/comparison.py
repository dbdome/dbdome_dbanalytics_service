"""Shared calc_query builder and parameter substitution for all collectors."""

import json
import re

__all__ = ["compute_calc_query", "substitute_parameters"]


def substitute_parameters(sql: str, parameters: dict) -> str:
    """Replace :param_name placeholders in *sql* with literal values.
    Strings are single-quoted; numbers are inlined as-is."""
    if not isinstance(sql, str):
        return sql
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        placeholder = f":{key}"
        if placeholder in sql:
            sql = sql.replace(
                placeholder,
                f"'{value}'" if isinstance(value, str) else str(value),
            )
    return sql


def compute_calc_query(
    query: str,
    step_parameters_raw=None,
    expected_raw=None,
) -> str:
    """Return the diagnostic SQL for a root-cause step.

    When *expected* contains a ``condition``, returns:

        SELECT * FROM (
            <original_query_with_params>
        ) a
        WHERE <condition_with_params>

    Running this on the monitored database returns rows only when the alert
    condition is met — paste-ready for DBA confirmation.  Without a
    condition the plain param-substituted query is returned.
    """
    # A NULL/NaN query (a metric row with no SQL) is truthy as a float and would
    # otherwise crash substitute_parameters; coerce it to an empty string.
    if not isinstance(query, str) or not query.strip():
        return query if isinstance(query, str) else ""

    # Resolve parameters
    params: dict = {}
    if isinstance(step_parameters_raw, str):
        try:
            parsed = json.loads(step_parameters_raw)
            if isinstance(parsed, dict):
                params = parsed
        except (json.JSONDecodeError, ValueError):
            pass
    elif isinstance(step_parameters_raw, dict):
        params = step_parameters_raw

    # Parse expected; pull embedded parameters if any
    expected: dict = {}
    if expected_raw is not None:
        if isinstance(expected_raw, str):
            try:
                parsed = json.loads(expected_raw)
                if isinstance(parsed, dict):
                    expected = parsed
            except (json.JSONDecodeError, ValueError):
                pass
        elif isinstance(expected_raw, dict):
            expected = expected_raw
    ep = expected.get("parameters") if expected else None
    if isinstance(ep, dict):
        params = {**ep, **params}  # explicit step_params win

    sql = substitute_parameters(query, params) if params else query

    condition = expected.get("condition", "") if expected else ""
    if condition and params:
        condition = substitute_parameters(condition, params)

    if condition:
        if re.match(r"^\s*row_count\s*(>=|<=|!=|<>|==|=|>|<)", condition, re.IGNORECASE):
            return f"SELECT COUNT(*) FROM (\n{sql}\n) A"
        return f"SELECT CASE WHEN {condition} THEN 1 ELSE 0 END\nFROM (\n{sql}\n) A"
    return sql
