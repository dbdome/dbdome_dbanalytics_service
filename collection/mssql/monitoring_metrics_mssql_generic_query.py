import pandas as pd
import re
from sqlalchemy import create_engine, text, event
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email_utils.smtp_email_sender import send_mail_alert_no_attachment
import json
from datetime import datetime
import pyodbc
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse
import psycopg2
from purgers.purge_metric_metadata import purge_general_metric_metadata_per_root_cause

from alerts.alert_helper import manage_alerts, manage_diagnosys_alerts

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


def _escape_sqlalchemy_params(sql):
    r"""
    Escape remaining :param-like patterns that SQLAlchemy text() would
    interpret as bound parameters.  Uses \: (literal colon) escape.
    Handles patterns like LIKE '2:%:1' where :1 looks like a parameter.
    """
    return re.sub(r'(?<!\w):(?=[a-zA-Z0-9_])', r'\\:', sql)


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


def _build_comparison(metric_metadata_json, expected_raw):
    """
    Build a metric_metadata_vs_expected JSON comparing actual results to expected.
    Returns a JSON string with actual row_count, expected condition, and matched flag.
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
    matched = None

    # Evaluate condition
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

def collect_all_metrics_mssql_queries(mssql_server, mssql_database, mssql_username, mssql_password, mssql_driver, auth_type, mssql_port=None, domain_filter=None, risk_filter=None, server_id=None):
    """
    Retrieves metric queries from monitoring.metric_queries table, runs each against MSSQL,
    and stores results in monitoring.general_metric_metadata_results.

    domain_filter: None = all metrics, or one of 'SEC', 'PERF', 'HLTH', 'OTHER'
    risk_filter:   None = all risk levels, or one of 'low','medium','high','critical'
    """
    
    
    installed_drivers = pyodbc.drivers()
    print("Installed drivers:", installed_drivers)

    # Define priority list
    priority = ["ODBC Driver 18 for SQL Server",
            "ODBC Driver 17 for SQL Server",
            "SQL Server"]

    # Select the first available driver by priority
    selected_driver = next((d for d in priority if d in installed_drivers), None)

    if selected_driver is None:
        raise RuntimeError("No suitable ODBC driver found!")

    print("Selected driver:", selected_driver)


    driver =selected_driver

    # Create connection strings
    pg_conn_str = get_connection_string()
    #mssql_conn_str = f"mssql+pyodbc://{mssql_username}:{mssql_password}@{mssql_server}/{mssql_database}?driver={mssql_driver}"

    server_with_port = f"{mssql_server},{mssql_port}" if mssql_port else mssql_server
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={mssql_database};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={mssql_database};
            UID={mssql_username};
            PWD={mssql_password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    params = quote_plus(odbc_str)

    # Create the connection string
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)


    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_engine = create_engine(pg_conn_str, echo=True)
        mssql_engine = create_engine(connection_string, echo=True)
        _register_mssql_output_converters(mssql_engine)

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
        AND lower(cm.db_vendor) IN ('mssql', 'sqlserver')
        and rc.vendor_name in ('mssql', 'sqlserver')
        AND rl.is_active IS TRUE
        {domain_clause}
        {risk_clause_main}

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
	  where lower(db_vendor) in ('mssql', 'sqlserver')
	    and is_active = true
	    {risk_clause_legacy}
	)
 

	
                """,
                con=conn
            )

        #server_key = f"{mssql_server}:{mssql_port}" if mssql_port else mssql_server
        server_key = f"{mssql_server}" if mssql_port else mssql_server

        if queries_df.empty:
            db_write_log("✅ No active metric queries found to process.", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
            return 1

        # ========== 3. Collect all results first ==========
        insert_payloads = []
        alert_queue = []
        current_issue_id = None


        for _, query_row in queries_df.iterrows():
            metric_query = query_row['query']
            category_id = query_row['category_id']
            metric_name = query_row['metric_name']
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
                # Substitute :param placeholders with literal values from detection_steps.parameters
                step_params = query_row.get('step_parameters')
                if step_params:
                    if isinstance(step_params, str):
                        try:
                            step_params = json.loads(step_params)
                        except (json.JSONDecodeError, ValueError):
                            step_params = None
                    if step_params:
                        metric_query = _substitute_parameters(metric_query, step_params)

                # Escape any remaining :param-like patterns to prevent SQLAlchemy
                # from treating them as bound parameters (e.g. LIKE '2:%:1')
                metric_query = _escape_sqlalchemy_params(metric_query)

                df = pd.read_sql_query(text(metric_query), con=mssql_engine)
                # Fix Windows-1252 chars (e.g. 0x96 en-dash) that break UTF-8 encoding
                for col in df.select_dtypes(include=['object']).columns:
                    df[col] = df[col].apply(lambda v: v.encode('utf-8', errors='replace').decode('utf-8') if isinstance(v, str) else v)
                metric_metadata_json = _sanitize_json(df.to_json(orient='records'))
                comparison = _sanitize_json(_build_comparison(metric_metadata_json, query_row.get('expected')))

                # If the metric returned no rows, replace the empty '[]' with
                # a single all-null row showing the column shape.
                if df.empty and len(df.columns) > 0:
                    metric_metadata_json = _sanitize_json(json.dumps([{c: None for c in df.columns.tolist()}]))

                insert_payloads.append({
                    "server_id": server_id ,
                    "server": server_key ,
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
                _bulk_insert(insert_payloads, pg_engine, mssql_server, mssql_port)
                purge_general_metric_metadata_per_root_cause(metric_name)
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
                                 "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
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
                        {"domain_code": domain_filter or 'SEC', "risk_level": _risk_level}
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
                    db_write_log(f"Alert auth check failed for '{metric_name}': {auth_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                    #manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, mssql_server, metric_metadata_json, status="failed", _server_id=server_id)

                if not alert_authorised:
                    db_write_log(f"Alert skipped for '{metric_name}' - not authorised (domain={domain_filter}, risk={_risk_level})", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                    continue

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
                    db_write_log(f"Alert sent for '{metric_name}' (matched, authorised)", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                except Exception as alert_ex:
                    db_write_log(f"❌ Alert failed for '{metric_name}': {alert_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
                    #manage_diagnosys_alerts(query_row.get('root_cause_id') or metric_name, metric_query, comparison, mssql_server, metric_metadata_json, status="failed", _server_id=server_id)

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
           
        db_write_log(f"✅ Bulk insert done for {len(insert_payloads)} metrics.", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)

    except Exception as bulk_ex:
        db_write_log(f"❌ Bulk insert failed: {bulk_ex}", 0, "collect_all_metrics_mssql_queries", mssql_server, port=mssql_port)
    
