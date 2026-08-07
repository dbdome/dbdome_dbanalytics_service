import pandas as pd
import re
from sqlalchemy import create_engine, text, event
from utils.config_dotenv import get_connection_string
from utils.metric_json import to_records_json
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret
try:
    from analysis.self_activity_filter import (
        is_self_activity, filter_excluded_logins, filter_self_statements)
except Exception:
    def is_self_activity(*_a, **_k):
        return False
    def filter_excluded_logins(df):
        return df
    def filter_self_statements(df):
        return df
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
from utils.alert_resultset import fetch_alert_resultset
from siem.rapid.rapid_sender import siem_rapid_send
from siem.crowdstrike.crowdstrike_sender import siem_crowdstrike_send
from siem.wazuh.wazuh_sender import siem_wazuh_send
from siem.generic.syslog_sender import siem_send_all
import json
from datetime import datetime
import pyodbc
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse
import psycopg2

from alerts.alert_helper import manage_alerts, manage_diagnosys_alerts
from alerts.alert_dispatcher import dispatch          # background alert delivery
from collection.comparison import compute_calc_query

def _register_mssql_output_converters(engine):
    """
    Register pyodbc output converters on every raw DBAPI connection to handle:
      - ODBC SQL type -16 (NVARCHAR(MAX) / XML)  -> decode as UTF-16LE
      - UTF-8 encoding errors from other column types -> replace bad bytes
    """
    @event.listens_for(engine, "connect")
    def _on_connect(dbapi_connection, connection_record):
        # Type -16 = SQL_SS_XML / SQL_WLONGVARCHAR (NVARCHAR(MAX), XML)
        def _decode_nvarchar_max(raw):
            if isinstance(raw, bytes):
                return raw.decode("utf-16le", errors="replace")
            return raw

        # Type -150 = SQL_SS_VARIANT  (common secondary offender)
        def _decode_sql_variant(raw):
            if isinstance(raw, bytes):
                return raw.decode("utf-16le", errors="replace")
            return raw

        try:
            dbapi_connection.add_output_converter(-16, _decode_nvarchar_max)
            dbapi_connection.add_output_converter(-150, _decode_sql_variant)
        except Exception:
            pass  # converter already registered or unsupported


def _substitute_parameters(sql, parameters):
    """
    Replace :param_name placeholders in SQL with literal values from
    the parameters dict.  Returns the resolved SQL string.
    """
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        if isinstance(value, str):
            sql = sql.replace(f":{key}", f"'{value}'")
        else:
            sql = sql.replace(f":{key}", str(value))
    return sql


def _compute_calc_query(query, step_parameters_raw, expected_raw=None):
    """Build the diagnostic SQL query.

    If expected contains a condition, returns:
        SELECT * FROM (<original_query>) a WHERE <condition_with_params>

    Running this against the target DB returns rows only when the alert
    condition is met, so a DBA can paste it directly to reproduce the finding.
    Without a condition, returns the plain query with params substituted.
    """
    if not query:
        return query

    # Parse parameters
    params = step_parameters_raw
    if isinstance(params, str):
        try:
            params = json.loads(params)
        except (json.JSONDecodeError, ValueError):
            params = None

    # Substitute params into the base query
    sql = query
    if params and isinstance(params, dict):
        sql = _substitute_parameters(sql, params)

    # Extract condition from expected and substitute params
    condition = ""
    if expected_raw:
        exp = expected_raw
        if isinstance(exp, str):
            try:
                exp = json.loads(exp)
            except (json.JSONDecodeError, ValueError):
                exp = {}
        if isinstance(exp, dict):
            condition = exp.get("condition", "")
            if condition and params and isinstance(params, dict):
                condition = _substitute_parameters(condition, params)

    if condition:
        calc = f"SELECT * FROM (\n{sql}\n) a\nWHERE {condition}"
    else:
        calc = sql

    return _escape_sqlalchemy_params(calc)


def _escape_sqlalchemy_params(sql):
    r"""
    Escape remaining :param-like patterns that SQLAlchemy text() would
    interpret as bound parameters.  Uses \: (literal colon) escape.
    Handles patterns like LIKE '2:%:1' where :1 looks like a parameter.
    """
    return re.sub(r'(?<!\w):(?=[a-zA-Z0-9_])', r'\\:', sql)


