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

def metrics_analysis_populate_threats():
     #postgresql connection
    pg_connection_string = get_connection_string()
   
 # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
            with A AS 
            (
            select
            ROW_NUMBER() OVER (
            PARTITION BY server , query order by metric_name  , server , query 
            ) seq   , 
            ROW_NUMBER() OVER (
            PARTITION BY server , query order by server , query
            ) query_no   , 
            transaction_type , metric_name , metric_result ,  server  , low_range, high_range,query from monitoring.metric_results  
            where metric_result > high_range
            ),b as
            (
            select 
            query_no , 
            row_number() over (partition by query_no , metric_name  order by query_no , metric_name , metric_result desc) seq , 
            transaction_type , metric_name , metric_result ,  server  , low_range, high_range,query  from a 
            where seq=1
            and metric_result > high_range 
            )
            select
            transaction_type , query_no , metric_name , metric_result ,  server  , low_range, high_range,query  from b
            where seq=1
            order by query_no , seq
           """            
    try:
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        #query_no , metric_name , metric_result ,  server  , low_range, high_range,query,transaction_type  
                        server      = row['server']
                        query_no    = row['query_no']                          
                        query         = row['query'] ,
                        metric_name    = row['metric_name']                        
                        min_value_duration = row['low_range']
                        max_value_duration = row['high_range']
                        metric_results = row['metric_results']
                        transaction_type = row['transaction_type']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO threats.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":[server], "transaction_type":transaction_type , "query":query,"metric_result":metric_results,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                for row in df.itertuples(index=False)]
                                )
    except Exception as e:                 
                    db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",server )
    
   

    finally:            
            db_write_log(f"metrics_analysis_populate_threats sucess"   ,0,"metrics_active_transactions_analysis",server )
            raw_conn.close()
            return  1