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
from datetime import datetime, timezone
import pyodbc
import sqlparse
import sqlglot
from  sqlglot import exp
import json
#from sklearn.preprocessing import StandardScaler, LabelEncoder
#import torch
#from torch import nn
#from fastai.tabular.all import *
#from torch.utils.data import DataLoader, TensorDataset
#import torch.optim as optim
import sqlparse
from sqlparse.sql import IdentifierList, Identifier, Where, Comparison, Function
from sqlparse.tokens import Keyword, DML, Punctuation
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders




def metrics_active_transactions_analysis():
    try:
          
          metrics_active_transactions_analysis_parse();
    except Exception as e:
        db_write_log(f"metrics_active_transactions_ai_Autoencoder_analysis failed with error: {e}", 0, "metrics_active_transactions_ai_Autoencoder_analysis", "")
    finally:
        db_write_log("metrics_active_transactions_ai_Autoencoder_analysis finished successfully", 0, "metrics_active_transactions_ai_Autoencoder_analysis", "")
    return 1



def metrics_active_transactions_analysis_parse():        

    pg_connection_string = get_connection_string()
   
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
                select MAX(row_id) row_id  , server  , query from monitoring.active_transactions where query not in(select query from monitoring.metric_query_parsing )            
                group by server  , query
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "active_transactions"
                        row_id           = row[0]
                        # Process each row...
                        with postgres_engine.begin() as conn:                                                  
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
                                                text("INSERT INTO monitoring.metric_query_parsing ( server ,query_id ,query,observed_at ,columns, tables, literal,condition,joins,func ) VALUES (:server ,:query_id ,:query,:observed_at ,:columns, :tables, :literal,:condition,:joins,:func)"),
                                                [{"server":servername, "transaction_type":transaction_type , "query_id":row_id,"query":query,"observed_at":observed_at,"columns":columns,"tables":tables,"literal":literal,"condition":condition,"joins":join , "func":func}]
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
                                                    conn.execute(
                                                        text("""
                                                            INSERT INTO monitoring.metric_query_parsing 
                                                            (server, query_id, query, observed_at, columns, tables, literal, condition, joins, func) 
                                                            VALUES 
                                                            (:server, :query_id, :query, :observed_at, :columns, :tables, :literal, :condition, :joins, :func)
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
                                                            "func": str(functions)
                                                        }
                                                    )
                                                    
                                                except Exception as e:
                                                    db_write_log(f"SQL parsing failed: {e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                    raw_conn.close()  
    except Exception as e:                 
                                            db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse","" )
    finally:
     

                                    db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis","" )  
                                    raw_conn.close()                                                                                    
                                    return  1
    
    p_sql_cmd = f""" 
                select MAX(row_id) row_id  , server  , query from monitoring.active_transactions where query in(select query from monitoring.metric_query_parsing )            
                group by server  , query
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "active_transactions"
                        row_id           = row[0]
                        # Process each row...
                        try:
                                            observed_at = get_observed_at(query)
                                            with postgres_engine.begin() as conn:                                                  
                                                conn.execute(
                                            text("update monitoring.metric_query_parsing set  observed_at = :observed_at where server = :server and query = :query"),
                                            [{"server":servername, "query":query,"observed_at":observed_at} ])
                        except Exception as e:                 
                            db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                        finally:
                            db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )  
                            raw_conn.close()                                                                                    
                                    


    finally:
            db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis_parse","" )  
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

def to_iso_z(value):
    if isinstance(value, datetime):
        dt = value
    else:
        try:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S.%f")
        except ValueError:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")



     
def metrics_active_transactions_analysis_parse():        

    pg_connection_string = get_connection_string()
   
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
    raw_conn = postgres_engine.raw_connection()    
    #====================== Duration secs ============
    p_sql_cmd = f""" 
                select MAX(row_id) row_id  , server  , query from monitoring.active_transactions where query not in(select query from monitoring.metric_query_parsing )            
                group by server  , query 
                order by  row_id desc limit 1000
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "active_transactions"
                        row_id           = row[0]
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
                                            observed_at = 0;
                                            expression = sqlglot.parse(query)
                                            # Find all columns
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
                                            
                                            
                                            conn.execute(
                                                text("INSERT INTO monitoring.metric_query_parsing ( server ,query_id ,query,observed_at ,columns, tables, literal,condition,joins,func ) VALUES (:server ,:query_id ,:query,:observed_at ,:columns, :tables, :literal,:condition,:joins,:func)"),
                                                [{"server":servername, "transaction_type":transaction_type , "query_id":row_id,"query":query,"observed_at":observed_at,"columns":columns,"tables":tables,"literal":literal,"condition":condition,"joins":join , "func":func}]
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
                                                    conn.execute(
                                                        text("""
                                                            INSERT INTO monitoring.metric_query_parsing 
                                                            (server, query_id, query, observed_at, columns, tables, literal, condition, joins, func) 
                                                            VALUES 
                                                            (:server, :query_id, :query, :observed_at, :columns, :tables, :literal, :condition, :joins, :func)
                                                        """),
                                                        {
                                                            "server": servername,
                                                            "query_id": row_id,
                                                            "query": query,
                                                            "observed_at":  0,
                                                            "columns": str(columns),
                                                            "tables": str(tables),
                                                            "literal": str(literals),
                                                            "condition": str(conditions),
                                                            "joins": str(joins),
                                                            "func": str(functions)
                                                        }
                                                    )
                                                    
                                                except Exception as e:
                                                    db_write_log(f"SQL parsing failed: {e}", 0, "metrics_active_transactions_analysis_parse", servername, port=get_port_for_server(servername))
                                                    raw_conn.close()  
    except Exception as e:                 
                                            db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse","" )
    finally:
     

                                    db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis","" )  
                                    raw_conn.close()                                                                                    
                                    return  1
    
    p_sql_cmd = f""" 
                select MAX(row_id) row_id  , server  , query from monitoring.active_transactions where query in(select query from monitoring.metric_query_parsing )            
                group by server  , query
                """            
    try:            
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        if not df.empty:
                    for index, row in df.iterrows():
                        servername    = row['server']  
                        query         = row['query'] ,
                        transaction_type = "active_transactions"
                        row_id           = row[0]
                        # Process each row...
                        try:
                                            observed_at = get_observed_at(query)
                                            with postgres_engine.begin() as conn:                                                  
                                                conn.execute(
                                            text("update monitoring.metric_query_parsing set  observed_at = :observed_at where server = :server and query = :query"),
                                            [{"server":servername, "query":query,"observed_at":observed_at} ])
                        except Exception as e:                 
                            db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=get_port_for_server(servername) )
                        finally:
                            db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis",servername, port=get_port_for_server(servername) )  
                            raw_conn.close()                                                                                    
                                    


    finally:
            db_write_log(f"metrics_active_transactions_analysis_parse success"   ,0,"metrics_active_transactions_analysis_parse","" )  
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

def to_iso_z(value):
    if isinstance(value, datetime):
        dt = value
    else:
        try:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S.%f")
        except ValueError:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")

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
