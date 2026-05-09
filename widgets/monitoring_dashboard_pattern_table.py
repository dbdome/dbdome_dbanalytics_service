import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string

logger = logging.getLogger(__name__)

def dashboard_pattern_table (query: str ) -> dict:


    logger.info("Starting nested report export operation...")

    pg_connection_string = get_connection_string()        
        # Database connection
    conn = psycopg2.connect(pg_connection_string)
    
    
    cursor = conn.cursor()

    # Execute the query
    cursor.execute(query)
    
    # Fetch column names
    columns = [column[0] for column in cursor.description]
    
    # Fetch all rows and convert them to dictionaries
    table_data = []
    for row in cursor.fetchall():
        row_dict = {}
        for col, val in zip(columns, row):
            # Format datetime if needed
            if isinstance(val, datetime):
                val = val.isoformat(timespec='milliseconds')
            row_dict[col] = val
        table_data.append(row_dict)

    # Final JSON structure
    result = {
        "charts": {},
        "table": table_data
    }

    cursor.close()
    conn.close()
    return result



