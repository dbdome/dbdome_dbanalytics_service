#monitoring_metrics_mssql_latency
import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.metric_json import to_records_json
from utils.log4dbexpert import db_write_log

# Security-agent annotation. Optional by construction: if the package is absent
# or fails to import, the shim returns the metadata untouched so collection is
# completely unaffected. annotate() itself never raises and never suppresses an
# alert -- it only adds `reason` to the payload.
try:
    from security_agent.runner import annotate as _sec_annotate
except Exception:  # pragma: no cover - agent is optional
    def _sec_annotate(*, metadata=None, **_kw):
        return metadata
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
from alerts.alert_dispatcher import dispatch          # background alert delivery
from alerts.alert_helper import manage_diagnosys_alerts
from collection.comparison import compute_calc_query
import json
import re


def _domain_clause(domain_filter):
    """Return a SQL WHERE clause fragment to filter by domain prefix."""
    if domain_filter == 'SEC':
        return "AND cm.metric_name LIKE 'SEC-%%'"
    elif domain_filter == 'PERF':
        return "AND cm.metric_name LIKE 'PERF-%%'"
    elif domain_filter == 'HLTH':
        return "AND cm.metric_name LIKE 'HLTH-%%'"
    elif domain_filter == 'OTHER':
        return "AND cm.metric_name NOT LIKE 'SEC-%%' AND cm.metric_name NOT LIKE 'PERF-%%' AND cm.metric_name NOT LIKE 'HLTH-%%'"
    return ""


_VALID_RISK_LEVELS = ('low', 'medium', 'high', 'critical')

def _risk_clause(risk_filter, col_expr='rc.risk_level'):
    """Return a SQL WHERE clause fragment that filters by risk_level.

    col_expr lets the caller point the comparison at either the joined
    rc.risk_level column (the main SELECT) or a literal like 'medium' (the
    legacy union-all branch). Filtering on a literal that doesn't match the
    requested risk level naturally excludes the legacy branch -- legacy
    metrics have no real risk_level metadata.
    """
    if risk_filter and risk_filter in _VALID_RISK_LEVELS:
        return f"AND {col_expr} = '{risk_filter}'"
    return ""


def _substitute_parameters(sql, parameters):
    """Replace :param_name placeholders with literal values from parameters dict."""
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        if isinstance(value, str):
            sql = sql.replace(f":{key}", f"'{value}'")
        else:
            sql = sql.replace(f":{key}", str(value))
    return sql


def _build_comparison(metric_metadata_json, expected_raw, step_params=None):
    """
    Build a metric_metadata_vs_expected JSON comparing actual results to expected.
    """
    actual_rows = json.loads(metric_metadata_json) if metric_metadata_json else []
    row_count = len(actual_rows)

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
    if condition and isinstance(step_params, dict) and step_params:
        condition = _substitute_parameters(condition, step_params)
    matched = None

    if condition:
        m = re.match(r"^\s*row_count\s*([><=!]+)\s*(\d+)\s*$", condition, re.IGNORECASE)
        if m:
            op, val = m.group(1), int(m.group(2))
            if op == ">":    matched = row_count > val
            elif op == ">=":  matched = row_count >= val
            elif op == "<":   matched = row_count < val
            elif op == "<=":  matched = row_count <= val
            elif op in ("=", "=="): matched = row_count == val
            elif op in ("!=", "<>"): matched = row_count != val
        elif row_count == 0 and re.match(r"^\s*row_count\s*>", condition, re.IGNORECASE):
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

