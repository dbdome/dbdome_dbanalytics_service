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

def collect_metric_mssql_database_unmasked_users(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver , auth_type , mssql_port=None):
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
    try:
        cursor = raw_conn.cursor()
        cursor.execute("SELECT name FROM sys.databases")
        for row in cursor.fetchall():
            p_dbname = row[0]
            p_sql_cmd = f""" 
                SELECT '{servername}' server,  
                dp.name AS UserName,
                dp.type_desc AS UserType , 
      perm.state_desc ,
      perm.permission_name
FROM 
    {p_dbname}.sys.database_permissions AS perm
JOIN 
    {p_dbname}.sys.database_principals AS dp
    ON perm.grantee_principal_id = dp.principal_id
WHERE 
    perm.permission_name = 'UNMASK';            """
            vraw_conn = sql_server_engine.raw_connection()
            try:
                df = pd.read_sql_query(p_sql_cmd, con=vraw_conn)
                try:
                    with postgres_engine.begin() as conn:                                                  
                        conn.execute(
                        text("INSERT INTO monitoring.database_unmasked_users(server  , UserName,UserType , state_desc , permission_name ) values(:server  , :UserName,:UserType , :state_desc , :permission_name )"),
                        [{
                            "server":row[0] ,
                            "UserName":row[1],
                            "UserType":row[2] , 
                            "state_desc":row[3],
                            "permission_name":row[4]                            
                              } for row in df.itertuples(index=False)]
                        )
                except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_database_unmasked_users failed with error:{e}"   ,0,"collect_metric_mssql_database_unmasked_users",servername, port=mssql_port)
                    raw_conn.close()
                    return 0;
                finally:
                        db_write_log(f"collect_metric_mssql_database_unmasked_users sucess"   ,0,"collect_metric_mssql_database_unmasked_users",servername, port=mssql_port)
                raw_conn.close()
                return 0;

            
            
            
            
            
            
            
            
            
            
            finally:
                vraw_conn.close()


            
    finally:
            raw_conn.close()
    return  1
    return 0;

