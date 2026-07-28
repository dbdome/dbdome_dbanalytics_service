import psycopg2
import pandas as pd
from utils.config_dotenv import get_connection_string
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.log4dbexpert import db_write_log


def post_version():
     #postgresql connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f"""   
                select version_number , application_name from 
                (
	                select row_number() over ( partition by application_name order by entry_date desc ) seq ,  version_number , application_name from versioning.version_control
                )
                where seq=1 and application_name = 'dbanalytics'
                """            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        version_number          = row['version_number']  
                        application_name               = row['application_name'] 
                        result = 1
                        # Process each row...

    except Exception as e:                 
                    db_write_log(f"metrics_sql_injection_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis","" )

    finally:
            db_write_log(f"metrics_sql_injection_analysis sucess"   ,0,"metrics_active_transactions_analysis","" )
            print(f"application_name:{application_name} , Version:{version_number}")
            raw_conn.close()
    return  1