def collect_all_metrics_postgres_queries(pg_server, pg_port, pg_database, pg_username, pg_password, domain_filter=None, risk_filter=None, vendor_slug=None, server_id=None):
    """
    Retrieves metric queries from monitoring.metric_queries table, runs each against MSSQL,
    and stores results in monitoring.general_metric_metadata_results.

    vendor_slug: when None (default) the SQL filters on ('postgres','postgresql').
                 When set to a single value (e.g. 'dbanalytics' for self-monitoring)
                 the filter is narrowed to that one vendor.
    """

    # Target-DB password is stored encrypted; decrypt_secret is idempotent.
    pg_password = decrypt_secret(pg_password)

    # Strip port from server if it contains host:port
    if ':' in str(pg_server):
        pg_server = pg_server.split(':')[0]

    # Vendor filter for the rc-joined SELECT and the legacy union-all branch.
    if vendor_slug:
        vendor_filter_cm = f"lower(cm.db_vendor) = '{vendor_slug}'"
        vendor_filter_rc = f"rc.vendor_name = '{vendor_slug}'"
        vendor_filter_legacy = f"lower(db_vendor) = '{vendor_slug}'"
    else:
        vendor_filter_cm = "lower(cm.db_vendor) in ('postgres','postgresql')"
        vendor_filter_rc = "rc.vendor_name in ('postgres','postgresql')"
        vendor_filter_legacy = "lower(db_vendor) in ('postgres','postgresql')"

    # Create connection strings
    pg_conn_str = get_connection_string()
    # sslmode=prefer negotiates SSL first and falls back to plaintext, so targets
    # that REQUIRE SSL (hostssl-only pg_hba / TLS-terminating proxies) connect as
    # well as no-SSL ones. The old hardcoded sslmode=disable was rejected outright
    # by SSL-required servers. Override per-install with DBEXPERT_PG_SSLMODE
    # (disable | allow | prefer | require | verify-ca | verify-full).
    import os as _os
    _sslmode = _os.environ.get("DBEXPERT_PG_SSLMODE", "prefer")
    pg_monitored_connection_string = f"postgresql://{pg_username}:{pg_password}@{pg_server}:{pg_port}/{pg_database}?sslmode={_sslmode}"


    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_engine = create_engine(pg_conn_str)
        import os as _os
        _qt = int(_os.environ.get("DBEXPERT_QUERY_TIMEOUT", "30"))
        pg_monitored_engine = create_engine(
            pg_monitored_connection_string,
            connect_args={"connect_timeout": 15, "options": "-c statement_timeout=" + str(_qt * 1000)}  # login + per-query timeout
        )
        metadata = MetaData(schema="monitoring")

        # ========== 2. Retrieve list of queries to run ==========
        with pg_engine.connect() as conn:
            queries_df = pd.read_sql_query(
                text(f"""
                  select
      query,
      category_id,
      metric_name,
      expected,
      step_parameters,
      domain_name,
      area_name,
      issue_name,
      issue_id,
      root_cause_id,
      root_cause_name,
      root_cause_desc,
      detection_name,
      detection_desc,
      step_name,
      risk_level      
  from
  (
      SELECT  row_number() over (partition by rc.root_cause_id, rc.step_name order by rc.root_cause_id) seq,
              cm.query, cm.category_id, cm.metric_name,
              rc.expected,
              rc.parameters AS step_parameters,
              rc.domain_name,
              rc.area_name,
              rc.issue_name,
              coalesce(rc.issue_id, cm.metric_name) issue_id,
              rc.root_cause_id,
              rc.name AS root_cause_name,
              rc.root_cause_desc,
              rc.detection_name,
              rc.detection_desc,
              rc.step_name,
              rc.risk_level
      FROM metrics.v_custom_metrics cm
      JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = cm.metric_name
      JOIN rootcause.risk_level rl ON rl.risk_level = rc.risk_level  
      WHERE cm.is_active = true
        AND {vendor_filter_cm}
        and {vendor_filter_rc}
        AND rl.is_active IS TRUE
         {_domain_clause(domain_filter)}
         {_risk_clause(risk_filter)}

      ORDER BY rc.issue_id, rc.root_cause_id
  ) sub
  WHERE seq = 1
    union all
	(
		select    query,
      category_id,
      metric_name,
      null expected,
      null step_parameters,
      null domain_name,
      null area_name,
      null issue_name,
      null issue_id,
      null root_cause_id,
      null root_cause_name,
      null root_cause_desc,
      null detection_name,
      null detection_desc,
      null step_name,
      'medium' risk_level
	  from metrics.custom_metrics
	  where {vendor_filter_legacy}
	    and is_active = true
	    {_risk_clause(risk_filter, "'medium'")}
	)
                """),
                con=conn  # type: ignore[arg-type]
            )

        if queries_df.empty:
            db_write_log("✅ No active metric queries found to process.", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
            return 1

        # Overlay this server's learned thresholds (rootcause.parameter_tuning)
        # before calc_query bakes the parameters into the SQL and condition.
        # Key must match the server_key used for alert_log below (host:port).
        try:
            from utils.threshold_overrides import apply_parameter_overrides
            _srv_key = f"{pg_server}:{pg_port}" if pg_port else f"{pg_server}"
            apply_parameter_overrides(pg_engine, _srv_key, queries_df)
        except Exception as _ovr_ex:
            db_write_log(f"threshold override overlay skipped: {_ovr_ex}", 0,
                         "threshold_overrides", f"{pg_server}")

        queries_df['calc_query'] = queries_df.apply(
            lambda r: compute_calc_query(r['query'], r.get('step_parameters'), r.get('expected')), axis=1
        )

        # ========== 3. Loop through each query ==========

        # Include the port so multiple PG instances on one host (e.g. 5432 + a
        # 6430 SSL cluster) are distinct servers in gmmr/alerts/dashboards.
        server_key = f"{pg_server}:{pg_port}" if pg_port else f"{pg_server}"
        for _, query_row in queries_df.iterrows():  # Renamed to avoid confusion
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
            if is_self_activity(metric_name, query_row.get('query'), 'postgresql'):
                db_write_log(f"Metric '{metric_name}' suppressed as DBDOME self-activity/benign inventory - not stored, not alerted.",
                             0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
                continue

            print(f"🔍 Running metric: {metric_name}")

            try:
                # ========== 4. Execute metric query ==========
                step_params = query_row.get('step_parameters')
                if step_params:
                    if isinstance(step_params, str):
                        try:
                            step_params = json.loads(step_params)
                        except (json.JSONDecodeError, ValueError):
                            step_params = None
                    if step_params:
                        metric_query = _substitute_parameters(metric_query, step_params)

                df = pd.read_sql_query(text(metric_query), con=pg_monitored_engine)
                # drop rows for logins registered in metrics.exclude_logins (self-activity)
                df = filter_excluded_logins(df)
                # drop captured statements that are DBDOME's own collector SQL
                df = filter_self_statements(df)

                # ========== 5. Convert results to JSON ==========
                metric_metadata_json = to_records_json(df)
                comparison = _build_comparison(metric_metadata_json, query_row.get('expected'), step_params)
                
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, pg_server, metric_metadata_json, _server_id=server_id)

                # A metric that returned no rows is stored as an empty [] - NOT as a
                # synthetic all-null row. Faking one row to "document the column shape"
                # made every empty result look like a result: the monitoring views shred
                # metric_metadata with jsonb_array_elements, so each empty sweep produced a
                # phantom all-null row. Seen live on SEC-SQL-ACC-011-RC02 against
                # 192.168.200.50 - 7 fake "active transactions", every column null.
                # Condition evaluation never saw the fake row: _build_comparison runs
                # ABOVE this point, on the real (empty) result.

                # ========== 6. Prepare payload (queue for bulk insert) ==========
                insert_payloads = []
                insert_payloads.append({
                    "server": server_key,
                    "server_id": server_id,
                    "category_id": category_id,
                    "metric_name": metric_name,
                    "metric_config": json.dumps({"query": metric_query, "calc_query": query_row.get('calc_query') or metric_query}),
                    "metric_metadata": metric_metadata_json,
                    "metric_metadata_vs_expected": (
                        (query_row.get('expected') if isinstance(query_row.get('expected'), str)
                         else json.dumps(query_row.get('expected')) if query_row.get('expected') is not None
                         else comparison)
                        if df.empty
                        else comparison
                    ),
                })
                     # ========== 9. Bulk insert all queued payloads ==========
                if insert_payloads:
                    _bulk_insert(insert_payloads, pg_engine, pg_server, pg_port)
                    db_write_log("✅ All metrics inserted successfully (bulk).", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)


                # ========== 8. Send alert if matched ==========
                comparison_data = json.loads(comparison)
                if comparison_data.get("matched") is True:
                    _risk_level = query_row.get('risk_level') or comparison_data.get('severity') or 'medium'
                    # ===== add to alerts.alert_log =====
                    alert_row_id = None
                    try:
                        with pg_engine.begin() as alog:
                            # One alert per (server, root_cause_id) per hour: drop any earlier alert for
                            # this server + root cause in the current hour, so only the latest survives.
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
                                    # postgres writes comparison_data (not the raw
                                    # rows) as its alert metadata - annotate that.
                                    "meta": json.dumps(_sec_annotate(
                                        server=server_key,
                                        root_cause_id=query_row.get('root_cause_id') or metric_name,
                                        query_text=metric_query,
                                        metadata=comparison_data,
                                        metric_name=metric_name,
                                        risk_level=_risk_level,
                                        domain=query_row.get('domain_name'),
                                    )),
                                    "login_name": next((r.get('login_name') for r in metric_metadata_json if isinstance(r, dict)), None) if isinstance(metric_metadata_json, list) else metric_metadata_json.get('login_name') if isinstance(metric_metadata_json, dict) else None,
                                }
                            ).scalar()
                    except Exception as alog_ex:
                        db_write_log(f"alert_log insert failed for '{metric_name}': {alog_ex}", 0,
                                     "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
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
                        db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)

                    if not alert_authorised:
                        db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
                    else:
                        try:
                            dispatch(send_mail_alert_no_attachment, 
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
                            db_write_log(f"Alert sent for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
                        except Exception as alert_ex:
                            db_write_log(f"Alert failed for '{metric_name}': {alert_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)

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
                                dispatch(siem_rapid_send, _rc_id, _risk_level, server_key, _desc)
                                dispatch(siem_crowdstrike_send,
                                    event_type=_rc_id,
                                    severity=_risk_level,
                                    server=server_key,
                                    root_cause_id=_rc_id,
                                    description=_desc,
                                    additional_data=_details,
                                )
                                dispatch(siem_wazuh_send,
                                    event_type=_rc_id,
                                    severity=_risk_level,
                                    server=server_key,
                                    root_cause_id=_rc_id,
                                    description=_desc,
                                    additional_data=_details,
                                )
                                dispatch(siem_send_all,
                                    event_type=_rc_id,
                                    severity=_risk_level,
                                    server=server_key,
                                    root_cause_id=_rc_id,
                                    description=_desc,
                                    additional_data=_details,
                                )
                    except Exception as siem_ex:
                        db_write_log(f"SIEM alert failed for '{metric_name}': {siem_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)

                    try:
                        with pg_engine.connect() as pg_check:
                            diag_row = pg_check.execute(
                                text("""
                                    SELECT 1 FROM config.webook_alerts w
                                    JOIN rootcause.domains d ON d.name = w.metric_type
                                    WHERE d.code = :domain_code
                                      AND w.risk_level = :risk_level
                                      AND w.send_diagnosis_evidence IS TRUE
                                    LIMIT 1
                                """),
                                {"domain_code": domain_filter or '', "risk_level": _risk_level}
                            ).fetchone()
                            if diag_row is not None:
                                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, pg_server, metric_metadata_json, _server_id=server_id)
                    except Exception as diag_ex:
                        db_write_log(f"Diagnosis evidence check failed for '{metric_name}': {diag_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)

            except Exception as metric_ex:
                db_write_log(f"❌ Metric '{metric_name}' failed with error: {metric_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)
                #manage_diagnosys_alerts(metric_name, metric_query, comparison, pg_server, metric_metadata_json, status="failed")
                continue

   
        return 1

    except Exception as e:
        db_write_log(f"❌ collect_all_metrics_postgres_queries failed with error: {e}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)        
        return 0


def _bulk_insert(insert_payloads, pg_engine, pg_server, pg_port):
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

        db_write_log(f"✅ Bulk insert done for {len(insert_payloads)} metrics.", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)

    except Exception as bulk_ex:
        db_write_log(f"❌ Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_postgres_queries", pg_server, port=pg_port)