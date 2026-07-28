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
import urllib.parse

def update_report_counters ():
    #postgresql connection
    pg_connection_string = get_connection_string()
    # ========== 2. Create SQLAlchemy Engines ==========
    servername = "";
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    p_sql_cmd = f""" 
            SELECT '{servername}' server,
            tsql.text AS Query,
            req.status,
            req.command,
            req.cpu_time,
            req.total_elapsed_time
    FROM 
        sys.dm_exec_requests req
    CROSS APPLY 
        sys.dm_exec_sql_text(req.sql_handle) AS tsql
    WHERE 
        tsql.text LIKE '%--%'         
    OR tsql.text LIKE '%;% %'              
    OR tsql.text LIKE '%exec%'    
    OR tsql.text LIKE '%xp_%'     
    OR tsql.text LIKE '%sp_%'     
    OR tsql.text LIKE '%UNION%'  
ORDER BY 
    req.total_elapsed_time DESC
            """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            raw_conn.close()
            # ========== 4. Bulk UPSERT into PostgreSQL ==========
            _sql = """
                    INSERT INTO monitoring.injection_requests 
                    (server, query, status, command, cpu_time, total_elapsed_time) 
                    VALUES (%(server)s, %(query)s, %(status)s, %(command)s, %(cpu_time)s, %(total_elapsed_time)s)
                """            
            with postgres_engine.begin() as conn:                                                  
                conn.execute(
                        text(_sql),
                        [{"server": row[0], "query": row[1].replace("'", "''") if row[1] else '', "status": row[2] , "command":row[3] , "cpu_time":row[4] , 
                          "total_elapsed_time":row[5]} for row in df.itertuples(index=False)]
)
                
    except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_sql_injection failed with error:{e}"   ,0,"collect_metric_mssql_sql_injection",servername )
    finally:
            print("✅ collect_metric_mssql_sql_injection=>Data sync complete")    
            raw_conn.close()
    return  1
    return 0;

