from utils.config_dotenv import get_connection_string
from collection.mssql.active_transactions_mssql import collect_metric_active_transactions
from collection.mssql.monitoring_metrics_mssql_tcp_connection import collect_metric_mssql_tcp_connections
from collection.mssql.monitoring_metrics_mssql_transaction_req import collect_metric_mssql_transaction_requests
from collection.mssql.monitoring_metrics_mssql_network_connection_io import collect_metric_mssql_network_connection_io
from collection.mssql.monitoring_metrics_mssql_database_performance import collect_metric_mssql_database_performance
from collection.mssql.monitoring_metrics_mssql_database_unmasked_users import collect_metric_mssql_database_unmasked_users
from collection.mssql.monitoring_metrics_mssql_sql_injection import collect_metric_mssql_sql_injection
from collection.mssql.monitoring_metrics_mssql_server_hardening_unused_inactive_sql_server_logins import collect_metric_mssql_server_hardening_unused_inactive_sql_server_logins
from collection.mssql.monitoring_metrics_mssql_alerts_io import collect_metric_mssql_network_alerts
from collection.mssql.monitoring_metrics_mssql_latency import collect_metric_mssql_latency
from collection.mssql.monitoring_metrics_mssql_active_sessions import collect_metric_mssql_active_sessions
from collection.mssql.monitoring_metrics_mssql_ad_hoc_cpu_cunsuming_queries import collect_metric_mssql_ad_hoc_consuming_queries
from collection.postgres.monitoring_metrics_postgres_missing_indexes import collect_metric_postgres_missing_indexes
from collection.postgres.monitoring_metrics_postgres_stat_activity  import collect_metric_postgres_stat_activity
from collection.postgres.monitoring_metrics_postgres_sensitive_data import collect_metric_postgres_sensitive_data_activity
from collection.oracle.active_transactions_oracle                 import collect_metric_active_transactions_from_oracle
from collection.mssql.monitoring_metrics_mssql_sensitive_data    import collect_metric_mssql_sensitive_data_activity
from collection.mssql.monitoring_metrics_mssql_privileged_logins import collect_metric_mssql_privileged_logins
from collection.postgres.monitoring_metrics_postgres_privileged_logins import collect_metric_postgres_privileged_logins
from collection.mssql.monitoring_metrics_mssql_generic_query     import collect_all_metrics_mssql_queries
from collection.postgres.monitoring_metrics_postgres_generic_query import collect_all_metrics_postgres_queries
from collection.mysql.monitoring_metrics_mysql_generic_query    import   collect_all_metrics_mysql_queries
from collection.oracle.monitoring_metrics_oracle_generic_query import collect_all_metrics_oracle_queries
from collection.mssql.monitoring_metrics_mssql_schema  import collect_metric_mssql_table_schema
from collection.mssql.monitoring_metrics_mssql_event_session import collect_metric_mssql_event_sessions
from collection.MariaDB.monitoring_metrics_MariaDB_generic_query import collect_all_metrics_MariaDB_queries
from collection.informix.monitoring_metrics_informix_generic_query import collect_all_metrics_informix_queries
from collection.clickhouse.monitoring_metrics_clickhouse_generic_query import collect_all_metrics_clickhouse_queries
from collection.mongodb.monitoring_metrics_mongodb_generic_query import collect_all_metrics_mongodb_queries
import psycopg2
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret
from jobs.job_handler  import job_update_next_run_time
from jobs.job_handler  import job_history_write
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

# I/O-bound work — threads parallelize without GIL contention. Override via env.
_COLLECTOR_PARALLELISM = int(os.environ.get('DBEXPERT_COLLECTOR_PARALLELISM', '8'))


