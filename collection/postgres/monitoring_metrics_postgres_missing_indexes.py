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

def collect_metric_postgres_missing_indexes(pg_server,pg_servername  ,pg_port, pg_database , pg_username , pg_password , pg_driver ):

    # Create the connection string

    monitored_connection_string = f"postgresql://{pg_username}:{pg_password}@{pg_server}:{pg_port}/{pg_database}"
    #postgresql connection
    pg_home_connection_string = get_connection_string()
   
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    pg_monitored_server_engine = create_engine(monitored_connection_string )
    # PostgreSQL (target)
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="monitoring")  
    try:
        raw_conn = pg_monitored_server_engine.raw_connection()    
        p_sql_cmd = f"""              
                            SELECT
                            '{pg_servername}'  servername , 
                                relname AS table_name,
                                attname AS column_name,
                                n_tup_ins table_inserts  , 
                                n_tup_upd table_updates ,
                                n_tup_del AS table_deletes,
                                n_live_tup AS live_rows,
                                pg_size_pretty(pg_relation_size(relid)) AS size
                            FROM
                                pg_stat_user_tables t
                            JOIN
                                pg_attribute a ON a.attrelid = t.relid
                            LEFT JOIN
                                pg_index i ON i.indrelid = t.relid AND a.attnum = ANY(i.indkey)
                            WHERE
                                i.indexrelid IS NULL AND NOT a.attisdropped AND a.attnum > 0
                            ORDER BY
                            live_rows DESC;
                        """           
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        raw_conn.close()
        # ========== 4. Bulk UPSERT into PostgreSQL ==========
        if df.empty:
            return 1
        with pg_postgres_home_engine.begin() as conn:                                                                  
                conn.execute(
                text("INSERT INTO monitoring.table_usage (\
                               server , table_name , column_name , inserts , updates , deletes ,live_rows ,size)\
                      VALUES (:server , :table_name , :column_name , :inserts , :updates , :deletes ,:live_rows ,:size )"),
                        [{                      
                      "server":row[0],
                      "table_name":row[1],
                      "column_name":row[2],
                       "inserts": row[3],
                        "updates": row[4],
                        "deletes":row[5] , 
                       "live_rows" :row[6],
                        "size":row[7] 
                       } for row in df.itertuples(index=False)]
)
    except Exception as e:                 
                    db_write_log(f"collect_metric_postgres_missing_indexes failed with error:{e}"   ,0,"collect_metric_mssql_active_sessions" , pg_server , port=pg_port)
    finally:
            db_write_log(f"✅ collect_metric_postgres_missing_indexes success"   ,0,"collect_metric_mssql_active_sessions" , pg_server , port=pg_port)
            raw_conn.close()
    return  1
    return 0;

