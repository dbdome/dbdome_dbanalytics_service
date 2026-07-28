import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
try:
    from analysis.self_activity_filter import filter_excluded_logins as _dbdome_filter_excluded_logins
except Exception:
    def _dbdome_filter_excluded_logins(df, *a, **k):
        return df
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse
import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders

def collect_metric_active_transactions(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver , auth_type , mssql_port=None):
    server = mssql_server
    servername = mssql_servername
    database = mssql_database or "master"
    username = mssql_username
    password = mssql_password
    #driver = "ODBC Driver 17 for SQL Server"
    # Get the list of installed ODBC drivers
    installed_drivers = pyodbc.drivers()
    print("Installed drivers:", installed_drivers)

    # Define priority list
    priority = ["ODBC Driver 18 for SQL Server",
            "ODBC Driver 17 for SQL Server",
            "SQL Server"]

    # Select the first available driver by priority
    selected_driver = next((d for d in priority if d in installed_drivers), None)

    if selected_driver is None:
        raise RuntimeError("No suitable ODBC driver found!")

    print("Selected driver:", selected_driver)


    driver =selected_driver
    server_with_port = f"{servername},{mssql_port}" if mssql_port else servername
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={database or 'master'};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={database or 'master'};
            UID={username};
            PWD={password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    #params = quote_plus(odbc_str)

    # Create the connection string
    
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)

    #connection_string = f"mssql+pyodbc:///?odbc_connect={params}"


    #postgresql connection
    pg_connection_string = get_connection_string()



    # ========== 1. Define SQLAlchemy Model ==========
    Base = declarative_base()

    class active_transactions(Base):
        __tablename__ = 'monitoring.active_transactions'  
        server                  = Column(String)
        session_id              = Column(Integer)
        blocking_session_id     = Column(Integer)
        duration_secs           = Column(Integer)
        database_name           = Column(String)
        start_time              = Column(DateTime  , primary_key=True)
        last_request_end_time   = Column(DateTime)
        open_transaction_count  = Column(Integer)
        cpu_time                = Column(Integer)
        command                 = Column(String)
        logical_reads           = Column(Integer)
        reads                   = Column(Integer)
        writes                  = Column(Integer)
        wait_type               = Column(String)
        last_wait_type          = Column(String)
        login_name              = Column(String)
        program_name            = Column(String)
        host_name               = Column(String)
        query                   = Column(String)

    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    sql_server_engine = create_engine(connection_string )
    # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")
    

    
    try:
        raw_conn = sql_server_engine.raw_connection()
        cursor = raw_conn.cursor()
        cursor.execute("SELECT name FROM sys.databases")
        for row in cursor.fetchall():
            p_dbname = row[0]
            p_sql_cmd = f""" 
                SELECT '{servername}' server,
                    der.session_id session_id,         
                    der.blocking_session_id blocking_session_id,          
                    DATEDIFF(second, der.start_time, GETDATE()) AS duration_secs,          
                    DB_NAME(der.database_id) AS database_name,          
                    der.start_time ,           
                    ses.last_request_end_time,          
                    ses.open_transaction_count,          
                    ses.cpu_time,          
                    der.command,          
                    der.logical_reads,          
                    der.reads,          
                    der.writes,          
                    der.wait_type,          
                    der.last_wait_type,          
                    ses.login_name,          
                    ses.program_name AS program_name,          
                    ses.host_name,      
                    t.text query          
                FROM {p_dbname}.sys.dm_exec_requests der          
                INNER JOIN {p_dbname}.sys.dm_exec_sessions ses ON der.session_id = ses.session_id          
                CROSS APPLY {p_dbname}.sys.dm_exec_sql_text(der.sql_handle) t            
                CROSS APPLY {p_dbname}.sys.dm_exec_query_plan(der.plan_handle) cp            
                WHERE der.session_id > 50
            """
            vraw_conn = sql_server_engine.raw_connection()
            try:
                df = pd.read_sql_query(p_sql_cmd, con=vraw_conn)
                df = _dbdome_filter_excluded_logins(df)
                # ========== 4. Bulk UPSERT into PostgreSQL ==========                
                with postgres_engine.begin() as conn:                                                                      
                    conn.execute(
                        text("INSERT INTO monitoring.active_transactions (server, session_id, blocking_session_id, duration_secs,database_name, start_time , last_request_end_time, open_transaction_count, cpu_time,command, logical_reads,reads, writes,wait_type, last_wait_type,login_name,  program_name, host_name , query   ) \
                        VALUES \
                        (:server, :session_id, :blocking_session_id, :duration_secs,:database_name, :start_time , :last_request_end_time, :open_transaction_count, :cpu_time,:command, :logical_reads,:reads, :writes,:wait_type, :last_wait_type,:login_name, :program_name, :host_name , :query   )"),
                        [{"server":row[0], "session_id":row[1], "blocking_session_id":row[2], "duration_secs":row[3],"database_name":row[4], "start_time":row[5] , "last_request_end_time":row[6], "open_transaction_count":row[7], "cpu_time":row[8],"command":row[9], "logical_reads":row[10],"reads":row[11], "writes":row[12],"wait_type":row[13], "last_wait_type":row[14],"login_name":row[15], "program_name":row[16], "host_name":row[17] , "query":row[18]     } for row in df.itertuples(index=False)]

                        )
            except Exception as e:                 
                    db_write_log(f"collect_metric_mssql_latency failed with error:{e}"   ,0,"collect_metric_active_transactions"  , servername, port=mssql_port)
            finally:
                vraw_conn.close()            

    except Exception as e:                 
                db_write_log(f"collect_metric_active_transactions failed with error:{e}{connection_string}"   ,0,"login_failure"  , servername, port=mssql_port)
    finally:
            db_write_log(f"collect_metric_active_transactions success"   ,0,"login_failure"  , servername, port=mssql_port)
            raw_conn.close()
    return  1
    return 0;


    def sql_parse (query):
        try:
                                            expression = sqlglot.parse(query)
                                            # Find all columns
                                            try:    
                                                columns     =  [col.name for col in expression[0].find_all(expression[0].Column)]                                            
                                            except AttributeError  as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse columns failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=mssql_port)
                                                columns = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_tables = expression[0].find_all(exp.Table)  # or just Table
                                                    tables = [table.name for table in all_tables if hasattr(table, 'name') and table.name]
                                                else:
                                                    tables = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse tables failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                tables = []
                                            try:
                                                if expression and len(expression) > 0:
                                                    all_literals = expression[0].find_all(exp.Literal)  # or just Literal
                                                    literal = [lit.name for lit in all_literals if hasattr(lit, 'name') and lit.name]
                                                else:
                                                    literal = []
                                            except (AttributeError, IndexError, TypeError) as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse literal failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                literal = []                                            

                                            try:
                                                condition = [cond.name for cond in expression[0].find_all(exp.Condition) if hasattr(cond, 'name')]                                    
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse condition failed with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                condition = []                                            
                                            try:
                                                join = [j.name for j in expression[0].find_all(exp.Join) if hasattr(j, 'name')]                                                                        
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed join with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                join = []                               
                                                                                        
                                            try:
                                                func = [f.name for f in expression[0].find_all(exp.Func) if hasattr(f, 'name')]                                                                                                             
                                            except AttributeError as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed func with error:{e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                func = []
                                            
                                            with postgres_engine.begin() as conn:                                                  
                                                conn.execute(
                                                text("INSERT INTO monitoring.metric_query_parsing ( server ,query_id ,query,observed_at ,columns, tables, literal,condition,joins,func  , table_name) VALUES (:server ,:query_id ,:query,:observed_at ,:columns, :tables, :literal,:condition,:joins,:func,:table_name)"),
                                                [{"server":servername, "transaction_type":transaction_type , "query_id":row_id,"query":query,"observed_at":observed_at,"columns":columns,"tables":tables,"literal":literal,"condition":condition,"joins":join , "func":func,"table_name":table_name}]
                                                );
                                        
                                                

        except Exception as e:                 
                                                db_write_log(f"metrics_active_transactions_analysis_parse failed with error:{e}"   ,0,"metrics_active_transactions_analysis_parse",servername, port=mssql_port)
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
                                                    db_write_log(f"SQL parsing failed: {e}", 0, "metrics_active_transactions_analysis_parse", servername, port=mssql_port)
                                                    raw_conn.close()  

