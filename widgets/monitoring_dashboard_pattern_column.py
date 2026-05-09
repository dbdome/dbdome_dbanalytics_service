import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)

def dashboard_pattern_column(query,chart_text="Chart data"):
    
    pg_home_connection_string = get_connection_string()    
    engine = create_engine(pg_home_connection_string)
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchall()
        # Process results into categories and series arrays
        categories = []
        series = []

        for row in result:
            categories.append(row[0])
            series.append(row[1])

        # Build JSON
        output = {
            "charts": {
                "Column": {
                    "series": series,
                    "categories": categories,
                    "text": chart_text
                }
            }
        }
    return output