_SENSITIVE_TOKEN = '/*__SENSITIVE_COLS_VALUES__*/'


def _inject_sensitive_values(sql, server_key, pg_engine):
    """Replace the RC15 sensitive-list placeholder with this server's sensitive
    columns from metrics.v_sensitive_columns_all (curated UNION auto-discovered).

    Only metrics containing the placeholder are touched (RC15), so this is a
    no-op for every other metric. Fail-safe: on any error or an empty list the
    placeholder is left in place -- the stored SQL is still valid T-SQL and just
    yields the sentinel row (which matches no real query text), so the metric
    never errors and never falls back to the expensive per-cycle catalog scan.
    """
    if _SENSITIVE_TOKEN not in sql:
        return sql
    try:
        with pg_engine.connect() as c:
            rows = c.execute(
                text("""
                    SELECT db_name, schema_name, table_name, column_name, pii_category
                    FROM metrics.v_sensitive_columns_all
                    WHERE table_name IS NOT NULL
                      AND (server = :srv OR server IS NULL)
                """),
                {"srv": server_key},
            ).fetchall()
    except Exception:
        return sql
    if not rows:
        return sql

    def _lit(v):
        if v is None:
            return "NULL"
        # Double single quotes for T-SQL; escape ':' so SQLAlchemy text() does
        # not read it as a bind parameter.
        return "N'" + str(v).replace("'", "''").replace(":", "\\:") + "'"

    values = ",".join(
        "(%s,%s,%s,%s,%s)" % (_lit(r[0]), _lit(r[1]), _lit(r[2]), _lit(r[3]), _lit(r[4]))
        for r in rows
    )
    return sql.replace(_SENSITIVE_TOKEN, "," + values)


def _sanitize_json(text):
    """
    Remove null bytes (\u0000 / \x00) from JSON strings.
    PostgreSQL text/jsonb columns cannot store \u0000.
    SQL Server sql_variant columns (e.g. sys.configurations.value_in_use)
    may contain embedded null bytes that break PostgreSQL inserts.
    """
    if text is None:
        return text
    return text.replace('\x00', '').replace('\\u0000', '')


def _sql_condition_to_python(condition):
    """Convert SQL-style boolean operators to Python so eval() can run them."""
    condition = re.sub(r'\bOR\b',  'or',  condition, flags=re.IGNORECASE)
    condition = re.sub(r'\bAND\b', 'and', condition, flags=re.IGNORECASE)
    # Replace bare = with == but leave >=, <=, != untouched
    condition = re.sub(r'(?<![<>!])=(?!=)', '==', condition)
    return condition


def _build_comparison(metric_metadata_json, expected_raw, step_params=None):
    """
    Build a metric_metadata_vs_expected JSON comparing actual results to expected.

    Supports two condition styles:
      row_count > N          — compares the number of returned rows
      col_a > col_b * 85    — evaluated against the first result row's columns
                               (parameters substituted before evaluation)
    """
    actual_rows = json.loads(metric_metadata_json) if metric_metadata_json else []
    row_count = len(actual_rows)

    # Parse expected
    if expected_raw is None:
        expected = {}
    elif isinstance(expected_raw, str):
        try:
            expected = json.loads(expected_raw)
        except (json.JSONDecodeError, ValueError):
            expected = {}
    else:
        expected = expected_raw if isinstance(expected_raw, dict) else {}

    condition = expected.get("condition", "")

    # Substitute :param placeholders in the condition (same params used in the query)
    if condition and step_params and isinstance(step_params, dict):
        condition = _substitute_parameters(condition, step_params)

    matched = None
    if condition:
        # ── row_count pattern ─────────────────────────────────────────────
        m = re.match(r"^\s*row_count\s*([><=!]+)\s*(\d+)\s*$", condition, re.IGNORECASE)
        if m:
            op, val = m.group(1), int(m.group(2))
            if op == ">":             matched = row_count > val
            elif op == ">=":          matched = row_count >= val
            elif op == "<":           matched = row_count < val
            elif op == "<=":          matched = row_count <= val
            elif op in ("=", "=="):   matched = row_count == val
            elif op in ("!=", "<>"): matched = row_count != val
        else:
            # ── column-value expression: evaluate against first result row ─
            if actual_rows:
                try:
                    py_cond = _sql_condition_to_python(condition)
                    row_ns = {str(k): v for k, v in actual_rows[0].items()}
                    matched = bool(eval(py_cond, {"__builtins__": {}}, row_ns))  # noqa: S307
                except Exception:
                    matched = None
            elif row_count == 0 and re.match(r"^\s*row_count\s*>", condition, re.IGNORECASE):
                # 0 rows can never satisfy row_count > N for any non-negative N
                matched = False
    else:
        matched = row_count > 0

    if matched is None:
        matched = False

    return json.dumps({
        "row_count": row_count,
        "sample_rows": actual_rows[:5],
        "expected": expected,
        "condition": condition,
        "matched": matched,
        "severity": expected.get("severity"),
    })

