#monitoring_metrics_mssql_tcp_connection
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
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders

def collect_metric_mssql_tcp_connections(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
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
    pg_connection_string = get_connection_string()



   
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    try:
        sql_server_engine = create_engine(connection_string )
        # PostgreSQL (target)
        postgres_engine = create_engine(pg_connection_string )
        metadata = MetaData(schema="monitoring")  
        raw_conn = sql_server_engine.raw_connection()    
        p_sql_cmd = f""" 
             SELECT '{servername}' server,
                  session_id ,
                  most_recent_session_id ,
                  connect_time ,
                  net_transport ,
                  protocol_type ,
                  endpoint_id ,
                  encrypt_option  ,
                  auth_scheme ,
                  node_affinity ,
                  num_reads ,
                  num_writes ,
                  last_read ,
                  last_write ,
                  net_packet_size ,
                  client_net_address ,
                  client_tcp_port ,
                  local_net_address ,
                  local_tcp_port  
            from sys.dm_exec_connections
            where net_transport = 'TCP'
            """            
    
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
        with postgres_engine.begin() as conn:                                                  
                conn.execute(
                        text("INSERT INTO monitoring.tcp_connections (server, session_id ,most_recent_session_id,\
                  connect_time,\
                  net_transport ,\
                  protocol_type ,\
                endpoint_id ,\
            encrypt_option  ,\
            auth_scheme ,\
            node_affinity ,\
            num_reads ,\
            num_writes ,\
            last_read ,\
            last_write ,\
            net_packet_size ,\
            client_net_address ,\
            client_tcp_port ,\
            local_net_address ,\
            local_tcp_port  ) VALUES (:server,:session_id, \
                                            :most_recent_session_id , \
                                            :connect_time ,\
                                            :net_transport ,\
                                            :protocol_type ,\
                                            :endpoint_id , \
                                            :encrypt_option,\
                                            :auth_scheme ,\
                                        :node_affinity ,\
                                        :num_reads ,\
                                        :num_writes ,\
                                        :last_read ,\
                                        :last_write ,\
                                        :net_packet_size ,\
                                        :client_net_address ,\
                                        :client_tcp_port ,\
                                        :local_net_address ,\
                                        :local_tcp_port)"),
                        [{"server": row[0], "session_id": row[1], "most_recent_session_id": row[2] , "connect_time":row[3] , "net_transport":row[4] , 
                          "protocol_type":row[5],"endpoint_id":row[6] ,"encrypt_option":row[7],"auth_scheme":row[8] ,
                          "node_affinity":row[9]  ,"num_reads":row[10]  ,"num_writes":row[11]   ,"last_read":row[12] , 
                          "last_write":row[13] ,"net_packet_size":row[14] , "client_net_address":row[15],  "client_tcp_port":row[16] , 
                          "local_net_address":row[17] ,"local_tcp_port":row[18]  } for row in df.itertuples(index=False)]
)
                
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_tcp_connections failed with error:{e}"   ,0,"collect_metric_mssql_tcp_connections",servername , port=mssql_port)
    finally:
            db_write_log(f"collect_metric_mssql_tcp_connections success"   ,0,"collect_metric_mssql_tcp_connections",servername , port=mssql_port)
            raw_conn.close()
    return  1
    return 0;

