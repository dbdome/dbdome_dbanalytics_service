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


def metrics_active_sessions_analysis():
     #postgresql connection
    pg_connection_string = get_connection_string()
   
 # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
    select distinct
  a.server ,  
  a.database_name, 
  a.query,
  a.duration_secs,
  a.database_name , 
    COALESCE(min_value_duration,0)min_value_duration,
    COALESCE(max_value_duration,0)max_value_duration      
from 
(
select      
              server ,  
              database_name, 
              query,
              duration_secs,
              COALESCE(AVG(duration_secs),0) - (STDDEV_SAMP(COALESCE(duration_secs,0))OVER (PARTITION BY server, database_name , query)*(1-0.16))::numeric(18,0) min_value_duration,
              COALESCE(AVG(duration_secs),0) + (STDDEV_SAMP(COALESCE(duration_secs,0))OVER (PARTITION BY server, database_name,query)*(1+0.16))::numeric(18,0) max_value_duration
              from monitoring.active_transactions 
              where duration_secs >0
              group by server ,  
              database_name, 
              query,
              duration_secs
) a			  
join 
(
	select distinct at.server , at.database_name , at.query 
    from monitoring.active_transactions at 
    inner join monitoring.active_sessions ass on ass.session_id = at.session_id 
    where last_request_end_time > (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 second'
) b on a.server  = b.server and a.database_name = b.database_name and a.query = b.query
            """            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        #servername    +='.'
                        #servername    +=row['database_name']    
                        query         = row['query'] ,
                        metric_name    = "duration_secs"
                        transaction_type = "active_sessions"
                        min_value_duration = row['min_value_duration']
                        max_value_duration = row['max_value_duration']
                        duration_secs = row['duration_secs']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":duration_secs,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )

    except Exception as e:                 
                    db_write_log(f"metrics_active_sessions_analysis failed with error:{e}"   ,0,"metrics_active_session_analysis",servername, port=get_port_for_server(servername) )

    p_sql_cmd = f""" 
select distinct
  a.server ,  
  a.database_name, 
  a.query,
  a.logical_reads,
  a.database_name , 
    COALESCE(min_value_duration,0)min_value_duration,
    COALESCE(max_value_duration,0)max_value_duration      
from 
(
select  distinct
              AT.server ,  
              database_name, 
              query,
              logical_reads,
              coalesce(avg(logical_reads),0) - (STDDEV_SAMP(COALESCE(logical_reads,0))OVER (PARTITION BY AT.server, database_name,query)*(1-0.16))::numeric(18,0) min_value_duration,
              coalesce(avg(logical_reads),0) +  (STDDEV_SAMP(COALESCE(logical_reads,0))OVER (PARTITION BY AT.server, database_name,query)*(1+0.16))::numeric(18,0) max_value_duration
              from monitoring.active_transactions AT
              
              where duration_secs >0
              group by AT.server ,  
              database_name, 
              query,
              logical_reads
) a			  
join 
(
	select at.server , database_name , query from monitoring.active_transactions at
	inner join monitoring.active_sessions ass on ass.session_id = at.session_id 
	where last_request_end_time > (select max(last_request_end_time) 
	from monitoring.active_transactions) - interval '1 second'
	
) b on a.server  = b.server and a.database_name = b.database_name and a.query = b.query"""            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        database_name = row['database_name']
                        query         = row['query'] ,
                        metric_name    = "logical_reads"
                        transaction_type = "active_sessions"
                        min_value_duration = row['min_value_duration']
                        max_value_duration = row['max_value_duration']
                        metric_results = row['logical_reads']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":metric_results,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )
    except Exception as e:                 
                    db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )

    
    
    #Reads 
    p_sql_cmd = f""" 
select distinct
  a.server ,  
  a.database_name, 
  a.query,
  a.reads,
  a.database_name , 
    COALESCE(min_value_duration,0)min_value_duration,
    COALESCE(max_value_duration,0)max_value_duration      
from 
(
select         distinct
              server ,  
              database_name, 
              query,
              reads,
				COALESCE(avg(reads),0)- (STDDEV_SAMP(COALESCE(reads,0))OVER (PARTITION BY server, database_name,query)*(1-0.16))::numeric(18,0) min_value_duration,
                COALESCE(avg(reads),0) + (STDDEV_SAMP(COALESCE(reads,0))OVER (PARTITION BY server, database_name,query)*(1+0.16))::numeric(18,0) max_value_duration
              from monitoring.active_transactions 
              where duration_secs >0 and reads >0
              group by server ,  
              database_name, 
              query,
              reads
) a			  
join 
(
	select at.server , database_name , query 
	from monitoring.active_transactions at 
	inner join monitoring.active_sessions ass on ass.session_id = at.session_id and at.server = ass.server
	where last_request_end_time > (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 second'
) b on a.server  = b.server and a.database_name = b.database_name and a.query = b.query
            """            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        database_name = row['database_name']
                        query         = row['query'] ,
                        metric_name    = "reads"
                        transaction_type = "active_sessions"
                        min_value_duration = row['min_value_duration']
                        max_value_duration = row['max_value_duration']
                        metric_results = row['reads']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":duration_secs,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )
    except Exception as e:                 
                    db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )

    #Writes 
    p_sql_cmd = f""" 
        select distinct
        a.server ,  
        a.database_name, 
        a.query,
        a.writes,
        a.database_name , 
            COALESCE(min_value_duration,0)min_value_duration,
            COALESCE(max_value_duration,0)max_value_duration      
        from 
        (
        select  distinct
                    server ,  
                    database_name, 
                    query,
                    writes,
                     coalesce(avg(writes),0)-   (STDDEV_SAMP(COALESCE(writes,0))OVER (PARTITION BY server, database_name,query)*(1-0.16))::numeric(18,0) min_value_duration,
                     coalesce(avg(writes),0)+   (STDDEV_SAMP(COALESCE(writes,0))OVER (PARTITION BY server, database_name,query)*(1+0.16))::numeric(18,0) max_value_duration
                    from monitoring.active_transactions 
                    where duration_secs >0 and writes >0
                    group by server ,  
                    database_name, 
                    query,
                    writes
        ) a			  
        join 
        (
            select at.server , database_name , query 
			from monitoring.active_transactions at
			inner join monitoring.active_sessions ass on ass.session_id = at.session_id and ass.server = at.server
			where last_request_end_time > (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 second'
        ) b on a.server  = b.server and a.database_name = b.database_name and a.query = b.query
            """            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        database_name = row['database_name']
                        query         = row['query'] ,
                        metric_name    = "writes"
                        transaction_type = "active_sessions"
                        min_value_duration = row['min_value_duration']
                        max_value_duration = row['max_value_duration']
                        metric_results = row['writes']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":metric_results,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )
    except Exception as e:                 
                    db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )


    #cpu_time 
    p_sql_cmd = f""" 
        select distinct
        a.server ,  
        a.database_name, 
        a.query,
        a.cpu_time,
        a.database_name , 
            COALESCE(min_value_duration,0)min_value_duration,
            COALESCE(max_value_duration,0)max_value_duration      
        from 
        (
        select  distinct
                    server ,  
                    database_name, 
                    query,
                    cpu_time,
                    coalesce(avg(cpu_time)) -     (STDDEV_SAMP(COALESCE(cpu_time,0))OVER (PARTITION BY server, database_name,query))::numeric(18,0) min_value_duration,
                    coalesce(avg(cpu_time)) +   (STDDEV_SAMP(COALESCE(cpu_time,0))OVER (PARTITION BY server, database_name,query))::numeric(18,0) max_value_duration
                    from monitoring.active_transactions 
                    where duration_secs >0 and writes >0
                    group by server ,  
                    database_name, 
                    query,
                    cpu_time
        ) a			  
        join 
        (
            select at.server , database_name , query 
			from monitoring.active_transactions at 
			inner join monitoring.active_sessions ass on ass.session_id = at.session_id and at.server = ass.server
			where last_request_end_time > (select max(last_request_end_time) from monitoring.active_transactions) - interval '1 second'
        ) b on a.server  = b.server and a.database_name = b.database_name and a.query = b.query
        """            
    try:            
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
            if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        database_name = row['database_name']
                        query         = row['query'] ,
                        metric_name    = "cpu_time"
                        transaction_type = "active_sessions"
                        min_value_duration = row['min_value_duration']
                        max_value_duration = row['max_value_duration']
                        metric_results = row['cpu_time']
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,transaction_type,query,metric_result,metric_name,low_range,high_range) VALUES (:server,:transaction_type,:query,:metric_result,:metric_name,:low_range,:high_range)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_result":metric_results,"metric_name":metric_name,"low_range":min_value_duration,"high_range":max_value_duration} 
                                ]
                                )
    except Exception as e:                 
                    db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )


    finally:
            db_write_log(f"metrics_active_sessions_analysis failed with error:{e}"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )
            raw_conn.close()
            return  1
    


    def get_observed_at( _query ):
            pg_connection_string = get_connection_string()
            postgres_engine = create_engine(pg_connection_string )
            metadata = MetaData(schema="monitoring")  
            raw_conn = postgres_engine.raw_connection()    
            p_sql_cmd = f"""            
                SELECT 
            STRING_AGG(last_request_epoch::text, ', ' ORDER BY last_request_epoch DESC) AS observed_at
        FROM (
            SELECT DISTINCT 
                query,
                EXTRACT(EPOCH FROM last_request_end_time)::bigint AS last_request_epoch
            FROM monitoring.active_transactions
        ) sub
        GROUP BY query
        """  
            # Parameters tuple
            params = (_query,)

            # Execute with parameters
            df = pd.read_sql_query(p_sql_cmd, con=raw_conn, params=params)    
            if not df.empty:
                for index, row in df.iterrows():
                                observed_at    = row['observed_at']  
    return observed_at



import sqlparse
from sqlparse.sql import IdentifierList, Identifier, Where, Comparison, Function
from sqlparse.tokens import Keyword, DML, Punctuation

def parse_sql_query(query):
    """Parse SQL query and extract components"""
    try:
        parsed = sqlparse.parse(query)[0]
        
        result = {
            'tables': [],
            'columns': [],
            'conditions': [],
            'functions': [],
            'joins': []
        }
        
        # Extract tables
        from_seen = False
        for token in parsed.tokens:
            if from_seen:
                if isinstance(token, IdentifierList):
                    for identifier in token.get_identifiers():
                        result['tables'].append(identifier.get_real_name())
                elif isinstance(token, Identifier):
                    result['tables'].append(token.get_real_name())
                elif token.ttype is Keyword:
                    from_seen = False
            elif token.ttype is Keyword and token.value.upper() == 'FROM':
                from_seen = True
        
        # Extract columns
        select_seen = False
        for token in parsed.tokens:
            if select_seen:
                if isinstance(token, IdentifierList):
                    for identifier in token.get_identifiers():
                        result['columns'].append(str(identifier))
                elif isinstance(token, Identifier):
                    result['columns'].append(str(token))
                elif token.ttype is Keyword:
                    break
            elif token.ttype is DML and token.value.upper() == 'SELECT':
                select_seen = True
        
        # Extract WHERE conditions
        for token in parsed.tokens:
            if isinstance(token, Where):
                result['conditions'].append(str(token))
        
        # Extract JOINs
        for token in parsed.tokens:
            if token.ttype is Keyword and 'JOIN' in token.value.upper():
                result['joins'].append(token.value)
        
        # Extract functions (approximate)
        for token in parsed.flatten():
            if token.ttype is sqlparse.tokens.Name.Builtin:
                result['functions'].append(token.value)
        
        return result
        
    except Exception as e:
        print(f"Error parsing SQL: {e}")
        return None

# Example usage
sql = """
SELECT u.id, u.name, COUNT(o.id) as order_count
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.active = 1 AND o.status = 'completed'
GROUP BY u.id
"""

result = parse_sql_query(sql)
print("Tables:", result['tables'])
print("Columns:", result['columns'])
print("Conditions:", result['conditions'])
print("Functions:", result['functions'])
print("Joins:", result['joins'])
