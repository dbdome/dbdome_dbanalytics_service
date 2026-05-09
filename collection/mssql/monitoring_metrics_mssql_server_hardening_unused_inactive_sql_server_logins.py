#monitoring_metrics_mssql_sql_injection
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

def collect_metric_mssql_server_hardening_unused_inactive_sql_server_logins(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver  , auth_type, mssql_port=None):
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
    server_with_port = f"{mssql_servername},{mssql_port}" if mssql_port else mssql_servername
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
    #postgresql connection
    pg_connection_string = get_connection_string()



    
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    sql_server_engine = create_engine(connection_string , echo=True)
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = sql_server_engine.raw_connection()    
    p_sql_cmd = f""" 
            SELECT '{servername}' server,
            name AS LoginName,
            create_date AS CreatedDate,
            modify_date AS LastModifiedDate,
            (SELECT MAX(login_time) 
            FROM sys.dm_exec_sessions 
            WHERE login_name = l.name) AS LastLoginTime
            FROM sys.sql_logins AS l
            WHERE l.is_disabled = 0
            ORDER BY LastLoginTime;
            """            
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
                    db_write_log(f"server_hardening_unused_inactive_sql_server_logins failed with error:{e}"   ,0,"server_hardening_unused_inactive_sql_server_logins",servername , port=mssql_port)
    finally:
            db_write_log(f"server_hardening_unused_inactive_sql_server_logins success"   ,0,"server_hardening_unused_inactive_sql_server_logins",servername , port=mssql_port)
            raw_conn.close()
            return  1
    return 0;

