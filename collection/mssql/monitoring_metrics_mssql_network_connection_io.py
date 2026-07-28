#monitoring_metrics_mssql_network_connection_io
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

def collect_metric_mssql_network_connection_io(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
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
            SELECT        host_name,     program_name,     client_interface_name,     net_transport,     num_reads ,     num_writes ,  last_read ,   last_write ,   net_packet_size ,   client_net_address ,   login_time ,   login_name ,   cpu_time,  memory_usage ,   
            total_elapsed_time ,   total_scheduled_time ,   last_request_end_time ,   last_request_start_time,   original_login_name ,   database_id  ,  '{servername}' server ,  db_name(database_id  )
            FROM     sys.dm_exec_connections 
            JOIN     sys.dm_exec_sessions ON sys.dm_exec_connections.session_id = sys.dm_exec_sessions.session_id   
            """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            df = _dbdome_filter_excluded_logins(df)
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                text("INSERT INTO monitoring.connection_network_io (\
                     host_name, program_name, client_interface_name, net_transport, num_reads, num_writes, last_read, last_write, net_packet_size, client_net_address, login_time, login_name, cpu_time, memory_usage, total_elapsed_time, total_scheduled_time, last_request_end_time, last_request_start_time, original_login_name, database_id, server, database_name\
                       ) VALUES (:host_name, :program_name, :client_interface_name, :net_transport, :num_reads, :num_writes, :last_read, :last_write, :net_packet_size,\
                      :client_net_address, :login_time, :login_name, :cpu_time, :memory_usage, :total_elapsed_time, :total_scheduled_time, :last_request_end_time,\
                      :last_request_start_time, :original_login_name, :database_id, :server, :database_name)"),
                        [{
                            "host_name":row[0] ,
                            "program_name":row[1],     
                            "client_interface_name":row[2],       
                            "net_transport":row[3],       
                            "num_reads":row[4],            
                            "num_writes":row[5] ,  
                            "last_read":row[6] ,   
                            "last_write":row[7] ,   
                            "net_packet_size":row[8] ,   
                            "client_net_address":row[9] ,   
                            "login_time":row[10] ,
                            "login_name":row[11] ,   
                            "cpu_time":row[12],  
                            "memory_usage":row[13] ,   
                            "total_elapsed_time":row[14] ,   
                            "total_scheduled_time":row[15] ,   
                            "last_request_end_time":row[16] ,   
                            "last_request_start_time":row[17],
                            "original_login_name":row[18] ,   
                            "database_id":row[19]  ,   
                            "server":row[20]  ,   
                            "database_name":row[21] 
                          } for row in df.itertuples(index=False)]
)
                
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_tcp_connections failed with error:{e}"   ,0,"collect_metric_mssql_network_connection_io",servername, port=mssql_port)
    finally:
            db_write_log(f"collect_metric_mssql_network_connection_io success"   ,0,"collect_metric_mssql_network_connection_io",servername, port=mssql_port)
            raw_conn.close()
    return  1
    return 0;

