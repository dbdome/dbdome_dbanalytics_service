"""Shared calc_query builder and parameter substitution for all collectors."""

import json
import re

__all__ = ["compute_calc_query", "substitute_parameters"]


# A step's SQL is only wrappable in a derived table -- FROM ( <sql> ) A -- when it
# is a SINGLE SELECT EXPRESSION. Statement-level SQL is not: control flow and
# multi-statement batches are illegal inside a subquery, so wrapping them yields
# SQL that cannot parse ("Incorrect syntax near the keyword 'IF'").
#
# This bit: SEC-SQL-ACC-011-RC02 gained an
#   IF HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1 BEGIN ... END ELSE ...
# guard, and its stored calc_query became unrunnable. calc_query is the
# paste-ready query handed to a DBA, so a broken one is only found when someone
# pastes it -- hence the conservative check here rather than trusting the input.
_UNWRAPPABLE_START = re.compile(
    r"^\s*(IF|DECLARE|SET|EXEC|EXECUTE|BEGIN|USE|CREATE|ALTER|DROP|TRUNCATE|MERGE)\b",
    re.IGNORECASE,
)


def _is_wrappable(sql: str) -> bool:
    """True when *sql* can be nested inside FROM ( ... ) A.

    Deliberately conservative: a false 'no' costs only the COUNT/CASE wrapper
    (the caller falls back to the plain query, which is always valid), while a
    false 'yes' produces SQL that fails to parse.

    NOT rejected: a leading WITH. A CTE is legal inside a subquery on
    PostgreSQL, and rejecting it here would regress every pg CTE step. It is
    illegal on SQL Server -- but that is a pre-existing, vendor-specific gap and
    this module has no vendor context to decide it.
    """
    body = sql.strip().rstrip(";").strip()
    if not body:
        return False
    if _UNWRAPPABLE_START.match(body):
        return False
    # A ';' left after stripping one trailing terminator means a multi-statement
    # batch. (A ';' inside a string literal reads as a batch too -- conservative
    # by design; the cost is a missing wrapper, not a broken query.)
    return ";" not in body


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
        if not _is_wrappable(sql):
            # Statement-level SQL (control flow / multi-statement batch): hand back
            # the query itself. The DBA gets something that RUNS and shows the rows,
            # just without the count/verdict wrapper -- strictly better than a
            # wrapped string that cannot parse.
            return sql
        # Strip one trailing ';' - legal in a standalone query, illegal as the last
        # token inside a derived table.
        body = sql.strip().rstrip(";").strip()
        if re.match(r"^\s*row_count\s*(>=|<=|!=|<>|==|=|>|<)", condition, re.IGNORECASE):
            return f"SELECT COUNT(*) FROM (\n{body}\n) A"
        return f"SELECT CASE WHEN {condition} THEN 1 ELSE 0 END\nFROM (\n{body}\n) A"
    return sql
