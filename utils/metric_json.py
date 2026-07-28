"""Serialize a metric-result DataFrame to JSON records with human-readable
timestamps.

pandas' ``DataFrame.to_json(orient='records')`` renders datetime64 columns as
epoch milliseconds (its ``date_format='epoch'`` default), which is why the stored
``monitoring.general_metric_metadata_results.metric_metadata`` showed unix time.
``to_records_json`` first converts any datetime / datetime-with-tz column to a
``'YYYY-MM-DD HH:MM:SS'`` string so every consumer (the alert-email table, the
Grafana ``monitoring.v_*`` views, ``get_alert_log_resultset_byid``) shows a real
timestamp.

Defaults (agreed): local wall-clock is preserved (no timezone shift); tz-aware
columns are formatted in their own offset; NaT becomes JSON null. Columns that are
plain integers (e.g. a bigint that happens to hold a unix epoch) are intentionally
left untouched — converting them would require guessing the unit.

Use this in the generic collectors in place of ``df.to_json(orient='records')``.
"""
import pandas as pd  # noqa: F401  (kept for type clarity / future use)

_TS_FMT = "%Y-%m-%d %H:%M:%S"


def to_records_json(df):
    """Return ``df`` as a JSON 'records' string with datetime columns formatted
    as 'YYYY-MM-DD HH:MM:SS' instead of epoch milliseconds. Mirrors the prior
    ``df.to_json(orient='records', default_handler=str)`` for everything else."""
    if df is None:
        return "[]"
    if df.empty:
        return df.to_json(orient="records")
    out = df.copy()
    for col in out.select_dtypes(include=["datetime", "datetimetz"]).columns:
        formatted = out[col].dt.strftime(_TS_FMT)        # NaT -> the string 'NaT'
        out[col] = formatted.where(out[col].notna(), None)  # 'NaT' -> None (JSON null)
    return out.to_json(orient="records", default_handler=str)
