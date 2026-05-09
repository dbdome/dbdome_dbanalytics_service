import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)


def dashboard_pattern_pie( query, chart_text=""):
    pg_home_connection_string = get_connection_string()    
    engine = create_engine(pg_home_connection_string)
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchall()

        if not result:
            return {
                "charts": {
                    "Pie": {
                        "series": [],
                        "labels": [],
                        "text": chart_text
                    }
                }
            }

        # Assuming query returns two columns: label, value
        labels = []
        series = []

        for row in result:
            labels.append(row[0])
            series.append(row[1])

        output = {
            "charts": {
                "Pie": {
                    "series": series,
                    "labels": labels,
                    "text": chart_text
                }
            }
        }

        return output