def _build_mssql_engine(driver, server_str, database, username, password, auth_type, encrypt=None):
    """Build a SQLAlchemy MSSQL engine from an already-composed server string.

    encrypt: 'yes' | 'no' | 'optional'. Defaults to the DBEXPERT_MSSQL_ENCRYPT env
    var, else 'yes'. Encrypt=no is needed for older SQL Servers (e.g. SQL 2012/2014
    or SQL Express) that don't support the TLS that ODBC Driver 18 enforces by
    default — those fail the encrypted handshake rather than time out.
    """
    import os as _os
    if encrypt is None:
        encrypt = _os.environ.get("DBEXPERT_MSSQL_ENCRYPT", "yes")
    # Login timeout: fail fast on an unreachable server instead of hanging.
    common = f"Encrypt={encrypt};TrustServerCertificate=yes;Connection Timeout=15;"
    if auth_type == "win":
        odbc_str = (
            f"DRIVER={{{driver}}};SERVER={server_str};DATABASE={database or 'master'};"
            f"Trusted_Connection=yes;{common}"
        )
    else:
        odbc_str = (
            f"DRIVER={{{driver}}};SERVER={server_str};DATABASE={database or 'master'};"
            f"UID={username};PWD={password};{common}"
        )
    conn_str = "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)
    engine = create_engine(conn_str)
    _register_mssql_output_converters(engine)

    # Per-query timeout (seconds): a single slow metric query on the target can no
    # longer stall the whole collection cycle. On timeout pyodbc raises, the
    # per-metric handler logs it and collection continues. 0 = no limit.
    import os as _os
    _qt = int(_os.environ.get("DBEXPERT_QUERY_TIMEOUT", "30"))
    if _qt > 0:
        @event.listens_for(engine, "connect")
        def _set_query_timeout(dbapi_conn, _rec):
            try:
                dbapi_conn.timeout = _qt   # pyodbc connection query timeout
            except Exception:
                pass
    return engine


def _test_mssql_engine(engine):
    """Return True if the engine can open a connection."""
    try:
        with engine.connect() as c:
            c.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


