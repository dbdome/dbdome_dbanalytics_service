#monitoring_metrics_mssql_service_account_permissions
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
import urllib.parse

def collect_metric_mssql_service_account_permissions(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver ):
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


    
    connection_string = f"mssql+pyodbc://{username}:{password}@{server}/{database}?driver={driver}"

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
            servicename, startup_type_desc, service_account
            FROM 
            sys.dm_server_services;               """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                        text("INSERT INTO monitoring.server_hardening_unused_inactive_sql_server_logins ( server,loginname,createddate,lastmodifieddate,lastlogintime ) VALUES (:server,:loginname,:createddate,:lastmodifieddate,:lastlogintime)"),
                        [{"server": row[0], "loginname": row[1], "createddate": row[2] , "lastmodifieddate":row[3] , "lastlogintime":row[4] } for row in df.itertuples(index=False)]
)
                
    except Exception as e:                 
                    db_write_log(f"server_hardening_unused_inactive_sql_server_logins failed with error:{e}"   ,0,"server_hardening_unused_inactive_sql_server_logins" )
    finally:
            db_write_log(f"server_hardening_unused_inactive_sql_server_logins success"   ,0,"server_hardening_unused_inactive_sql_server_logins" )
            raw_conn.close()
    return  1
    return 0;

