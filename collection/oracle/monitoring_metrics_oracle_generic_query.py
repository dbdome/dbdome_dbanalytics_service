#monitoring_metrics_mssql_latency
import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.utils_config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
from alerts.alert_helper import manage_diagnosys_alerts
import json
import re
import oracledb
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


def _build_comparison(metric_metadata_json, expected_raw):
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
    elif expected:
        matched = row_count > 0

    return json.dumps({
        "row_count": row_count,
        "sample_rows": actual_rows[:5],
        "expected": expected,
        "condition": condition,
        "matched": matched,
        "severity": expected.get("severity"),
    })


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


def collect_all_metrics_oracle_queries(username, password, server, port, service_name, domain_filter=None, risk_filter=None, server_id=None):

    # Strip port from server if it contains host:port
    if ':' in str(server):
        server = server.split(':')[0]

    pg_conn_str = get_connection_string()
    pg_engine = create_engine(pg_conn_str, pool_pre_ping=True)
    metadata = MetaData(schema="monitoring")

    try:
        with pg_engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
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
        AND lower(cm.db_vendor) = 'oracle'
        and rc.vendor_name in ('oracle')
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
	  where lower(db_vendor) in ('oracle')
	    and is_active = true
	    {_risk_clause(risk_filter, "'medium'")}
	)
                """),
                con=conn  # type: ignore[arg-type]
            )

        if queries_df.empty:
            db_write_log("No active Oracle metric queries.", 0,
                         "collect_all_metrics_oracle_queries", server, port=port)
            return 1

        
        server_key = f"{server}"
        for _, query_row in queries_df.iterrows():
            oracle_sql = query_row['query']
            category_id = query_row.category_id
            metric_name = query_row.metric_name

            # Substitute :param placeholders with literal values from
            # detection_steps.parameters (step_parameters in the joined view).
            # Without this, oracledb sees the bind variables and raises DPY-4010.
            step_params = query_row.get('step_parameters')
            if step_params:
                if isinstance(step_params, str):
                    try:
                        step_params = json.loads(step_params)
                    except (json.JSONDecodeError, ValueError):
                        step_params = None
                if step_params:
                    oracle_sql = _substitute_parameters(oracle_sql, step_params)

            try:
                oracledb.defaults.disable_oob = True  # type: ignore[attr-defined]
                dsn = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={server})(PORT={int(port or 1521)}))(CONNECT_DATA=(SERVICE_NAME={service_name})))"
                try:
                    ora_conn = oracledb.connect(user=username, password=password, dsn=dsn)
                except Exception:
                    dsn_ssl = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST={server})(PORT={int(port or 1521)}))(CONNECT_DATA=(SERVICE_NAME={service_name}))(SECURITY=(SSL_SERVER_DN_MATCH=no)))"
                    ora_conn = oracledb.connect(user=username, password=password, dsn=dsn_ssl)
                with ora_conn:

                    df = pd.read_sql_query(oracle_sql, ora_conn)  # type: ignore[arg-type]

                    if len(df) > 5000:
                        df = df.head(5000)

                    metric_metadata_json = df.to_json(
                        orient="records",
                        default_handler=str
                    )

                    comparison = _build_comparison(metric_metadata_json, query_row.get('expected'))

                    # If the metric returned no rows, replace the empty '[]'
                    # with a single all-null row showing the column shape.
                    if df.empty and len(df.columns) > 0:
                        metric_metadata_json = json.dumps([{c: None for c in df.columns.tolist()}])

                    insert_payloads = []
                    insert_payloads.append({
                        "server": server_key,
                        "server_id": server_id,
                        "category_id": category_id,
                        "metric_name": metric_name,
                        "metric_config": json.dumps({"query": oracle_sql}),
                        "metric_metadata": metric_metadata_json,
                        "metric_metadata_vs_expected": (
                            (query_row.get('expected') if isinstance(query_row.get('expected'), str)
                             else json.dumps(query_row.get('expected')) if query_row.get('expected') is not None
                             else comparison)
                            if df.empty
                            else comparison
                        ),
                    })
                         # ========== Bulk insert all queued payloads ==========
                    if insert_payloads:
                        _bulk_insert(insert_payloads, pg_engine, server, port)
                        db_write_log("All metrics inserted successfully (bulk).", 0,
                        "collect_all_metrics_oracle_queries", server, port=port)

                    db_write_log(f"Metric '{metric_name}' collected.", 0,
                                 "collect_all_metrics_oracle_queries", server, port=port)

                    # ========== 8. Send alert if matched ==========
                    comparison_data = json.loads(comparison)
                    manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, oracle_sql, comparison, server, metric_metadata_json, _server_id=server_id)
                    if comparison_data.get("matched") is True:
                        _risk_level = query_row.get('risk_level') or comparison_data.get('severity') or 'medium'
                        # ===== add to alerts.alert_log =====
                        try:
                            with pg_engine.begin() as alog:
                                alog.execute(
                                    text("""
                                        INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata)
                                        VALUES (:server, :rc, :risk, CAST(:meta AS jsonb))
                                    """),
                                    {
                                        "server": server_key,
                                        "rc": query_row.get('root_cause_id') or metric_name,
                                        "risk": _risk_level,
                                        "meta": json.dumps(metric_metadata_json),
                                    }
                                )
                        except Exception as alog_ex:
                            db_write_log(f"alert_log insert failed for '{metric_name}': {alog_ex}", 0,
                                         "collect_all_metrics_oracle_queries", server, port=port)
                        # ===== end alerts.alert_log =====
                        alert_authorised = False
                        try:
                            with pg_engine.connect() as pg_check:
                                auth_row = pg_check.execute(
                                    text("""
                                        SELECT w.recurrency_hours FROM config.webook_alerts w
                                        JOIN rootcause.domains d ON d.name = w.metric_type
                                        WHERE d.code = :domain_code
                                          AND w.risk_level = :risk_level
                                          AND w.send_mail_alert IS TRUE
                                        LIMIT 1
                                    """),
                                    {"domain_code": domain_filter or '', "risk_level": _risk_level}
                                ).fetchone()
                                if auth_row is not None:
                                    recurrency = auth_row[0] or '24 hours'
                                    already_sent = pg_check.execute(
                                        text(f"""
                                            SELECT 1 FROM alerts.mail_alert_log
                                            WHERE metric_name = :metric_name
                                              AND server = :server
                                              AND entry_date > NOW() - INTERVAL '{recurrency} hours'
                                            LIMIT 1
                                        """),
                                        {"metric_name": metric_name, "server": server_key}
                                    ).fetchone()
                                    alert_authorised = already_sent is None
                        except Exception as auth_ex:
                            db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_oracle_queries", server, port=port)

                        if not alert_authorised:
                            db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_oracle_queries", server, port=port)
                        else:
                            try:
                                send_mail_alert_no_attachment(
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
                                    query=oracle_sql,
                                    expected=query_row.get('expected'),
                                    comparison_data=comparison_data,
                                    metric_metadata_json=metric_metadata_json,
                                )
                                db_write_log(f"Alert sent for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_oracle_queries", server, port=port)
                            except Exception as alert_ex:
                                db_write_log(f"Alert failed for '{metric_name}': {alert_ex}", 0, "collect_all_metrics_oracle_queries", server, port=port)

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
                                    manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, oracle_sql, comparison, server, metric_metadata_json, _server_id=server_id)
                        except Exception as diag_ex:
                            db_write_log(f"Diagnosis evidence check failed for '{metric_name}': {diag_ex}", 0, "collect_all_metrics_oracle_queries", server, port=port)

            except oracledb.Error as e:
                error, = e.args
                db_write_log(
                    f"ORA-{error.code}: {error.message}",
                    0,
                    "collect_all_metrics_oracle_queries",
                    server,
                    port=port
                )
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, oracle_sql, None, server, [], status="failed", _server_id=server_id)
   
        return 1

    except Exception as e:
        db_write_log(
            f"Collector failed: {e}",
            0,
            "collect_all_metrics_oracle_queries",
            server,
            port=port
        )
        return 0


def _bulk_insert(insert_payloads, pg_engine, server, port):
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

        db_write_log(f"Bulk insert done for {len(insert_payloads)} metrics.", 0, "collect_all_metrics_oracle_queries", server, port=port)

    except Exception as bulk_ex:
        db_write_log(f"Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_oracle_queries", server, port=port)
