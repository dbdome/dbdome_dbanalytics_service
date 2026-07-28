import psycopg2
import pandas as pd
from utils.config_dotenv import get_connection_string
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.log4dbexpert import db_write_log, get_port_for_server

import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders

def metrics_sql_injection_analysis():
     #postgresql connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    p_delete_sql_cmd = f"""
    delete from monitoring.metric_results where row_id in (  
select row_id from   (  
select row_number() over ( partition by  server, metric_id, transaction_type, query, metric_result, metric_name, low_range, high_range order by  entry_date desc ) seq ,
server, metric_id, transaction_type, query  from  monitoring.metric_results   )  where seq >1  )
"""
    try:
       with postgres_engine.begin() as conn:                                                  
                                   conn.execute(
                                text(p_delete_sql_cmd))

    except Exception as e:                 
                    db_write_log(f"metrics_active_sessions_analysis failed with error:{e}"   ,0,"metrics_active_sessions_analysis",servername, port=get_port_for_server(servername) )


 # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f"""   
 select  
ONLINE_SQL_INJECTION.server , 
ONLINE_SQL_INJECTION.pattern_name , 
ONLINE_SQL_INJECTION.query
 from
(
select
server ,
login_name ,  
program_name ,
host_name  ,
query ,
pattern_name
from monitoring.active_transactions   at
join metrics.sql_injection_patterns sp on at.query like '%' || sp.pattern_clause || '%'
where at.last_request_end_time > (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 minute'
)ONLINE_SQL_INJECTION
left outer join
(
select
server ,
login_name ,  
program_name ,
host_name  ,
query ,
pattern_name
from monitoring.active_transactions   at
join metrics.sql_injection_patterns sp on at.query like '%' || sp.pattern_clause || '%'
where at.last_request_end_time < (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 day'
) HISTORICAL_SQL_INJECTIONS on
HISTORICAL_SQL_INJECTIONS.server= ONLINE_SQL_INJECTION.server
and HISTORICAL_SQL_INJECTIONS.login_name= ONLINE_SQL_INJECTION.login_name
and HISTORICAL_SQL_INJECTIONS.program_name= ONLINE_SQL_INJECTION.program_name  
and HISTORICAL_SQL_INJECTIONS.host_name= ONLINE_SQL_INJECTION.host_name
and HISTORICAL_SQL_INJECTIONS.query=ONLINE_SQL_INJECTION.query
and HISTORICAL_SQL_INJECTIONS.pattern_name= ONLINE_SQL_INJECTION.pattern_name
where HISTORICAL_SQL_INJECTIONS.pattern_name IS NULL
"""            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername          = row['server']  
                        query               = row['query'] ,
                        metric_name         = "sql_injection"
                        transaction_type    = row['pattern_name']
                        min_value_duration = 0
                        max_value_duration = 0
                        result = 1
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":result,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )

    except Exception as e:                 
                    db_write_log(f"metrics_sql_injection_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis","" )

    finally:
            db_write_log(f"metrics_sql_injection_analysis sucess"   ,0,"metrics_active_transactions_analysis","" )
            raw_conn.close()
    return  1