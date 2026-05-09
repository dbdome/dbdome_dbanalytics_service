import pandas as pd
import re
from sqlalchemy import create_engine, text
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
from alerts.alert_helper import manage_diagnosys_alerts
import json
from datetime import datetime


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

def _risk_clause(risk_filter, col_expr="ds.expected->>'severity'"):
    """Return a SQL WHERE fragment that filters by risk_level.

    Informix collector reads risk_level from the detection_steps.expected
    JSON, so the default expression points there.
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


def _sanitize_json(text):
    """Remove null bytes from JSON strings. PostgreSQL cannot store \\u0000."""
    if text is None:
        return text
    return text.replace('\x00', '').replace('\\u0000', '')


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


def collect_all_metrics_informix_queries(informix_server, informix_database, informix_username, informix_password, informix_port, domain_filter=None, risk_filter=None, server_id=None):
    """
    Retrieves metric queries from monitoring.metric_queries table, runs each against Informix,
    and stores results in monitoring.general_metric_metadata_results.

    Requires: pip install IfxPy  (or IfxPyDbi for DB-API 2.0)
    Connection uses the Informix ODBC/JDBC driver via SQLAlchemy + ibm_db_sa or ifx_db.
    Alternatively uses jaydebeapi or pyodbc with Informix ODBC driver.
    """

    # Create connection strings
    pg_conn_str = get_connection_string()

    # Strip port from server if it contains host:port
    if ':' in str(informix_server):
        informix_server = informix_server.split(':')[0]

    # Informix connection via pyodbc + Informix ODBC driver
    informix_conn_str = (
        f"informix+pyodbc://{informix_username}:{informix_password}"
        f"@{informix_server}:{informix_port}/{informix_database}"
        f"?driver=IBM+INFORMIX+ODBC+DRIVER"
    )

    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_engine = create_engine(pg_conn_str, echo=True)
        informix_engine = create_engine(informix_conn_str, echo=True)

        # ========== 2. Retrieve list of queries to run ==========
        with pg_engine.connect() as conn:
            queries_df = pd.read_sql_query(
                f"""SELECT cm.query, cm.category_id, cm.metric_name, ds.expected,
                          ds.parameters AS step_parameters,
                          d.name AS domain_name,
                          a.name AS area_name,
                          i.name AS issue_name,
                          coalesce(i.issue_id, cm.metric_name) AS issue_id,
                          rc.root_cause_id,
                          rc.name AS root_cause_name,
                          rc.description AS root_cause_desc,
                          dp.name AS detection_name,
                          dp.description AS detection_desc,
                          ds.name AS step_name,
                          ds.expected->>'severity' AS risk_level
                   FROM metrics.v_custom_metrics cm
                   LEFT JOIN rootcause.detection_paths dp ON dp.root_cause_id = cm.metric_name AND dp.is_active = true
                   LEFT JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id AND dps.sequence = 1
                   LEFT JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
                   LEFT JOIN rootcause.root_causes rc
                        ON rc.root_cause_id = cm.metric_name
                   LEFT JOIN rootcause.issues i
                        ON i.issue_id = rc.issue_id
                   LEFT JOIN rootcause.domains d
                        ON d.code = i.domain_code
                   LEFT JOIN rootcause.areas a
                        ON a.code = i.area_code AND a.database_type_code = i.database_type_code
                   WHERE cm.is_active = true AND (dp.is_active = true OR dp.is_active IS NULL)
                     AND lower(cm.db_vendor) = 'informix'
                     {_domain_clause(domain_filter)}
                     {_risk_clause(risk_filter)}
                   ORDER BY rc.issue_id, rc.root_cause_id
                """,
                con=conn
            )

        server_key = f"{informix_server}" if informix_port else informix_server

        if queries_df.empty:
            db_write_log("✅ No active metric queries found to process.", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
            return 1

        # ========== 3. Collect all results ==========
        insert_payloads = []
        alert_queue = []
        current_issue_id = None

        for _, query_row in queries_df.iterrows():
            metric_query = query_row['query']
            category_id = query_row['category_id']
            metric_name = query_row['metric_name']
            issue_id = query_row['issue_id']

            print(f"🔍 Running metric: {metric_name}")

            # Flush when issue_id changes
            if current_issue_id is not None and issue_id != current_issue_id:
                _bulk_insert(insert_payloads, pg_engine, informix_server, informix_port)
                insert_payloads = []
            current_issue_id = issue_id

            try:
                # Substitute parameters
                step_params = query_row.get('step_parameters')
                if step_params:
                    if isinstance(step_params, str):
                        try:
                            step_params = json.loads(step_params)
                        except (json.JSONDecodeError, ValueError):
                            step_params = None
                    if step_params:
                        metric_query = _substitute_parameters(metric_query, step_params)

                df = pd.read_sql_query(text(metric_query), con=informix_engine)
                metric_metadata_json = _sanitize_json(df.to_json(orient='records'))
                comparison = _sanitize_json(_build_comparison(metric_metadata_json, query_row.get('expected')))

                # If the metric returned no rows, replace the empty '[]' with
                # a single all-null row showing the column shape.
                if df.empty and len(df.columns) > 0:
                    metric_metadata_json = _sanitize_json(json.dumps([{c: None for c in df.columns.tolist()}]))

                insert_payloads.append({
                    "server": server_key,
                    "server_id":server_id,
                    "category_id": category_id,
                    "metric_name": metric_name,
                    "metric_config": _sanitize_json(json.dumps({"query": metric_query})),
                    "metric_metadata": metric_metadata_json,
                    "metric_metadata_vs_expected": (
                        (query_row.get('expected') if isinstance(query_row.get('expected'), str)
                         else json.dumps(query_row.get('expected')) if query_row.get('expected') is not None
                         else comparison)
                        if df.empty
                        else comparison
                    )
                })

                # Queue alerts
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, informix_server, metric_metadata_json, _server_id=server_id)
                comparison_data = json.loads(comparison)
                if comparison_data.get("matched") is False:
                    alert_queue.append((metric_name, metric_query, query_row, comparison_data))

                print(f"✅ Metric '{metric_name}' collected.")

            except Exception as metric_ex:
                db_write_log(f"❌ Metric '{metric_name}' failed with error: {metric_ex}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
                manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, None, informix_server, [], status="failed", _server_id=server_id)
                continue

        # ========== 4. Bulk insert remaining ==========
        if insert_payloads:
            _bulk_insert(insert_payloads, pg_engine, informix_server, informix_port)
            db_write_log("✅ All metrics inserted successfully (bulk).", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)

        # ========== 5. Send queued alerts (if authorised) ==========
        for metric_name, metric_query, query_row, comparison_data in alert_queue:
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
                             "collect_all_metrics_informix_queries", informix_server, port=informix_port)
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
                db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)

            if not alert_authorised:
                db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
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
                        query=metric_query,
                        expected=query_row.get('expected'),
                        comparison_data=comparison_data,
                        metric_metadata_json=metric_metadata_json,
                    )
                    db_write_log(f"Alert sent for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
                except Exception as alert_ex:
                    db_write_log(f"❌ Alert failed for '{metric_name}': {alert_ex}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)

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
                        manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, informix_server, metric_metadata_json, _server_id=server_id)
            except Exception as diag_ex:
                db_write_log(f"Diagnosis evidence check failed for '{metric_name}': {diag_ex}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)

        return 1

    except Exception as e:
        db_write_log(f"❌ collect_all_metrics_informix_queries failed with error: {e}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
    return 0


def _bulk_insert(insert_payloads, pg_engine, informix_server, informix_port):
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

        db_write_log(f"✅ Bulk insert done for {len(insert_payloads)} metrics.", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)

    except Exception as bulk_ex:
        db_write_log(f"❌ Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_informix_queries", informix_server, port=informix_port)
