from sqlalchemy import create_engine, text
import pandas as pd
import pyodbc
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
#sel server connection
server = '192.168.68.116,5050'
database = 'DBDOME'
username = 'dbdome_usr'
password = 'Yd2243796Anz!!'
driver = 'ODBC Driver 17 for SQL Server'


#postresql connection string 
connection_string = f"postgresql+psycopg2://{username}:{password}@{server}/{database}?driver={driver}"
# PostgreSQL connection

pg_username  = 'dbdome_adm'
pg_password  = 'Yd2243796Anz!!'
pg_host      = 'dbdome-pg_ubuntu'
pg_port      =  '5432'
pg_dbname    =  'dbdome_202504'
pg_connection_string = f"postgresql+psycopg2://{pg_username}:{pg_password}@{pg_host}:{pg_port}/{pg_dbname}?driver={driver}"
postgres_engine = create_engine(pg_connection_string , echo  = True)



# Create the connection string
connection_string = f"mssql+pyodbc://{username}:{password}@{server}/{database}?driver={driver}"

# Create engine
engine = create_engine(connection_string, echo=True)


# Construct the dynamic SQL
query = f"""
SELECT 
    '{server}' AS server_name,
    der.session_id,
    der.blocking_session_id,
    DATEDIFF(second, der.start_time, GETDATE()) AS durationInSec,
    DB_NAME(der.database_id) AS database_name,
    der.start_time,
    ses.last_request_end_time,
    ses.open_transaction_count,
    ses.cpu_time,
    der.command,
    der.logical_reads,
    der.reads,
    der.writes,
    der.percent_complete,
    der.wait_type,
    der.last_wait_type,
    ses.login_name,
    ses.program_name AS program_name,
    ses.host_name,
    t.text,
    CONVERT(decimal(28, 1), migs.avg_total_user_cost * migs.avg_user_impact * 
        (migs.user_seeks + migs.user_scans)) AS improvement_measure,
    mid.equality_columns,
    mid.statement,
    'CREATE INDEX IX_' + 
        CONVERT(varchar, mig.index_group_handle) + '_' + 
        CONVERT(varchar, mid.index_handle) + ' ON ' + 
        mid.statement + 
        ' (' + 
        ISNULL(mid.equality_columns, '') + 
        CASE 
            WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
            THEN ',' 
            ELSE '' 
        END + 
        ISNULL(mid.inequality_columns, '') + 
        ')' + 
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') 
        AS create_index_statement
FROM 
    {database}.sys.dm_exec_requests der
INNER JOIN 
    {database}.sys.dm_exec_sessions ses 
    ON der.session_id = ses.session_id
LEFT OUTER JOIN 
    {database}.sys.dm_db_missing_index_groups mig 
    ON 1 = 1
LEFT OUTER JOIN 
    {database}.sys.dm_db_missing_index_group_stats migs 
    ON migs.group_handle = mig.index_group_handle
LEFT OUTER JOIN 
    {database}.sys.dm_db_missing_index_details mid 
    ON mig.index_handle = mid.index_handle
CROSS APPLY 
    {database}.sys.dm_exec_sql_text(der.sql_handle) t
CROSS APPLY 
    {database}.sys.dm_exec_query_plan(der.plan_handle) cp
"""

# Run the query and fetch results
with engine.connect() as conn:
    result = conn.execute(text(query))
    for row in result:
        print(row)