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
import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
import urllib.parse

def collect_metric_mssql_latency(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver , auth_type , mssql_port=None):
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

    server_with_port = f"{mssql_server},{mssql_port}" if mssql_port else mssql_server
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={mssql_database or 'master'};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={mssql_database or 'master'};
            UID={mssql_username};
            PWD={mssql_password};
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
                 tab.[Drive], tab.volume_mount_point AS [Volume_Mount_Point],
            CASE
                        WHEN num_of_reads = 0 THEN 0
                        ELSE (io_stall_read_ms/num_of_reads)
            END AS [Read_Latency],
            CASE
                        WHEN num_of_writes = 0 THEN 0
                        ELSE (io_stall_write_ms/num_of_writes)
            END AS [Write_Latency],
            CASE
                        WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0
                        ELSE (io_stall/(num_of_reads + num_of_writes))
            END AS [Overall_Latency],
            CASE
                        WHEN num_of_reads = 0 THEN 0
                        ELSE (num_of_bytes_read/num_of_reads)
            END AS [Avg_Bytes_per_Read],
            CASE
                        WHEN num_of_writes = 0 THEN 0
                        ELSE (num_of_bytes_written/num_of_writes)
            END AS [Avg_Bytes_per_Write],
            CASE
                        WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0
                        ELSE ((num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes))
            END AS [Avg_Bytes_per_Transfer]
        FROM (SELECT LEFT(UPPER(mf.physical_name), 2) AS Drive, SUM(num_of_reads) AS num_of_reads,
                     SUM(io_stall_read_ms) AS io_stall_read_ms, SUM(num_of_writes) AS num_of_writes,
                     SUM(io_stall_write_ms) AS io_stall_write_ms, SUM(num_of_bytes_read) AS num_of_bytes_read,
                     SUM(num_of_bytes_written) AS num_of_bytes_written, SUM(io_stall) AS io_stall, vs.volume_mount_point
      FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
      INNER JOIN sys.master_files AS mf WITH (NOLOCK)
      ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
              CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.[file_id]) AS vs
      GROUP BY LEFT(UPPER(mf.physical_name), 2), vs.volume_mount_point) AS tab
    ORDER BY [Overall_Latency] OPTION (RECOMPILE);
            """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            if df.empty:
                return 1
            with postgres_engine.begin() as conn:                                                  
                conn.execute(text("delete from monitoring.latency where server = '{servername}'"))
                conn.execute(
                text("INSERT INTO monitoring.latency (\
                      server,drive,volume_mount_point,read_latency,write_latency,overall_latency,avg_bytes_per_read,avg_bytes_per_write,avg_bytes_transfer)\
                      VALUES (:server,:drive,:volume_mount_point,:read_latency,:write_latency,:overall_latency,:avg_bytes_per_read,:avg_bytes_per_write,:avg_bytes_transfer)"),
                        [{
                      "server":row[0],
                      "drive":row[1],
                      "volume_mount_point":row[2],
                      "read_latency":row[3],
                      "write_latency":row[4],
                      "overall_latency":row[5],
                      "avg_bytes_per_read":row[6],
                      "avg_bytes_per_write":row[7],
                      "avg_bytes_transfer":row[8]
                       } for row in df.itertuples(index=False)]
)
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_latency failed with error:{e}"   ,0,"collect_metric_mssql_latency" , servername, port=mssql_port)
    finally:
            db_write_log(f"collect_metric_mssql_latency success"   ,0,"collect_metric_mssql_latency" , servername, port=mssql_port)
            raw_conn.close()
    return  1
    return 0;

