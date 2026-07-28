#monitoring_metrics_mssql_alerts
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

def collect_metric_mssql_network_alerts(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
    server = mssql_server
    servername = mssql_servername
    database = mssql_database
    username = mssql_username
    password = mssql_password
    installed_drivers = pyodbc.drivers()
    print("Installed drivers:", installed_drivers)
    import urllib.parse

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
                SELECT  
                '{servername}' server,
                name,  
                event_source,  
                message_id,  
                severity,  
                enabled,  
                has_notification,      
                delay_between_responses,  
                occurrence_count,  
                last_occurrence_date,  
                last_occurrence_time      
                FROM msdb.dbo.sysalerts WITH (NOLOCK)      
                ORDER BY name OPTION (RECOMPILE);      
            """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            if df.empty:
                return 1
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                text("INSERT INTO monitoring.alerts (\
                     server , name,  event_source,  message_id,severity,enabled,has_notification,delay_between_responses,occurrence_count,last_occurrence_date,last_occurrence_time\
                       ) VALUES (:server , :name,  :event_source,  :message_id,:severity,:enabled,:has_notification,:delay_between_responses,:occurrence_count,:last_occurrence_date,:last_occurrence_time)"),
                        [{
                            "server":row[0] , 
                            "name":row[1],  
                            "event_source":row[2],  
                            "message_id":row[3],
                            "severity":row[4],
                            "enabled":row[5],
                            "has_notification":row[6],
                            "delay_between_responses":row[7],
                            "occurrence_count":row[8],
                            "last_occurrence_date":row[9],
                            "last_occurrence_time":row[10]
                          } for row in df.itertuples(index=False)]
)
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_network_alerts failed with error:{e}"   ,0,"collect_metric_mssql_network_alerts",servername, port=mssql_port)
    finally:
            db_write_log(f"collect_metric_mssql_network_alerts success"   ,0,"collect_metric_mssql_network_alerts",servername, port=mssql_port)
            raw_conn.close()
    return  1
    return 0;

