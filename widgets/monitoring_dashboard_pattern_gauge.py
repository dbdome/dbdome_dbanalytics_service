import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)

def dashboard_pattern_gauge(query,gauge_text):
    
    pg_home_connection_string = get_connection_string()
    engine = create_engine(pg_home_connection_string)
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchone()
        if result:
            gauge_percentage = result[0]            
            return {
                "charts": {
                    "Gauge": {
                        "percent": gauge_percentage,
                        "text": gauge_text
                    }
                }
            }
        else:
            return {
                "charts": {
                    "Gauge": {
                        "percent": None,
                        "text": "No data"
                    }
                }
            }