#monitoring_metrics_mssql_ad_hoc_cpu_consuming_queries

import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

def collect_metric_mssql_ad_hoc_consuming_queries(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
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
        SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
        WHEN -1 THEN DATALENGTH(qt.TEXT)
        ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1),
        qs.execution_count,
        qs.total_logical_reads, qs.last_logical_reads,
        qs.total_logical_writes, qs.last_logical_writes,
        qs.total_worker_time,
        qs.last_worker_time,
        qs.total_elapsed_time/1000000 total_elapsed_time_in_S,
        qs.last_elapsed_time/1000000 last_elapsed_time_in_S,
        qs.last_execution_time
        FROM sys.dm_exec_query_stats qs        
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
        where qs.last_execution_time > dateadd(minute , -1 , getdate())
        ORDER BY qs.total_worker_time DESC
        """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                        text("INSERT INTO monitoring.ad_hoc_cpu_consuming_queries(server,query,execution_count,total_logical_reads,last_logical_reads,\
                             last_logical_writes,total_logical_writes,total_worker_time,last_worker_time,total_elapsed_time_in_S,last_elapsed_time_in_S,\
                             last_execution_time \
                ) VALUES \
                (:server ,\
                :query,\
                :execution_count ,\
                :total_logical_reads,\
                :last_logical_reads ,\
                :last_logical_writes ,\
                :total_logical_writes ,\
                :total_worker_time ,\
                :last_worker_time ,\
                :total_elapsed_time_in_S ,\
                :last_elapsed_time_in_S,\
                :last_execution_time  )"),
                [{"server":row[0],
                "query":row[1] ,
                "execution_count":row[2] ,
                "total_logical_reads":row[3],
                "last_logical_reads":row[4] ,
                "last_logical_writes":row[5],
                "total_logical_writes":row[6],
                "total_worker_time":row[7],
                "last_worker_time":row[8],
                "total_elapsed_time_in_S":row[9],
                "last_elapsed_time_in_S":row[10],
                "last_execution_time":row[11]
                } for row in df.itertuples(index=False)])        
    except Exception as e:                                                         
                    db_write_log(f"ad_hoc_cpu_consuming_queries failed with error:{e}"   ,0,"ad_hoc_cpu_consuming_queries" ,servername, port=mssql_port)
                    return  0
    finally:
            db_write_log(f"ad_hoc_cpu_consuming_queries success"   ,0,"ad_hoc_cpu_consuming_queries" ,servername, port=mssql_port)    
            raw_conn.close()
            
    return 1;





