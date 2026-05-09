import psycopg2
from utils.log4dbexpert import db_write_log
from jobs.job_handler  import job_update_next_run_time
from jobs.job_handler  import job_history_write
from utils.config_dotenv import get_connection_string

def add_registered_processes():
    #postgresql connection
    try:
        pg_connection_string = get_connection_string()

        # Connect to the PostgreSQL database
        conn = psycopg2.connect(pg_connection_string)

        # Create a cursor
        cur = conn.cursor()

        # Query the view
        cur.execute("select process_name  , interval from metrics.registered_processes where is_active=true")
        results = cur.fetchall()
        conn.close()
        return results
                    
        # Clean up
        cur.close()
        conn.close()
    except Exception as e:                 
                    db_write_log(f"add_registered_processes failed with error:{e}", 0, "add_registered_processes", "")
     
    

