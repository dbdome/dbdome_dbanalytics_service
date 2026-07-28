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

def execute_synch_aggregations():
     #postgresql connection
    pg_connection_string = get_connection_string()
   
 # PostgreSQL (target)
    postgres_engine = create_engine(pg_connection_string )
    metadata = MetaData(schema="monitoring")  
 
  #postgresql connection
    pg_connection_string = get_connection_string()

    # Connect to the PostgreSQL database
    conn = psycopg2.connect(pg_connection_string)

    # Create a cursor
    cur = conn.cursor()

    # Query the view
    cur.execute("select * from agg.aggregation_routines  where is_active = true ")

    # Fetch and print rows
    rows = cur.fetchall()
    for row in rows:
        row_id      = row[0]
        aggregation_procedure_name      = row[1]                                
 
    p_sql_cmd = f"call {aggregation_procedure_name}();"
    try:
       with postgres_engine.begin() as conn:                                                  
                                   conn.execute(
                                text(p_sql_cmd))

    except Exception as e:                 
                    db_write_log(f"execute_synch_aggregations failed with error:{e}"   ,0,aggregation_procedure_name,"execute_synch_aggregations" )


 
    finally:
            db_write_log(f"metrics_actexecute_synch_aggregations success"   ,0,aggregation_procedure_name,"" )              
    return  1