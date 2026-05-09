#monitored_servers_routines
from utils.config_dotenv import get_connection_string
import psycopg2

#postgresql connection
pg_connection_string = get_connection_string()

# Connect to the PostgreSQL database
conn = psycopg2.connect(pg_connection_string)

# Create a cursor
cur = conn.cursor()

# Query the view
cur.execute("select * from metrics.v_servers_routines_active")

# Fetch and print rows
rows = cur.fetchall()
for row in rows:
    row_id      = row[0]
    server      = row[1]
    servername  = row[2]
    database    = row[3]
    username    = row[4]
    password    = row[5]
    driver      = row[6]
    routine_name= row[7]
    

# Clean up
cur.close()
conn.close()

