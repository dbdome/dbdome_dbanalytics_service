import pyodbc
import psycopg2
from psycopg2.extras import execute_values

# ✅ 1. MSSQL connection
mssql_conn = pyodbc.connect(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=181.214.214.254,1433;"
    "DATABASE=interfaces;"
    "UID=dbdome_mon_usr;"
    "PWD=Yd2243796Anz!!"
)
mssql_cursor = mssql_conn.cursor()

# ✅ 2. Postgres connection
pg_conn = psycopg2.connect(
    host="localhost",
    dbname="dbcomp1",
    user="postgres",
    password="Yd2243796Anz!!",
    port=5432
)
pg_cursor = pg_conn.cursor()

# ✅ 3. Define source and target table
source_table = "dbo.tblclientguardians"
target_table = "public.tblclientguardians"

# ✅ 4. Read from MSSQL
mssql_cursor.execute(f"SELECT * FROM {source_table}")
rows = mssql_cursor.fetchall()

# ✅ 5. Get column names dynamically
columns = [column[0] for column in mssql_cursor.description]
columns_list = ", ".join(columns)
placeholders = ", ".join(["%s"] * len(columns))

# ✅ 6. Copy into Postgres
insert_query = f"INSERT INTO {target_table} ({columns_list}) VALUES %s"
execute_values(pg_cursor, insert_query, rows)

pg_conn.commit()

print(f"✅ Copied {len(rows)} rows from {source_table} to {target_table}")

# ✅ 7. Close connections
mssql_cursor.close()
mssql_conn.close()
pg_cursor.close()
pg_conn.close()