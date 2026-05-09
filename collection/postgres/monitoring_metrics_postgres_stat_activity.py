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

def collect_metric_postgres_stat_activity(pg_server,pg_servername  ,pg_port, pg_database , pg_username , pg_password , pg_driver ):
   

    # Create the connection string

    pg_monitored_connection_string = f"postgresql://{pg_username}:{pg_password}@{pg_server}:{pg_port}/{pg_database}?sslmode=disable"
    #postgresql connection
    
    pg_home_connection_string = get_connection_string()
   
    try:
        # ========== 2. Create SQLAlchemy Engines ==========
        
        pg_home_server_engine = create_engine(pg_home_connection_string , echo=True)
        # PostgreSQL (target)
        monitored_engine = create_engine(pg_monitored_connection_string , echo=True)
        metadata = MetaData(schema="monitoring")  
 
        raw_conn = monitored_engine.raw_connection()    
        p_sql_cmd = f"""              
                     select 
                        '{pg_servername}' servername, session_id,  duration_secs,  start_time, last_request_end_time, login_name, program_name, host_name, query 
                        from  
                        (
                        SELECT 
                            pid session_id,
                            EXTRACT(EPOCH FROM now() - query_start)::INT AS duration_secs,	
                            COALESCE(xact_start, NOW()) AS start_time,
                            Now() last_request_end_time , 
                            usename login_name,
                            application_name program_name,
                            client_addr host_name,	    
                            query   
                        FROM pg_stat_activity 
                        WHERE state IN ('active', 'idle in transaction', 'idle in transaction (aborted)')
                        ) A
                        ORDER BY start_time;
                        """           
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        raw_conn.close()
        # ========== 4. Bulk UPSERT into PostgreSQL ==========
        if df.empty:
            return 1
        with pg_home_server_engine.begin() as conn:                                                                  
                conn.execute(
                text("INSERT INTO monitoring.active_transactions (\
                               server ,  session_id,   duration_secs,   start_time,  last_request_end_time,  login_name,  program_name,  host_name,  query  )\
                      VALUES (:server , :session_id,  :duration_secs,  :start_time, :last_request_end_time, :login_name, :program_name, :host_name, :query )"),
                        [{                      
                      "server":row[0],
                      "session_id":row[1],
                      "duration_secs":row[2],
                        "start_time": pd.to_datetime(row[3], errors='coerce'),
                        "last_request_end_time": pd.to_datetime(row[4], errors='coerce'),                      "login_name":row[5] , 
                       "program_name" :row[6],
                        "host_name":row[7] , 
                        "query":row[8]
                       } for row in df.itertuples(index=False)]
)
    except Exception as e:                 
                    db_write_log(f"collect_metric_postgres_active_transactions failed with error:{e}"   ,0,"collect_metric_postgres_stat_activity" , pg_servername , port=pg_port)
    finally:
            db_write_log(f"✅collect_metric_postgres_active_transactions success"   ,0,"collect_metric_postgres_stat_activity" , pg_servername , port=pg_port)
            raw_conn.close()
            return  1
    return 0;

