#monitoring_metrics_mssql_latency
import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
try:
    from analysis.self_activity_filter import filter_excluded_logins as _dbdome_filter_excluded_logins
except Exception:
    def _dbdome_filter_excluded_logins(df, *a, **k):
        return df
import pyodbc
from collection.mssql.mssql_driver_util  import get_installed_driver_by_priority
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

def collect_metric_mssql_event_sessions(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
    server = mssql_server
    servername = mssql_servername
    database = mssql_database
    username = mssql_username
    password = mssql_password

    
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
    server_with_port = f"{servername},{mssql_port}" if mssql_port else servername
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={database or 'master'};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={database or 'master'};
            UID={username};
            PWD={password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    params = quote_plus(odbc_str)

    # Create the connection string
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)

    #postgresql connection
    pg_connection_string = get_connection_string()
   
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    sql_server_engine = create_engine(connection_string )
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = sql_server_engine.raw_connection()    
    p_sql_cmd = f"""              
                       SELECT 1 [DBDOME_Audit_RPC_Login_exists]
                    FROM sys.server_event_sessions
                    WHERE name = 'DBDOME_Audit_RPC_Login';
                """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            if df.empty:
                create_event(raw_conn) 
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if df.empty:
                  return 0;
            p_sql_cmd = f"""              
                SELECT
                    event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
                    event_data.value('(event/@timestamp)[1]', 'datetime2') AS event_time,
                    event_data.value('(event/action[@name="username"]/value)[1]', 'sysname') AS username,
                    event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(128)') AS host,
                    event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(128)') AS app,
                    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text
                    FROM sys.fn_xe_file_target_read_file(
                    'C:\\DBDOME\\XE\\dbdome_audit*.xel',
                    NULL, NULL, NULL
                ) AS x
                    CROSS APPLY (SELECT CAST(x.event_data AS XML)) t(event_data);
                """            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            df = _dbdome_filter_excluded_logins(df, login_cols=("username",))
            with postgres_engine.begin() as conn:                                                                  
                conn.execute(
                text("INSERT INTO monitoring.DBDOME_Audit_RPC_Login (\
                      server	, 	event_name , event_time,username,host,app,	sql_text)\
                      VALUES (:server , :event_name ,:event_time,:username,:host,:app,	:sql_text)"),
                        [{
                      "server":server,
                      "event_name":row[0],
                      "event_time":row[1],
                      "username":row[2],
                      "host":row[3],
                      "app":row[4],
                      "sql_text":row[5]
                       } for row in df.itertuples(index=False)]
)
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_event_sessions failed with error:{e}"   ,0,"collect_metric_mssql_event_sessions" , servername, port=mssql_port)
    finally:
            db_write_log(f"✅ collect_metric_mssql_event_sessions Data sync complete."   ,0,"collect_metric_mssql_event_sessions" , servername, port=mssql_port)
            raw_conn.close()
    return  1
    return 0;

def create_event(raw_conn):
        try:
            with raw_conn.begin() as conn:                                                                  
                conn.execute(
                text("CREATE EVENT SESSION [DBDOME_Audit_RPC_Login]\
ON SERVER\
ADD EVENT sqlserver.rpc_completed\
(\
    ACTION (\
        sqlserver.client_app_name,\
        sqlserver.client_hostname,\
        sqlserver.database_name,\
        sqlserver.username,\
        sqlserver.session_id,\
        sqlserver.sql_text\
    )\
),\
ADD EVENT sqlserver.login\
(\
    ACTION (\
        sqlserver.client_app_name,\
        sqlserver.client_hostname,\
        sqlserver.username,\
        sqlserver.session_id\
    )\
),\
ADD EVENT sqlserver.login_failed\
(\
    ACTION (\
        sqlserver.client_app_name,\
        sqlserver.client_hostname,\
        sqlserver.username\
    )\
)\
ADD TARGET package0.event_file\
(\
    SET filename = N'C:\\DBDOME\\XE\\dbdome_audit.xel',\
        max_file_size = 50,\
        max_rollover_files = 5\
);"))
            conn.execute(
            text("ALTER EVENT SESSION [DBDOME_Audit_RPC_Login]\
                    ON SERVER\
                    STATE = START"))
        except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_create_event_session failed with error:{e}"   ,0,"collect_metric_mssql_create_event_session" , None )
        finally:
            db_write_log(f"✅ collect_metric_mssql_create_event_session Data sync complete."   ,0,"collect_metric_mssql_create_event_session" , None )
            raw_conn.close()
        return  1
    
          