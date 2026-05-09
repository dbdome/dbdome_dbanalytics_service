import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)


def dashboard_pattern_area(query, chart_text="Area Chart"):
        pg_home_connection_string = get_connection_string()    
        engine = create_engine(pg_home_connection_string)
        with engine.connect() as conn:
            result = conn.execute(text(query)).fetchall()

        if not result:
            return {
                "charts": {
                    "Area": {
                        "series": [],
                        "categories": [],
                        "text": chart_text
                    }
                }
            }

        columns = result[0].keys()
        categories = []
        series = []

        for row in result:
            categories.append(row[0])  # First column as category
            series.append(row[1])      # Second column as series value

        output = {
            "charts": {
                "Area": {
                    "series": series,
                    "categories": categories,
                    "text": chart_text
                }
            }
        }

        return output