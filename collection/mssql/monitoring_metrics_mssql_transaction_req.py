#monitoring_metrics_mssql_transaction_requests

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
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

def collect_metric_mssql_transaction_requests(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
    server = mssql_server
    servername = mssql_servername
    database = mssql_database
    if not database:
           database = "master"
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
    # Create the connection string

    #connection_string = f"mssql+pyodbc://{username}:{password}@{server}/{database}?driver={driver}"

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
        SELECT '{servername}' server,
        r.start_time,
        r.command,
        s.last_request_end_time,
            r.session_id,
            r.status,
            r.blocking_session_id,
            r.wait_type,
            r.wait_time,
            r.cpu_time,
            r.total_elapsed_time,
            r.reads,
            r.writes,
            r.logical_reads,
            s.login_name,
            s.host_name,
            s.program_name,
        s.is_user_process,
            t.text AS sql_text,
        r.connection_id , 
        DB_NAME(r.database_id) database_name
        FROM 
            sys.dm_exec_requests r
        JOIN 
            sys.dm_exec_sessions s ON r.session_id = s.session_id
        CROSS APPLY 
            sys.dm_exec_sql_text(r.sql_handle) t"""            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            df = _dbdome_filter_excluded_logins(df)
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                        text("INSERT INTO monitoring.transaction_requests (server ,start_time ,command ,last_request_end_time,session_id ,\
        status ,\
        blocking_session_id ,\
        wait_type ,\
        wait_time ,\
        cpu_time,\
        total_elapsed_time,\
        reads ,\
        writes,\
        logical_reads,\
        login_name  ,\
        host_name	,\
        program_name,\
        is_user_process ,\
        sql_text ,\
        connection_id , \
        database_name  ) VALUES \
        (:server ,\
        :start_time ,\
        :command ,\
        :last_request_end_time,\
        :session_id ,\
        :status ,\
        :blocking_session_id ,\
        :wait_type ,\
        :wait_time ,\
        :cpu_time,\
        :total_elapsed_time,\
        :reads ,\
        :writes,\
        :logical_reads,\
        :login_name  ,\
        :host_name	,\
        :program_name,\
        :is_user_process ,\
        :sql_text ,\
        :connection_id , \
        :database_name  )"),
        [{"server" :row[0],
        "start_time":row[1] ,
        "command":row[2] ,
        "last_request_end_time":row[3],
        "session_id" :row[4],
        "status" :row[5],
        "blocking_session_id" :row[6],
        "wait_type" :row[7],
        "wait_time" :row[8],
        "cpu_time":row[9],
        "total_elapsed_time":row[10],
        "reads" :row[11],
        "writes":row[12],
        "logical_reads":row[13],
        "login_name"  :row[14],
        "host_name"	:row[15],
        "program_name":row[16],
        "is_user_process" :row[17],
        "sql_text" :row[18],
        "connection_id" :row[19],
        "database_name"  :row[20],} for row in df.itertuples(index=False)])        
    except Exception as e:                 
                    print(df.head() )
                    print(len(df.columns)) 
                    db_write_log(f"collect_metric_mssql_transaction_requests failed with error:{e}"   ,0,"collect_metric_mssql_transaction_requests" ,servername, port=mssql_port)
                    return  0
    finally:
            db_write_log(f"collect_metric_mssql_transaction_requests success"   ,0,"collect_metric_mssql_transaction_requests" ,servername, port=mssql_port)
            raw_conn.close()
            
    return 1;





