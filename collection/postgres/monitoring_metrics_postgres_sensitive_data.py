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

def collect_metric_postgres_sensitive_data_activity(pg_server,pg_servername  ,pg_port, pg_database , pg_username , pg_password , pg_driver ):
    
    # Create the PG monitoried connection string

    pg_monitored_connection_string = f"postgresql://{pg_username}:{pg_password}@{pg_server}:{pg_port}/{pg_database}?sslmode=disable"
    #postgresql connection
    pg_home_connection_string = get_connection_string()
   
    try:
        # ========== 2. Create SQLAlchemy Engines ==========
        # SQL Server (source)
        pg_home_server_engine = create_engine(pg_home_connection_string , echo=True)
        # PostgreSQL (target)
        pg_monitored_engine = create_engine(pg_monitored_connection_string , echo=True)
        metadata = MetaData(schema="monitoring")  
 
        raw_conn = pg_monitored_engine.raw_connection()    
        p_sql_cmd = f"""              
                     select 
                        '{pg_server}' servername ,                             
                                table_catalog AS database_name,
                                table_schema,
                                table_name,
                                column_name,
                                data_type
                            FROM 
                                information_schema.columns
                            WHERE 
                                column_name ILIKE ANY (ARRAY[
                                    '%password%', '%pass%', '%secret%', '%token%', '%key%', 
                                    '%credit%', '%card%', '%ssn%', '%email%', '%phone%', 
                                    '%address%', '%dob%', '%birth%', '%salary%'
                                ])
                            ORDER BY 
                                table_catalog, table_schema, table_name;
                        """           
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        raw_conn.close()
        # ========== 4. Bulk UPSERT into PostgreSQL ==========
        if df.empty:
            return 1
        with pg_home_server_engine.begin() as conn:                                                                  
                conn.execute(
                text("delete from monitoring.sensitive_schema where server =:server"),
                        [{                      
                      "server":row[0]
                       } for row in df.itertuples(index=False)]
        )
                        
        with pg_home_server_engine.begin() as conn:                                                                  
                conn.execute(
                text("INSERT INTO monitoring.sensitive_schema (server ,  database_name,table_schema,table_name,column_name,data_type  )\
                      VALUES (:server ,  :database_name,:table_schema,:table_name,:column_name,:data_type )"),
                        [{                      
                      "server":row[0],
                      "database_name":row[1],
                      "table_schema":row[2],
                        "table_name":row[3],
                        "column_name":row[4],
                       "data_type" :row[5]
                       } for row in df.itertuples(index=False)]
        )
    except Exception as e:                 
                    db_write_log(f"collect_metric_postgres_sensitive_data_activity failed with error:{e}"   ,0,"collect_metric_postgres_sensitive_data_activity" , pg_server , port=pg_port)
    finally:
            db_write_log(f"✅collect_metric_postgres_sensitive_data_activity success"   ,0,"collect_metric_postgres_sensitive_data_activity" , pg_server , port=pg_port)
            raw_conn.close()
            return  1
    return 0;

