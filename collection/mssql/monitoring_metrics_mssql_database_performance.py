#monitoring_metrics_mssql_database_performance
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

def collect_metric_mssql_database_performance(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver , auth_type , mssql_port=None):
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

    server_with_port = f"{servername},{mssql_port}" if mssql_port else servername
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={database};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={database};
            UID={username};
            PWD={password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    

    # Create the connection string
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)


    pg_connection_string = get_connection_string()



   
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    sql_server_engine = create_engine(connection_string , echo=True)
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = sql_server_engine.raw_connection()    
    p_sql_cmd = f"""              
            SELECT '{servername}' server ,  DB_NAME(fs.database_id) AS [Database Name], CAST(fs.io_stall_read_ms/(1.0 + fs.num_of_reads) AS NUMERIC(10,1)) AS [avg_read_stall_ms],  
            CAST(fs.io_stall_write_ms/(1.0 + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_write_stall_ms],  
            CAST((fs.io_stall_read_ms + fs.io_stall_write_ms)/(1.0 + fs.num_of_reads + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_io_stall_ms],  
            CONVERT(DECIMAL(18,2), mf.size/128.0) AS [File Size (MB)], mf.physical_name, mf.type_desc, fs.io_stall_read_ms, fs.num_of_reads,  
            fs.io_stall_write_ms, fs.num_of_writes, fs.io_stall_read_ms + fs.io_stall_write_ms AS [io_stalls], fs.num_of_reads + fs.num_of_writes AS [total_io]  
            FROM sys.dm_io_virtual_file_stats(null,null) AS fs  
            INNER JOIN sys.master_files AS mf WITH (NOLOCK)  
            ON fs.database_id = mf.database_id  
            AND fs.[file_id] = mf.[file_id]  
            ORDER BY avg_io_stall_ms DESC OPTION (RECOMPILE)"""            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                text("INSERT INTO monitoring.database_performance(server ,database_name , avg_read_stall_ms,avg_write_stall_ms,avg_io_stall_ms,File_Size, physical_name,type_desc, io_stall_read_ms, num_of_reads,io_stall_write_ms, num_of_writes, io_stalls, total_io) values(:server,:database_name, :avg_read_stall_ms,:avg_write_stall_ms,:avg_io_stall_ms,:File_Size,:physical_name,:type_desc, :io_stall_read_ms, :num_of_reads,:io_stall_write_ms, :num_of_writes, :io_stalls,:total_io)"),
                        [{
                            "server":row[0] ,
                            "database_name":row[1] ,
                            "avg_read_stall_ms":row[2] ,
                            "avg_write_stall_ms":row[3] ,
                            "avg_io_stall_ms":row[4] ,
                            "File_Size":row[5] ,
                            "physical_name":row[6] ,
                            "type_desc":row[7] ,
                            "io_stall_read_ms":row[8] ,
                            "num_of_reads":row[9] ,
                            "io_stall_write_ms":row[10] ,
                            "num_of_writes":row[11] ,
                            "io_stalls":row[12] ,
                            "total_io":row[13] 

                          } for row in df.itertuples(index=False)]
                )                
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_database_performance failed with error:{e}"   ,0,"collect_metric_mssql_database_performance",servername, port=mssql_port)
    finally:
            db_write_log(f"collect_metric_mssql_database_performance success "   ,0,"collect_metric_mssql_database_performance",servername, port=mssql_port)
            raw_conn.close()
            return  1
    return 0;