def _dispatch_full_row(row):
    """Run the right collector for one v_servers_routines_active row.
    All exceptions caught and logged here so the pool's join sees a clean return."""
    row_id       = row[0]
    server       = row[1]
    servername   = row[2]
    database     = row[3]
    username     = row[4]
    password     = decrypt_secret(row[5])   # monitored-DB password is stored encrypted
    driver       = row[6]
    routine_name = row[8]
    job_id       = row[9]
    duration_secs= row[10]
    next_run_time= row[11]
    port         = row[12]
    oracle_dsn   = row[13]
    auth_type    = row[14]
    service_name = row[15]
    server_label = f"{servername}:{port}" if port else servername

    match routine_name:
        case "active_transactions_mssql":
            try:
                result = collect_metric_active_transactions(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                db_write_log(f"Function succeeded", result ,"collect_metric_active_transactions",server_label)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_active_transactions failed with error:{e}"   , 2 ,"collect_metric_active_transactions" ,server_label)
                return
            result = "default"
        case "tcp_connections_mssql":
            try:
                result = collect_metric_mssql_tcp_connections(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_tcp_connections failed with error:{e}"   , 2 ,"collect_metric_mssql_tcp_connections",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_active_transactions" ,server_label)
            result = "default"
        case "transaction_requests":
            try:
                result = collect_metric_mssql_transaction_requests(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_transaction_requests failed with error:{e}"   , 2 ,"collect_metric_mssql_transaction_requests",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_network_connection_io",server_label)
        case "collect_metric_mssql_network_connection_io":
            try:
                result = collect_metric_mssql_network_connection_io(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_network_connection_io failed with error:{e}"   , 2 ,"collect_metric_mssql_network_connection_io" ,server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_network_connection_io",server_label)
        case "collect_metric_mssql_database_performance":
            try:
                result = collect_metric_mssql_database_performance(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_database_performance failed with error:{e}"   , 2 ,"collect_metric_mssql_database_performance",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_database_performance",server_label)
        case "collect_metric_mssql_database_unmasked_users":
            try:
                result = collect_metric_mssql_database_unmasked_users(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_database_unmasked_users failed with error:{e}"   , 2 ,"collect_metric_mssql_database_unmasked_users",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_database_unmasked_users",server_label)
        case "collect_metric_mssql_sql_injection":
            try:
                result = collect_metric_mssql_sql_injection(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_sql_injection failed with error:{e}"   , 2 ,"collect_metric_mssql_sql_injection" ,server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_sql_injection",server_label)
        case "collect_metric_mssql_server_hardening_unused_inactive_sql_server_logins":
            try:
                result = collect_metric_mssql_server_hardening_unused_inactive_sql_server_logins(server,servername  , database , username , password , driver , auth_type, mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_sql_injection failed with error:{e}"   , 2 ,"collect_metric_mssql_sql_injection" ,server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_sql_injection" ,server_label)
        case "collect_metric_mssql_network_alerts":
            try:
                result = collect_metric_mssql_network_alerts(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_network_alerts failed with error:{e}"   , 2 ,"collect_metric_mssql_network_alerts",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_network_alerts",server_label)
        case "collect_metric_mssql_latency":
            try:
                result = collect_metric_mssql_latency(server,servername  , database , username , password , driver , auth_type)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_network_alerts failed with error:{e}"   , 2 ,"collect_metric_mssql_network_alerts",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_network_alerts" ,server_label)

        case "collect_metric_mssql_active_sessions":
            try:
                result = collect_metric_mssql_active_sessions(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_active_sessions failed with error:{e}"   , 2 ,"collect_metric_mssql_active_sessions",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_active_sessions" ,server_label)

        case "collect_metric_mssql_ad_hoc_consuming_queries":
            try:
                result = collect_metric_mssql_ad_hoc_consuming_queries(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_ad_hoc_consuming_queries failed with error:{e}"   , 2 ,"collect_metric_mssql_ad_hoc_consuming_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_ad_hoc_consuming_queries" ,server_label)
        case "collect_metric_postgres_missing_indexes":
            try:
                result = collect_metric_postgres_missing_indexes(server,servername  , port,database , username , password , driver )
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_ad_hoc_consuming_queries failed with error:{e}"   , 2 ,"collect_metric_mssql_ad_hoc_consuming_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_ad_hoc_consuming_queries" ,server_label)
        case "collect_metric_postgres_stat_activity":
            try:
                result = collect_metric_postgres_stat_activity(server,servername  , port,database , username , password , driver )
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_postgres_stat_activity failed with error:{e}"   , 2 ,"collect_metric_postgres_stat_activity",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_postgres_stat_activity" ,server_label)

        case "collect_metric_postgres_sensitive_data_activity":
            try:
                result = collect_metric_postgres_sensitive_data_activity(server,servername  , port,database , username , password , driver)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_postgres_stat_activity failed with error:{e}"   , 2 ,"collect_metric_postgres_stat_activity",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_postgres_stat_activity" ,server_label)
        case "collect_metric_active_transactions_from_oracle":
            try:
                result = collect_metric_active_transactions_from_oracle()
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_active_transactions_from_oracle failed with error:{e}"   , 2 ,"collect_metric_active_transactions_from_oracle",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_active_transactions_from_oracle" ,server_label)
            result = "default"

        case "collect_metric_mssql_sensitive_data_activity":
            try:
                result = collect_metric_mssql_sensitive_data_activity(server,servername  , port,database , username , password , driver , auth_type)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_active_transactions_from_oracle failed with error:{e}"   , 2 ,"collect_metric_active_transactions_from_oracle",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_active_transactions_from_oracle" ,server_label)
            result = "default"

        case "collect_metric_mssql_privileged_logins":
            try:
                result = collect_metric_mssql_privileged_logins(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_mssql_privileged_logins failed with error:{e}"   , 2 ,"collect_metric_mssql_privileged_logins",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_mssql_privileged_logins" ,server_label)
            result = "default"
        case "collect_metric_postgres_privileged_logins":
            try:
                result = collect_metric_postgres_privileged_logins(server,servername  ,port, database , username , password , driver)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_postgres_privileged_logins failed with error:{e}"   , 2 ,"collect_metric_postgres_privileged_logins",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_postgres_privileged_logins" ,server_label)
            result = "default"
        case "collect_all_metrics_mssql_queries":
            try:
                result = collect_all_metrics_mssql_queries(server, database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_metric_postgres_privileged_logins failed with error:{e}"   , 2 ,"collect_metric_postgres_privileged_logins",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_metric_postgres_privileged_logins" ,server_label)

        case "collect_all_metrics_postgres_queries":
            try:
                result = collect_all_metrics_postgres_queries(server,port, database , username , password )
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_postgres_queries failed with error:{e}"   , 2 ,"collect_all_metrics_postgres_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_postgres_queries" ,server_label)

        case "collect_all_metrics_oracle_queries":
            try:
                result = collect_all_metrics_oracle_queries (username , password  , server , port , service_name)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_oracle_queries failed with error:{e}"   , 2 ,"collect_all_metrics_oracle_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_oracle_queries" ,server_label)


        case "collect_all_metrics_mysql_queries":
            try:
                result = collect_all_metrics_mysql_queries(server,database , username , password  , port )
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_mysql_queries failed with error:{e}"   , 2 ,"collect_all_metrics_mysql_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_mysql_queries" ,server_label)

            result = "default"
        case "collect_all_metrics_MariaDB_queries":
            try:
                result = collect_all_metrics_MariaDB_queries(server,database , username , password  , port )
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_mysql_queries failed with error:{e}"   , 2 ,"collect_all_metrics_mysql_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_mysql_queries" ,server_label)

            result = "default"
        case "collect_all_metrics_informix_queries":
            try:
                result = collect_all_metrics_informix_queries(server, database, username, password, port)
                job_update_next_run_time(job_id, duration_secs, next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_informix_queries failed with error:{e}", 2, "collect_all_metrics_informix_queries", server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result, "collect_all_metrics_informix_queries", server_label)
            result = "default"
        case "collect_all_metrics_clickhouse_queries":
            try:
                result = collect_all_metrics_clickhouse_queries(server, database, username, password, port)
                job_update_next_run_time(job_id, duration_secs, next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_clickhouse_queries failed with error:{e}", 2, "collect_all_metrics_clickhouse_queries", server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result, "collect_all_metrics_clickhouse_queries", server_label)
            result = "default"
        case "collect_all_metrics_mongodb_queries":
            try:
                # service_name carries the Mongo authSource (usually 'admin')
                result = collect_all_metrics_mongodb_queries(server, database, username, password, port, service_name=service_name)
                job_update_next_run_time(job_id, duration_secs, next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_mongodb_queries failed with error:{e}", 2, "collect_all_metrics_mongodb_queries", server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result, "collect_all_metrics_mongodb_queries", server_label)
            result = "default"
        case "collect_metric_mssql_active_schema":
            try:
                result = collect_metric_mssql_table_schema(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_mysql_queries failed with error:{e}"   , 2 ,"collect_all_metrics_mysql_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_mysql_queries" ,server_label)

            result = "default"
        case "collect_metric_mssql_event_sessions":
            try:
                result = collect_metric_mssql_event_sessions(server,servername  , database , username , password , driver,auth_type,mssql_port=port)
                job_update_next_run_time(job_id , duration_secs , next_run_time)
                job_history_write(job_id)
            except Exception as e:
                db_write_log(f"collect_all_metrics_mysql_queries failed with error:{e}"   , 2 ,"collect_all_metrics_mysql_queries",server_label)
                return
            finally:
                db_write_log(f"Function succeeded", result ,"collect_all_metrics_mysql_queries" ,server_label)

            result = "default"


def collect_metrics_operation():
    pg_connection_string = get_connection_string()
    conn = psycopg2.connect(pg_connection_string)
    try:
        cur = conn.cursor()
        cur.execute("select * from metrics.v_servers_routines_active")
        rows = cur.fetchall()
        cur.close()
    finally:
        conn.close()

    if not rows:
        return

    workers = min(_COLLECTOR_PARALLELISM, len(rows))
    with ThreadPoolExecutor(max_workers=workers, thread_name_prefix='collect') as pool:
        futures = [pool.submit(_dispatch_full_row, r) for r in rows]
        for f in as_completed(futures):
            f.result()


# ═══════════════════════════════════════════════════════════════
# Domain-split operations
# ═══════════════════════════════════════════════════════════════
# These run the same generic collectors but filtered by domain prefix:
#   SEC-*   = Security
#   PERF-*  = Performance
#   HLTH-*  = Health
#   OTHER   = Legacy/custom metrics without domain prefix
# ═══════════════════════════════════════════════════════════════

def _dispatch_domain_row(row, domain_filter, risk_filter=None, rc_filter=None, skip_unchanged=False):
    """Run the right generic collector for one row, scoped to a domain and/or risk_level.
    All exceptions caught and logged here so the pool's join sees a clean return.

    rc_filter scopes the run to specific root causes (the dedicated fast collector).
    Only the mssql collector implements it today: the other vendors filter their
    metric set differently, and passing rc_filter to one that IGNORES it would run
    a FULL sweep at the dedicated collector's cadence - so they are skipped
    explicitly rather than silently mis-collected."""
    row_id       = row[0]
    server       = row[1]
    servername   = row[2]
    database     = row[3]
    username     = row[4]
    password     = decrypt_secret(row[5])   # monitored-DB password is stored encrypted
    driver       = row[6]
    routine_name = row[8]
    job_id       = row[9]
    duration_secs= row[10]
    next_run_time= row[11]
    port         = row[12]
    oracle_dsn   = row[13]
    auth_type    = row[14]
    service_name = row[15]
    server_id    = row[16]
    server_label = f"{servername}:{port}" if port else servername

    scope_label = domain_filter or risk_filter or 'ALL'
    if rc_filter:
        scope_label = rc_filter if isinstance(rc_filter, str) else ','.join(rc_filter)
    op_name = f"{routine_name}_{scope_label}"

    # rc_filter is only honoured by the mssql collector (see docstring). Skipping
    # is the safe failure: the root cause keeps being collected by the normal
    # sweep on those vendors, just at the slower cadence.
    if rc_filter and routine_name != "collect_all_metrics_mssql_queries":
        db_write_log(f"rc_filter '{scope_label}' not supported by {routine_name} - skipped "
                     f"(vendor still collected by the generic sweep)",
                     0, "_dispatch_domain_row", server_label)
        return

    try:
        match routine_name:
            case "collect_all_metrics_mssql_queries":
                result = collect_all_metrics_mssql_queries(
                    server, database, username, password, driver, auth_type,
                    mssql_port=port, domain_filter=domain_filter,
                    risk_filter=risk_filter, server_id=server_id,
                    rc_filter=rc_filter, skip_unchanged=skip_unchanged)

            case "collect_all_metrics_postgres_queries":
                result = collect_all_metrics_postgres_queries(
                    server, port, database, username, password,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_dbanalytics_queries":
                # DBDOME self-monitoring: target is the dbanalytics catalog DB
                # itself (PostgreSQL on port 5444). Reuses the postgres collector
                # but narrows the vendor filter to the 'dbanalytics' vendor so
                # only self-monitoring rootcauses are picked up.
                result = collect_all_metrics_postgres_queries(
                    server, port, database, username, password,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    vendor_slug='dbanalytics', server_id=server_id)

            case "collect_all_metrics_oracle_queries":
                result = collect_all_metrics_oracle_queries(
                    username, password, server, port, service_name,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_mysql_queries":
                result = collect_all_metrics_mysql_queries(
                    server, database, username, password, port,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_MariaDB_queries":
                result = collect_all_metrics_MariaDB_queries(
                    server, database, username, password, port,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_informix_queries":
                result = collect_all_metrics_informix_queries(
                    server, database, username, password, port,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_clickhouse_queries":
                result = collect_all_metrics_clickhouse_queries(
                    server, database, username, password, port,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case "collect_all_metrics_mongodb_queries":
                # service_name carries the Mongo authSource (usually 'admin')
                result = collect_all_metrics_mongodb_queries(
                    server, database, username, password, port,
                    service_name=service_name,
                    domain_filter=domain_filter, risk_filter=risk_filter,
                    server_id=server_id)

            case _:
                # Specialized collectors handled by collect_metrics_operation.
                return

        job_update_next_run_time(job_id, duration_secs, next_run_time)
        job_history_write(job_id)
        db_write_log(f"[{scope_label}] {routine_name} succeeded",
                     0, op_name, server_label)

    except Exception as e:
        db_write_log(f"[{scope_label}] {routine_name} failed: {e}",
                     2, op_name, server_label)


def _run_domain_collection(domain_filter, risk_filter=None, rc_filter=None, skip_unchanged=False):
    """
    Run generic query collectors for all active servers, filtered by domain
    and/or risk_level.

    domain_filter: 'SEC', 'PERF', 'HLTH', 'OTHER', or None (all domains)
    risk_filter:   'low', 'medium', 'high', 'critical', or None (all risks)
    rc_filter:     root_cause_id (or list) to run EXCLUSIVELY - the dedicated
                   collector path; None runs the normal sweep
    skip_unchanged: store a sample only when it differs from the previous one
    """
    pg_connection_string = get_connection_string()
    conn = psycopg2.connect(pg_connection_string)
    try:
        cur = conn.cursor()
        cur.execute("select * from metrics.v_servers_routines_active")
        rows = cur.fetchall()
        cur.close()
    finally:
        conn.close()

    if not rows:
        return

    workers = min(_COLLECTOR_PARALLELISM, len(rows))
    with ThreadPoolExecutor(max_workers=workers, thread_name_prefix='collect') as pool:
        futures = [pool.submit(_dispatch_domain_row, r, domain_filter, risk_filter,
                               rc_filter, skip_unchanged) for r in rows]
        for f in as_completed(futures):
            f.result()


# Root causes with their own tight-cadence collector. Keep in step with
# config.global_params('dedicated_collector_rcs'), which is what the generic
# sweep reads to EXCLUDE them - if the two disagree, the RC is either collected
# twice per cycle or not at all.
ACTIVE_TX_RC = 'SEC-SQL-ACC-011-RC02'


def collect_metrics_operation_active_tx():
    """Dedicated fast collector for SEC-SQL-ACC-011-RC02 (active transactions).

    WHY THIS EXISTS. The query itself costs 0.38s (measured against a live SQL
    Server), but inside the generic SEC sweep it queues behind ~1,695 metrics and
    only gets a turn every 5.5-14 minutes. Both branches of the query look back
    just 60 SECONDS (`DATEADD(SECOND, -60, GETDATE())`), so at that spacing it
    observes its own window ~7-18% of the time and misses over 80% of the
    transactions and statements it exists to catch. Cadence must stay <= 60s.

    Reuses the normal path in full - same per-server thread pool, same insert,
    comparison and alert handling - scoped to one root cause. Volume is held down
    by skip_unchanged: at 30s this metric would otherwise write ~2.3M rows/day
    per server.
    """
    db_write_log(f"Starting dedicated collection for {ACTIVE_TX_RC}", 0,
                 "collect_metrics_operation_active_tx", "")
    _run_domain_collection(None, rc_filter=ACTIVE_TX_RC, skip_unchanged=True)
    db_write_log(f"Dedicated collection for {ACTIVE_TX_RC} complete", 0,
                 "collect_metrics_operation_active_tx", "")


def collect_metrics_operation_sec():
    """Collect Security domain metrics (SEC-*) for all active servers."""
    db_write_log("Starting SEC domain collection", 0, "collect_metrics_operation_sec", "")
    _run_domain_collection('SEC')
    db_write_log("SEC domain collection complete", 0, "collect_metrics_operation_sec", "")


def collect_metrics_operation_perf():
    """Collect Performance domain metrics (PERF-*) for all active servers."""
    db_write_log("Starting PERF domain collection", 0, "collect_metrics_operation_perf", "")
    _run_domain_collection('PERF')
    db_write_log("PERF domain collection complete", 0, "collect_metrics_operation_perf", "")


def collect_metrics_operation_hlth():
    """Collect Health domain metrics (HLTH-*) for all active servers."""
    db_write_log("Starting HLTH domain collection", 0, "collect_metrics_operation_hlth", "")
    _run_domain_collection('HLTH')
    db_write_log("HLTH domain collection complete", 0, "collect_metrics_operation_hlth", "")


def collect_metrics_operation_other():
    """Collect non-domain metrics (legacy/custom) for all active servers."""
    db_write_log("Starting OTHER collection", 0, "collect_metrics_operation_other", "")
    _run_domain_collection('OTHER')
    db_write_log("OTHER collection complete", 0, "collect_metrics_operation_other", "")


def collect_metrics_operation_critical():
    """Collect only critical-risk metrics (across all domains) for all active servers."""
    db_write_log("Starting CRITICAL risk collection", 0, "collect_metrics_operation_critical", "")
    _run_domain_collection(domain_filter=None, risk_filter='critical')
    db_write_log("CRITICAL risk collection complete", 0, "collect_metrics_operation_critical", "")
