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
import sqlglot
import sqlparse
from  sqlglot import exp

def metrics_custom_metrics_analysis():
        pg_connection_string = get_connection_string()
        postgres_engine = create_engine(pg_connection_string )
        metadata = MetaData(schema="monitoring")  
        p_delete_sql_cmd = f"""DELETE FROM monitoring.metric_results mr
WHERE mr.row_id IN (
    SELECT mr2.row_id
    FROM monitoring.metric_results mr2
    JOIN (
        SELECT 
            a.server,
            a.metric_name,
            a.metric_config
        FROM (
            SELECT 
                row_number() OVER (
                    PARTITION BY server, metric_name 
                    ORDER BY entry_date DESC
                ) AS seq,
                server,
                metric_name,
                metric_config
            FROM monitoring.general_metric_metadata_results
            WHERE metric_metadata != '[]'
        ) a
        WHERE a.seq = 1
    ) b 
        ON b.server = mr2.server 
       AND b.metric_name = mr2.metric_name       
);"""
        p_sql_cmd = f"""
        INSERT INTO monitoring.metric_results (
    server, 
    metric_name, 
    transaction_type, 
    query
)
 SELECT 
            a.server,
            a.metric_name,
			a.metric_name,
            a.metric_config
        FROM (
            SELECT 
                row_number() OVER (
                    PARTITION BY server, metric_name 
                    ORDER BY entry_date DESC
                ) AS seq,
                server,
                metric_name,
                metric_config
            FROM monitoring.general_metric_metadata_results
            WHERE metric_metadata != '[]'
        ) a
        WHERE a.seq = 1
"""
        try:
            with postgres_engine.begin() as conn:                                                  
                                   conn.execute(text(p_delete_sql_cmd))
                                   metrics_custom_analysis_expensive_transactions_parse();
                                   metrics_custom_analysis_active_transactions_parse();
                                   

                                

        except Exception as e:                 
                    db_write_log(f"metrics_custom_metrics_analysis failed with error:{e}"   ,0,"metrics_custom_metrics_analysis","" )


        finally:
            db_write_log(f"metrics_custom_metrics_analysis sucess"   ,0,"metrics_custom_metrics_analysis","" )
            conn.close()
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


