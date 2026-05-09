import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)

def dashboard_pattern_line( query, chart_text="Line Chart"):
    pg_home_connection_string = get_connection_string()    
    engine = create_engine(pg_home_connection_string)
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchall()
        columns = result[0].keys() if result else []

        # Assuming first column is category, others are series
        categories = []
        series_dict = {col: [] for col in columns[1:]}  # skip category column

        for row in result:
            categories.append(row[0])  # first column as category
            for idx, col in enumerate(columns[1:], start=1):
                series_dict[col].append(row[idx])

        # Build complex series array
        complex_series = []
        for name, data in series_dict.items():
            complex_series.append({
                "name": name,
                "data": data
            })

        output = {
            "charts": {
                "Line": {
                    "categories": categories,
                    "series": complex_series,
                    "text": chart_text
                }
            }
        }

        return output