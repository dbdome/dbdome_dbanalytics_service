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

import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders

def metrics_sql_unification():
     #postgresql connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    try:
       with postgres_engine.begin() as conn:                                                  
                                   conn.execute(
                                text("delete from monitoring.metric_results where row_id in (  select row_id from   (  select row_number() over ( partition by  server, metric_id, transaction_type, query, metric_result, metric_name, low_range, high_range order by entry_date desc ) seq , server, metric_id, transaction_type, query, metric_result, metric_name, low_range, high_range from  monitoring.metric_results   )  where seq >1  )"))

    except Exception as e:                 
                    db_write_log(f"metrics_active_sessions_analysis failed with error:{e}"   ,0,"metrics_active_sessions_analysis","" )


    finally:
            db_write_log(f"metrics_sql_injection_analysis sucess"   ,0,"metrics_active_transactions_analysis","" )
            conn.close()
            return  1