def collect_all_metrics_mssql_queries(mssql_server, mssql_database, mssql_username, mssql_password, mssql_driver, auth_type, mssql_port=None, domain_filter=None, risk_filter=None, server_id=None):
    """
    Retrieves metric queries from monitoring.metric_queries table, runs each against MSSQL,
    and stores results in monitoring.general_metric_metadata_results.

    domain_filter: None = all metrics, or one of 'SEC', 'PERF', 'HLTH', 'OTHER'
    risk_filter:   None = all risk levels, or one of 'low','medium','high','critical'
    """

    # The target-DB password is stored encrypted (enc:v1:...); decrypt_secret is
    # idempotent (plaintext / already-decrypted values pass through unchanged).
    mssql_password = decrypt_secret(mssql_password)

    installed_drivers = pyodbc.drivers()
    print("Installed drivers:", installed_drivers)

    priority = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"]
    selected_driver = next((d for d in priority if d in installed_drivers), None)
    if selected_driver is None:
        raise RuntimeError("No suitable ODBC driver found!")
    print("Selected driver:", selected_driver)
    driver = selected_driver

    pg_conn_str = get_connection_string()

    # Primary attempt: use server as-is (may already contain host\instance or host:port)
    primary_server_str = f"{mssql_server},{mssql_port}" if mssql_port else mssql_server
    mssql_engine = _build_mssql_engine(driver, primary_server_str, mssql_database,
                                       mssql_username, mssql_password, auth_type)

    if not _test_mssql_engine(mssql_engine):
        # Fallback: force explicit TCP with ip,port notation.
        # Covers cases where the primary string uses a hostname that doesn't
        # resolve, a named instance, or Named Pipes as the default protocol.
        fallback_port = int(mssql_port) if mssql_port else 1433
        fallback_server_str = f"{mssql_server},{fallback_port}"
        db_write_log(
            f"Primary connection failed — retrying with '{fallback_server_str}'",
            0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port,
        )
        mssql_engine = _build_mssql_engine(driver, fallback_server_str, mssql_database,
                                           mssql_username, mssql_password, auth_type)

    if not _test_mssql_engine(mssql_engine):
        # Fallback 2: older servers reject ODBC Driver 18's enforced TLS — retry the
        # original server string with Encrypt=no (still TrustServerCertificate=yes).
        db_write_log(
            f"Encrypted connection failed — retrying '{primary_server_str}' with Encrypt=no",
            0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port,
        )
        mssql_engine = _build_mssql_engine(driver, primary_server_str, mssql_database,
                                           mssql_username, mssql_password, auth_type,
                                           encrypt="no")

    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_engine = create_engine(pg_conn_str)

        # ========== 2. Retrieve list of queries to run ==========
        # Build domain filter clause
        if domain_filter == 'SEC':
            domain_clause = "AND cm.metric_name LIKE 'SEC-%%'"
        elif domain_filter == 'PERF':
            domain_clause = "AND cm.metric_name LIKE 'PERF-%%'"
        elif domain_filter == 'HLTH':
            domain_clause = "AND cm.metric_name LIKE 'HLTH-%%'"
        elif domain_filter == 'OTHER':
            domain_clause = "AND cm.metric_name NOT LIKE 'SEC-%%' AND cm.metric_name NOT LIKE 'PERF-%%' AND cm.metric_name NOT LIKE 'HLTH-%%'"
        else:
            domain_clause = ""  # no filter = all metrics

        # Build risk_level filter clauses (one for the rc-joined SELECT, one for
        # the legacy union-all branch which hard-codes 'medium').
        if risk_filter in ('low', 'medium', 'high', 'critical'):
            risk_clause_main   = f"AND rc.risk_level = '{risk_filter}'"
            risk_clause_legacy = f"AND 'medium' = '{risk_filter}'"
        else:
            risk_clause_main   = ""
            risk_clause_legacy = ""

        with pg_engine.connect() as conn:
            queries_df = pd.read_sql_query(
                f"""  
 select query, category_id, metric_name, expected, step_parameters, domain_name, area_name,
        issue_name, issue_id, root_cause_id, root_cause_name, root_cause_desc, detection_name,
        detection_desc, step_name, risk_level, rank
 from (
   select u.*,
          row_number() over (partition by metric_name
                             order by (root_cause_id is null), rank) as dedup_rn  -- run each metric_name ONCE per cycle; prefer the root-cause-mapped row over the legacy one
   from (
 select query, category_id, metric_name, expected, step_parameters, domain_name, area_name,
       issue_name, issue_id, root_cause_id, root_cause_name, root_cause_desc, detection_name,
       detection_desc, step_name, risk_level,
       case when gmmr_metric_name is null then 0 else 1 end rank
from (
    SELECT row_number() over (partition by rc.root_cause_id, rc.step_name
                              order by rc.root_cause_id) seq,
           cm.query, cm.category_id, cm.metric_name,
           rc.expected, rc.parameters AS step_parameters,
           rc.domain_name, rc.area_name, rc.issue_name,
           coalesce(rc.issue_id, cm.metric_name) issue_id,
           rc.root_cause_id, rc.name AS root_cause_name, rc.root_cause_desc,
           rc.detection_name, rc.detection_desc, rc.step_name, rc.risk_level,
           gmmr.gmmr_metric_name
    FROM metrics.v_custom_metrics cm
    JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = cm.metric_name
    JOIN rootcause.risk_level   rl ON rl.risk_level = rc.risk_level
    LEFT OUTER JOIN (
        SELECT DISTINCT metric_name AS gmmr_metric_name
        FROM monitoring.general_metric_metadata_results where entry_date > now() - interval '1 minute'
    ) gmmr ON gmmr.gmmr_metric_name = rc.root_cause_id
    WHERE cm.is_active = true
      AND lower(cm.db_vendor) IN ('mssql', 'sqlserver')
      AND rc.vendor_name      IN ('mssql', 'sqlserver')
      AND rl.is_active IS TRUE
      {domain_clause}
      {risk_clause_main}
) sub
WHERE seq = 1
union all
(
    select query, category_id, metric_name,
           null expected, null step_parameters, null domain_name, null area_name,
           null issue_name, null issue_id, null root_cause_id, null root_cause_name,
           null root_cause_desc, null detection_name, null detection_desc, null step_name,
           'medium' risk_level,
           1 as rank                              -- ← was missing the comma before this
    from metrics.custom_metrics
    where lower(db_vendor) in ('mssql', 'sqlserver')
      and is_active = true
	  {risk_clause_legacy}
)
   ) u
 ) d
 where d.dedup_rn = 1
 order by rank;

	
                """,
                con=conn
            )

        #server_key = f"{mssql_server}:{mssql_port}" if mssql_port else mssql_server
        server_key = f"{mssql_server}" if mssql_port else mssql_server

        # Overlay this server's learned thresholds (rootcause.parameter_tuning)
        # onto the global detection_steps.parameters. Must happen BEFORE
        # calc_query is computed, since the parameters are baked into both the
        # SQL and the alert condition. No-ops when the server has no overrides.
        try:
            from utils.threshold_overrides import apply_parameter_overrides
            _tuned = apply_parameter_overrides(pg_engine, server_key, queries_df)
            if _tuned:
                db_write_log(f"applied {_tuned} tuned threshold(s) for this server", 0,
                             "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
        except Exception as _ovr_ex:
            # Tuning must never be able to stop collection.
            db_write_log(f"threshold override overlay skipped: {_ovr_ex}", 0,
                         "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)

        # Pre-compute the diagnostic SQL for every row.
        # calc_query = SELECT * FROM (<original_query>) a WHERE <condition_with_params>
        # Returns rows only when the alert condition is met — ready to paste for DBAs.
        queries_df['calc_query'] = queries_df.apply(
            lambda r: compute_calc_query(r['query'], r.get('step_parameters'), r.get('expected')), axis=1
        )

        if queries_df.empty:
            db_write_log("✅ No active metric queries found to process.", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
            return 1

        # ========== 3. Collect all results first ==========
        insert_payloads = []
        alert_queue = []
        current_issue_id = None

        # ---- Pre-execute the per-metric queries CONCURRENTLY (the slow part).
        # Each pd.read_sql_query is a network round-trip to the target server and
        # there can be hundreds per domain; running them serially is the real
        # bottleneck on a single-server deployment. The engine's connection pool
        # gives each worker its own connection. All result processing, inserts,
        # alerts below stay strictly serial (order preserved), so the
        # stateful issue-flush / bulk-insert / alert logic is unchanged.
        # Tune with DBEXPERT_QUERY_PARALLELISM (1 = serial, the old behaviour).
        import os as _os
        from concurrent.futures import ThreadPoolExecutor as _TPE, as_completed as _ac
        _qpar = max(1, int(_os.environ.get('DBEXPERT_QUERY_PARALLELISM', '6')))
        _rows = list(queries_df.iterrows())

        def _prefetch_query(qr):
            sp_raw = qr.get('step_parameters')
            sp = sp_raw
            if isinstance(sp, str):
                try:
                    sp = json.loads(sp)
                except (json.JSONDecodeError, ValueError):
                    sp = None
            mq = _compute_calc_query(qr['query'], sp_raw)
            mq = _inject_sensitive_values(mq, server_key, pg_engine)
            return (pd.read_sql_query(text(mq), con=mssql_engine), mq, sp)

        prefetch = {}
        if _rows:
            with _TPE(max_workers=min(_qpar, len(_rows))) as _pool:
                _futs = {_pool.submit(_prefetch_query, qr): pos for pos, (_, qr) in enumerate(_rows)}
                for _f in _ac(_futs):
                    _p = _futs[_f]
                    try:
                        prefetch[_p] = _f.result()
                    except Exception as _e:           # defer to the serial loop's per-metric handler
                        prefetch[_p] = ('__error__', _e)

        for _pos, (_, query_row) in enumerate(_rows):
            # pd.read_sql_query turns SQL NULLs into float NaN. NaN is truthy,
            # so downstream `query_row.get('x') or ''` does NOT replace it: the
            # NaN leaks into alert_log, the email body (as the text "nan"), and
            # into the mail-auth gate where psycopg2 renders it 'NaN'::float8 ->
            # trim() resolves to the non-existent btrim(double precision). The
            # legacy custom_metrics UNION branch selects all-NULL domain/area/
            # issue/etc., so this fires for unmapped custom metrics. Normalise
            # NaN -> None up front so every `... or ''` behaves as intended.
            query_row = query_row.where(pd.notna(query_row), None)
            metric_query = query_row['query']
            category_id = query_row['category_id']
            metric_name = query_row['metric_name']

            # ---- self-activity / false-alarm suppression (analysis.suppression_rules) ----
            if is_self_activity(metric_name, query_row.get('query'), 'sqlserver'):
                db_write_log(f"Metric '{metric_name}' suppressed as DBDOME self-activity/benign inventory - not stored, not alerted.",
                             0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                continue
            issue_id = query_row['issue_id']
            expected = query_row['expected']
            risk_level = query_row['risk_level']

            print(f"🔍 Running metric: {metric_name}")
            # ========== Flush when issue_id changes ==========
            if issue_id is None:
                    _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port)
            if current_issue_id is not None and issue_id != current_issue_id:                
                _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port)
                insert_payloads = []  # reset for next issue
            current_issue_id = issue_id

            try:
                # Execute the plain query (params substituted, no WHERE wrapper) to
                # get the full result set stored in metric_metadata.
                # calc_query (with WHERE) is stored in metric_config for DBA reference.
                # Consume the result pre-fetched concurrently above. Re-raise its
                # error so the existing per-metric except-handler treats it exactly
                # as before (log + continue).
                _pre = prefetch.get(_pos)
                if isinstance(_pre, tuple) and len(_pre) == 2 and _pre[0] == '__error__':
                    raise _pre[1]
                df, metric_query, step_params = _pre
                # drop rows for logins registered in metrics.exclude_logins (self-activity)
                df = filter_excluded_logins(df)
                # drop captured statements that are DBDOME's OWN collector SQL — the
                # destructive-DDL detections were reporting DBDOME's temp tables
                # (CREATE/DROP #sensitive_cols) as destructive DDL.
                df = filter_self_statements(df)
                # Fix Windows-1252 chars (e.g. 0x96 en-dash) that break UTF-8 encoding
                for col in df.select_dtypes(include=['object']).columns:
                    df[col] = df[col].apply(lambda v: v.encode('utf-8', errors='replace').decode('utf-8') if isinstance(v, str) else v)
                metric_metadata_json = _sanitize_json(to_records_json(df))
                comparison = _sanitize_json(_build_comparison(metric_metadata_json, query_row.get('expected'), step_params))

                # If the metric returned no rows, replace the empty '[]' with
                # a single all-null row showing the column shape.
                if df.empty and len(df.columns) > 0:
                    metric_metadata_json = _sanitize_json(json.dumps([{c: None for c in df.columns.tolist()}]))

                insert_payloads.append({
                    "server_id": server_id ,
                    "server": server_key ,
                    "category_id": category_id,
                    "metric_name": metric_name,
                    "metric_config": _sanitize_json(json.dumps({
                        "query": metric_query,
                        "calc_query": query_row['calc_query'],
                    })),
                    "metric_metadata": metric_metadata_json,
                    "metric_metadata_vs_expected": (
                        (query_row.get('expected') if isinstance(query_row.get('expected'), str)
                         else json.dumps(query_row.get('expected')) if query_row.get('expected') is not None
                         else comparison)
                        if df.empty
                        else comparison
                    )
                })
                _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port)
                # Queue alerts separately
                comparison_data = json.loads(comparison)
                if comparison_data.get("matched") is True:
                    alert_queue.append((metric_name, metric_query, query_row, comparison_data))
                    #manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, mssql_server, metric_metadata_json, _server_id=server_id)

                print(f"✅ Metric '{metric_name}' collected.")
                db_write_log(f"✅ Metric '{metric_name}' collected.", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
            except Exception as metric_ex:
                db_write_log(f"❌ Metric '{metric_name}' failed: {metric_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                print(f"❌ Metric '{metric_name}' Error.{metric_ex},Query:{metric_query}")
                continue

            # ========== 4. Bulk insert any remaining results ==========
            if insert_payloads:
                _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port)
            db_write_log("✅ All metrics inserted successfully (bulk).", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)        
            # ========== 5. Send queued alerts (if authorised) ==========
            for metric_name, metric_query, query_row, comparison_data in alert_queue:
                _risk_level = query_row.get('risk_level') or 'medium'
                # ===== add to alerts.alert_log =====
                alert_row_id = None
                try:
                    with pg_engine.begin() as alog:
                        # One alert per (server, root_cause_id) per hour: drop any
                        # earlier alert for this server + root cause in the current
                        # hour, so only the latest survives.
                        alog.execute(
                            text("""
                                DELETE FROM alerts.alert_log
                                WHERE server = :server
                                  AND root_cause_id = :rc
                                  AND date_trunc('hour', entry_date) = date_trunc('hour', LOCALTIMESTAMP)
                            """),
                            {"server": server_key, "rc": query_row.get('root_cause_id') or metric_name}
                        )
                        alert_row_id = alog.execute(
                            text("""
                                INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name)
                                VALUES (:server, :rc, :risk, CAST(:meta AS jsonb), :login_name)
                                RETURNING row_id
                            """),
                            {
                                "server": server_key,
                                "rc": query_row.get('root_cause_id') or metric_name,
                                "risk": _risk_level,
                                "meta": json.dumps(metric_metadata_json),
                                "login_name": next((r.get('login_name') for r in metric_metadata_json if isinstance(r, dict)), None) if isinstance(metric_metadata_json, list) else metric_metadata_json.get('login_name') if isinstance(metric_metadata_json, dict) else None,
                            }
                        ).scalar()
                except Exception as alog_ex:
                    db_write_log(f"alert_log insert failed for '{metric_name}': {alog_ex}", 0,
                                 "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                # ===== end alerts.alert_log =====
                alert_authorised = False
                try:
                    with pg_engine.connect() as pg_check:
                        mail_auth_row = pg_check.execute(
                            text("""
                                SELECT
                                    mal.entry_date > NOW() - (wba.recurrency_hours || ' hours')::interval AS in_recurrency_window
                                FROM alerts.mail_alert_log mal
                                JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = mal.metric_name
                                JOIN config.webook_alerts wba ON wba.metric_type = rc.domain_name
                                    AND rc.risk_level = wba.risk_level
                                WHERE wba.send_mail_alert IS TRUE
                                  AND mal.metric_name = :metric_name
                                  AND mal.server = :server
                                ORDER BY mal.entry_date DESC
                                LIMIT 1
                            """),
                            {"metric_name": metric_name, "server": server_key}
                        ).fetchone()
                        alert_authorised = mail_auth_row is None or not mail_auth_row[0]
                except Exception as auth_ex:
                    db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                    #manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, mssql_server, metric_metadata_json, status="failed", _server_id=server_id)

                if not alert_authorised:
                    db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                    continue

                # Deliver the email in the BACKGROUND so a slow/unreachable mail
                # server never blocks collection (was the cause of the stall +
                # "idle in transaction"). dispatch() never blocks the collector.
                dispatch(
                    send_mail_alert_no_attachment,
                    label=f"mail:{metric_name}",
                    server=server_key,
                    domain_name=query_row.get('domain_name') or '',
                    area_name=query_row.get('area_name') or '',
                    issue_name=query_row.get('issue_name') or '',
                    root_cause_id=query_row.get('root_cause_id') or metric_name,
                    root_cause_name=query_row.get('root_cause_name') or metric_name,
                    root_cause_desc=query_row.get('root_cause_desc') or '',
                    detection_name=query_row.get('detection_name') or '',
                    detection_desc=query_row.get('detection_desc') or '',
                    step_name=query_row.get('step_name') or '',
                    risk_level=_risk_level,
                    query=metric_query,
                    expected=query_row.get('expected'),
                    comparison_data=comparison_data,
                    metric_metadata_json=metric_metadata_json,
                    alert_id=alert_row_id,
                )
                db_write_log(f"Alert queued for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)

                try:
                    with pg_engine.connect() as pg_check:
                        siem_row = pg_check.execute(
                            text("""
                                SELECT 1 FROM config.webook_alerts w
                                JOIN rootcause.domains d ON d.name = w.metric_type
                                WHERE d.code = :domain_code
                                  AND w.risk_level = :risk_level
                                  AND w.send_siem_alert IS TRUE
                                LIMIT 1
                            """),
                            {"domain_code": domain_filter or '', "risk_level": _risk_level}
                        ).fetchone()
                        if siem_row is not None:
                            _rc_id = query_row.get('root_cause_id') or metric_name
                            _desc = (
                                f"area:{query_row.get('area_name') or ''}, "
                                f"domain:{query_row.get('domain_name') or ''}, "
                                f"issue:{query_row.get('issue_name') or ''}, "
                                f"root:{query_row.get('root_cause_name') or metric_name}"
                            ).encode('utf-8', errors='ignore').decode('utf-8')
                            # Detection results delivered to SIEM = the alert's
                            # canonical resultset (same rows as the alert panel):
                            # monitoring.get_alert_log_resultset_byid(alert_id).
                            _details = None
                            if alert_row_id:
                                _rows = fetch_alert_resultset(alert_row_id)
                                if _rows:
                                    _details = {"alert_id": alert_row_id,
                                                "detection_results": _rows}
                            # SIEM/webhook deliveries are HTTP — also dispatch them
                            # to the background so they can't block collection.
                            dispatch(siem_rapid_send, _rc_id, _risk_level, server_key, _desc,
                                     label=f"siem_rapid:{metric_name}")
                            dispatch(siem_crowdstrike_send, label=f"siem_cs:{metric_name}",
                                     event_type=_rc_id,
                                     severity=_risk_level,
                                     server=server_key,
                                     root_cause_id=_rc_id,
                                     description=_desc,
                                     additional_data=_details)
                            dispatch(siem_wazuh_send, label=f"siem_wazuh:{metric_name}",
                                     event_type=_rc_id,
                                     severity=_risk_level,
                                     server=server_key,
                                     root_cause_id=_rc_id,
                                     description=_desc,
                                     additional_data=_details)
                            dispatch(siem_send_all, label=f"siem_generic:{metric_name}",
                                     event_type=_rc_id,
                                     severity=_risk_level,
                                     server=server_key,
                                     root_cause_id=_rc_id,
                                     description=_desc,
                                     additional_data=_details)
                except Exception as siem_ex:
                    db_write_log(f"SIEM alert failed for '{metric_name}': {siem_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)

            # This metric's alerts have been sent — clear the queue. Section 5 runs
            # INSIDE the per-metric loop, so without this it re-sent every prior
            # alert on every iteration (duplicate alert_log rows + wrong metadata).
            alert_queue.clear()

        return 1

    except Exception as e:
        db_write_log(f"❌ collect_all_metrics_mssql_queries failed with error: {e}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
    return 0



def _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port):
    if not insert_payloads:
        return
    try:
        with pg_engine.begin() as conn_pg:
            conn_pg.execute(
                text("""
                    INSERT INTO monitoring.general_metric_metadata_results
                        (server, category_id, metric_name, metric_config, metric_metadata, metric_metadata_vs_expected,server_id)
                    VALUES
                        (:server, :category_id, :metric_name, :metric_config, :metric_metadata, :metric_metadata_vs_expected,:server_id)
                """),
                insert_payloads
            )

            for payload in insert_payloads:
                conn_pg.execute(
                    text("CALL rootcause.update_root_cause_result(:p_root_cause_id, :p_server)"),
                    {"p_root_cause_id": payload["metric_name"], "p_server": payload["server"]}
                )
           
        _n = len(insert_payloads)
        # Clear after a successful commit so each payload is inserted EXACTLY once.
        # The collection loop calls _bulk_insert repeatedly on this same growing list
        # (per metric + per issue + section-4), which was re-inserting everything
        # every iteration — O(K^2) writes of large metric_metadata blobs (the cause
        # of the slowness and of duplicate rows). In-place clear, so callers see it empty.
        insert_payloads.clear()
        db_write_log(f"✅ Bulk insert done for {_n} metrics.", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)

    except Exception as bulk_ex:
        db_write_log(f"❌ Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
    
