import pandas as pd
from sqlalchemy import create_engine, text
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
from siem.rapid.rapid_sender import siem_rapid_send
from siem.crowdstrike.crowdstrike_sender import siem_crowdstrike_send
from alerts.alert_dispatcher import dispatch          # background alert delivery
from alerts.alert_helper import manage_diagnosys_alerts
from collection.comparison import compute_calc_query
import json
import re
from datetime import datetime
import pymysql


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
    """Return a SQL WHERE fragment that filters by risk_level."""
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


def collect_all_metrics_MariaDB_queries(MariaDB_server, mysql_database, mysql_username, mysql_password, mysql_port, domain_filter=None, risk_filter=None, server_id=None):
    """
    Retrieves metric queries from monitoring.metric_queries table, runs each against MSSQL,
    and stores results in monitoring.general_metric_metadata_results.
    """

    # Create connection strings
    pg_conn_str = get_connection_string()
    #mssql_conn_str = f"mssql+pyodbc://{mssql_username}:{mssql_password}@{mssql_server}/{mssql_database}?driver={mssql_driver}"
    #mysql+pymysql://username:password@host:port/database
    mysql_conn_str = f"mysql+pymysql://{mysql_username}:{mysql_password}@{MariaDB_server}:{mysql_port}/{mysql_database}"


    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_engine = create_engine(pg_conn_str)
        import os as _os
        _qt = int(_os.environ.get("DBEXPERT_QUERY_TIMEOUT", "30"))
        mssql_engine = create_engine(
            mysql_conn_str,
            connect_args={"connect_timeout": 15, "read_timeout": _qt, "write_timeout": _qt})  # login + per-query timeout
        # ========== 2. Retrieve list of queries to run ==========
        domain_clause_sql = _domain_clause(domain_filter)
        with pg_engine.connect() as conn:
            queries_df = pd.read_sql_query(
                f"""
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
        AND lower(cm.db_vendor) in ('mariadb','mysql')
        and rc.vendor_name in ('mariadb','mysql')
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
	  where lower(db_vendor) in ('mysql','mariadb')
	    and is_active = true
	    {_risk_clause(risk_filter, "'medium'")}
	)
""",
                con=conn
            )

        if queries_df.empty:
            db_write_log("✅ No active metric queries found to process.", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
            return 1

        queries_df['calc_query'] = queries_df.apply(
            lambda r: compute_calc_query(r['query'], r.get('step_parameters'), r.get('expected')), axis=1
        )

        # ========== 3. Loop through each query ==========

        server_key = f"{MariaDB_server}"
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

            print(f"🔍 Running metric: {metric_name}")
            db_write_log(f"🔍 Metric '{metric_name}'  Running metric", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
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

                df = pd.read_sql_query(text(metric_query), con=mssql_engine)

                # ========== 5. Convert results to JSON ==========
                metric_metadata_json = df.to_json(orient='records')

                comparison = _build_comparison(metric_metadata_json, query_row.get('expected'), step_params)
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, MariaDB_server, metric_metadata_json, _server_id=server_id)

                # If the metric returned no rows, replace the empty '[]' with
                # a single all-null row showing the column shape — so the
                # stored metric_metadata documents what the query WOULD have
                # returned.
                if df.empty and len(df.columns) > 0:
                    metric_metadata_json = json.dumps([{c: None for c in df.columns.tolist()}])

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
                    _bulk_insert(insert_payloads, pg_engine, MariaDB_server, mysql_port)
                    db_write_log("✅ All metrics inserted successfully (bulk).", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)



                # ========== 8. Send alert if matched + authorised ==========
                comparison_data = json.loads(comparison)
                if comparison_data.get("matched") is True:
                    _risk_level = query_row.get('risk_level') or comparison_data.get('severity') or 'medium'
                    # ===== add to alerts.alert_log =====
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
                            alog.execute(
                                text("""
                                    INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name)
                                    VALUES (:server, :rc, :risk, CAST(:meta AS jsonb), :login_name)
                                """),
                                {
                                    "server": server_key,
                                    "rc": query_row.get('root_cause_id') or metric_name,
                                    "risk": _risk_level,
                                    "meta": json.dumps(metric_metadata_json),
                                    "login_name": next((r.get('login_name') for r in metric_metadata_json if isinstance(r, dict)), None) if isinstance(metric_metadata_json, list) else metric_metadata_json.get('login_name') if isinstance(metric_metadata_json, dict) else None,
                                }
                            )
                    except Exception as alog_ex:
                        db_write_log(f"alert_log insert failed for '{metric_name}': {alog_ex}", 0,
                                     "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
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
                            if diag_row:
                                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, MariaDB_server, metric_metadata_json, _server_id=server_id)
                            else:
                                manage_diagnosys_alerts(metric_name, metric_query, comparison, MariaDB_server, metric_metadata_json, _server_id=server_id)
                    except Exception as auth_ex:
                        db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)

                    if not alert_authorised:
                        db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
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
                            )
                            db_write_log(f"Alert sent for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
                        except Exception as alert_ex:
                            db_write_log(f"Alert failed for '{metric_name}': {alert_ex}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)

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
                                dispatch(siem_rapid_send, _rc_id, _risk_level, server_key, _desc)
                                dispatch(siem_crowdstrike_send, 
                                    event_type=_rc_id,
                                    severity=_risk_level,
                                    server=server_key,
                                    root_cause_id=_rc_id,
                                    description=_desc,
                                )
                    except Exception as siem_ex:
                        db_write_log(f"SIEM alert failed for '{metric_name}': {siem_ex}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)

            except Exception as metric_ex:
                db_write_log(f"❌ Metric '{metric_name}:{metric_query}' failed with error: {metric_ex}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, None, MariaDB_server, [], status="failed", _server_id=server_id)
                continue

        return 1

    except Exception as e:
        db_write_log(f"❌ collect_all_metrics_MariaDB_queries failed with error: {e}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)
        return 0


def _bulk_insert(insert_payloads, pg_engine, MariaDB_server, mysql_port):
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

        db_write_log(f"✅ Bulk insert done for {len(insert_payloads)} metrics.", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)

    except Exception as bulk_ex:
        db_write_log(f"❌ Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_MariaDB_queries", MariaDB_server, port=mysql_port)