def metrics_custom_analysis_active_transactions_parse():        

    pg_connection_string = get_connection_string()
   
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
                select distinct
		gmmr.row_id , 
		gmmr.server as server, 
		elem->>'query'  as query 
        from monitoring.general_metric_metadata_results  gmmr
        left join lateral  jsonb_array_elements (gmmr.metric_metadata::jsonb) elem  on true
        left outer join monitoring.metric_query_parsing   mqp on mqp.query_id = gmmr.row_id
        where gmmr.metric_name = 'active_transactions'
        and 	mqp.query_id  IS NULL
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "active_transactions"
                        row_id           = row[0] , 
                        table_name       = "monitoring.general_metric_metadata_results"
        
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,query,transaction_type , metric_name) VALUES (:server,:query,:transaction_type , :metric_name)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_name":transaction_type} 
                                ]
                                )
                                    if isinstance(query, tuple):
                                        query = query[0]
                                        try:
                                            expression = sqlglot.parse(query)
                                            # Find all columns
                                            try:
                                                observed_at = get_observed_at(query)
                                            except AttributeError  as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse observed_at failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                            try:    
                                                columns     =  [col.name for col in expression[0].find_all(expression[0].Column)]                                            
                                            except AttributeError  as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse columns failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                                columns = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_tables = expression[0].find_all(exp.Table)  # or just Table
                                                    tables = [table.name for table in all_tables if hasattr(table, 'name') and table.name]
                                                else:
                                                    tables = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse tables failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                tables = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_literals = expression[0].find_all(exp.Literal)  # or just Literal
                                                    literal = [lit.name for lit in all_literals if hasattr(lit, 'name') and lit.name]
                                                else:
                                                    literal = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse literal failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                literal = []                                            

                                            try:
                                                condition = [cond.name for cond in expression[0].find_all(exp.Condition) if hasattr(cond, 'name')]                                    
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse condition failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                condition = []                                            
                                            try:
                                                join = [j.name for j in expression[0].find_all(exp.Join) if hasattr(j, 'name')]                                                                        
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed join with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                join = []                               
                                                                                        
                                            try:
                                                func = [f.name for f in expression[0].find_all(exp.Func) if hasattr(f, 'name')]                                                                                                             
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed func with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                func = []
                                            
                                            with postgres_engine.begin() as conn:                                                  
                                                conn.execute(
                                                text("INSERT INTO monitoring.metric_query_parsing ( server ,query_id ,query,observed_at ,columns, tables, literal,condition,joins,func  , table_name) VALUES (:server ,:query_id ,:query,:observed_at ,:columns, :tables, :literal,:condition,:joins,:func,:table_name)"),
                                                [{"server":servername, "transaction_type":transaction_type , "query_id":row_id,"query":query,"observed_at":observed_at,"columns":columns,"tables":tables,"literal":literal,"condition":condition,"joins":join , "func":func,"table_name":table_name}]
                                                );
                                        
                                                

                                        except Exception as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                        finally:
                                                try:
                                                    parsed = sqlparse.parse(query)
    
                                                    if parsed:
                                                        result = parse_sql_query(query)
                                                        
                                                        tables = result['tables']
                                                        columns = result['columns']
                                                        literals = []  # sqlparse doesn't easily extract literals
                                                        conditions = result['conditions']
                                                        joins = result['joins']
                                                        functions = result['functions']
                                                    else:
                                                        tables = []
                                                        columns = []
                                                        literals = []
                                                        conditions = []
                                                        joins = []
                                                        functions = []
                                                        
                                                    # Insert into database
                                                    with postgres_engine.begin() as conn: 
                                                        conn.execute(
                                                        text("""
                                                            INSERT INTO monitoring.metric_query_parsing 
                                                            (server, query_id, query, observed_at, columns, tables, literal, condition, joins, func , table_name) 
                                                            VALUES 
                                                            (:server, :query_id, :query, :observed_at, :columns, :tables, :literal, :condition, :joins, :func , :table_name)
                                                        """),
                                                        {
                                                            "server": servername,
                                                            "query_id": row_id,
                                                            "query": query,
                                                            "observed_at":  get_observed_at(query),
                                                            "columns": str(columns),
                                                            "tables": str(tables),
                                                            "literal": str(literals),
                                                            "condition": str(conditions),
                                                            "joins": str(joins),
                                                            "func": str(functions) , 
                                                            "table_name": str(table_name) , 
                                                        }
                                                    )
                                                    
                                                except Exception as e:
                                                    db_write_log(f"SQL parsing failed: {e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                    raw_conn.close()  
    except Exception as e:                 
        db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
    finally:
        db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )  
        raw_conn.close()  
    return 1







def metrics_custom_analysis_expensive_transactions_parse():        

    pg_connection_string = get_connection_string()
   
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
 select 
		gmmr.row_id , 
		gmmr.server as server, 
		elem->>'avg_cpu_ms' as avg_cpu_ms , 
		elem->>'query_text' as query , 
		elem->>'database_name' as   database_name,
		elem->>'avg_duration_ms'  as avg_duration_ms,
		elem->>'execution_count'as execution_count,
		elem->>'max_duration_ms' as max_duration_ms,
		elem->>'avg_logical_reads' as avg_logical_reads,
		elem->>'last_execution_time' as last_execution_time
from monitoring.general_metric_metadata_results  gmmr
left join lateral  jsonb_array_elements (gmmr.metric_metadata::jsonb) elem  on true
left outer join monitoring.metric_query_parsing   mqp on mqp.query_id = gmmr.row_id
where gmmr.metric_name = 'expensive_transactions'
and 	mqp.query_id  IS NULL
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "expensive_transactions"
                        row_id           = row[0],
                        table_name           = "monitoring.general_metric_metadata_results"
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
                                    conn.execute(
                                text("INSERT INTO monitoring.metric_results(server,query,transaction_type , metric_name) VALUES (:server,:query,:transaction_type , :metric_name)"),
                                [{"server":servername, "transaction_type":transaction_type , "query":query,"metric_name":transaction_type} 
                                ]
                                )
                                    if isinstance(query, tuple):
                                        query = query[0]
                                        try:
                                            expression = sqlglot.parse(query)
                                            # Find all columns
                                            try:
                                                observed_at = get_observed_at(query)
                                            except AttributeError  as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse observed_at failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                            try:    
                                                columns     =  [col.name for col in expression[0].find_all(expression[0].Column)]                                            
                                            except AttributeError  as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse columns failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                                columns = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_tables = expression[0].find_all(exp.Table)  # or just Table
                                                    tables = [table.name for table in all_tables if hasattr(table, 'name') and table.name]
                                                else:
                                                    tables = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse tables failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                tables = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_literals = expression[0].find_all(exp.Literal)  # or just Literal
                                                    literal = [lit.name for lit in all_literals if hasattr(lit, 'name') and lit.name]
                                                else:
                                                    literal = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse literal failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                literal = []                                            

                                            try:
                                                condition = [cond.name for cond in expression[0].find_all(exp.Condition) if hasattr(cond, 'name')]                                    
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse condition failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                condition = []                                            
                                            try:
                                                join = [j.name for j in expression[0].find_all(exp.Join) if hasattr(j, 'name')]                                                                        
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed join with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                join = []                               
                                                                                        
                                            try:
                                                func = [f.name for f in expression[0].find_all(exp.Func) if hasattr(f, 'name')]                                                                                                             
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed func with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                func = []
                                            
                                            with postgres_engine.begin() as conn:                                                  
                                                conn.execute(
                                                text("INSERT INTO monitoring.metric_query_parsing ( server ,query_id ,query,observed_at ,columns, tables, literal,condition,joins,func , table_name ) VALUES (:server ,:query_id ,:query,:observed_at ,:columns, :tables, :literal,:condition,:joins,:func,:table_name)"),
                                                [{"server":servername, "transaction_type":transaction_type , "query_id":row_id,"query":query,"observed_at":observed_at,"columns":columns,"tables":tables,"literal":literal,"condition":condition,"joins":join , "func":func,"table_name":table_name}]
                                                );
                                        
                                                

                                        except Exception as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                        finally:
                                                try:
                                                    parsed = sqlparse.parse(query)
    
                                                    if parsed:
                                                        result = parse_sql_query(query)
                                                        
                                                        tables = result['tables']
                                                        columns = result['columns']
                                                        literals = []  # sqlparse doesn't easily extract literals
                                                        conditions = result['conditions']
                                                        joins = result['joins']
                                                        functions = result['functions']
                                                    else:
                                                            tables = []
                                                            columns = []
                                                            literals = []
                                                            conditions = []
                                                            joins = []
                                                            functions = []
                                                        
                                                    # Insert into database
                                                    with postgres_engine.begin() as conn:       
                                                        conn.execute(
                                                        text("""
                                                            INSERT INTO monitoring.metric_query_parsing 
                                                            (server, query_id, query, observed_at, columns, tables, literal, condition, joins, func , table_name) 
                                                            VALUES 
                                                            (:server, :query_id, :query, :observed_at, :columns, :tables, :literal, :condition, :joins, :func,:table_name)
                                                        """),
                                                        {
                                                            "server": servername,
                                                            "query_id": row_id,
                                                            "query": query,
                                                            "observed_at":  get_observed_at(query),
                                                            "columns": str(columns),
                                                            "tables": str(tables),
                                                            "literal": str(literals),
                                                            "condition": str(conditions),
                                                            "joins": str(joins),
                                                            "func": str(functions) , 
                                                            "table_name": str(table_name)
                                                        }
                                                    )
                                                except Exception as e:                 
                                                        db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                                                finally:
                                                        db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )  
                                                        raw_conn.close()  
    except Exception as e:                 
            db_write_log(f"custom_metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"custom_metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )

    finally:
            db_write_log(f"custom_metrics_active_transactions_analysis_parse success"   ,0,"custom_metrics_active_transactions_analysis_parse","" )  
            raw_conn.close()            
    return 1;
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
