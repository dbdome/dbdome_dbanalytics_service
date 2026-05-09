import psycopg2
import json
from datetime import datetime
import logging
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import  get_connection_string
import json
from sqlalchemy import create_engine, text


logger = logging.getLogger(__name__)


def dashboard_pattern_bar(query, chart_text="Bar Chart"):
    pg_home_connection_string = get_connection_string()    
    engine = create_engine(pg_home_connection_string)
    with engine.connect() as conn:
        result = conn.execute(text(query)).fetchall()
        columns = result[0].keys() if result else []

        if not result or len(columns) < 2:
            return {
                "charts": {
                    "Bar": {
                        "series": [],
                        "categories": [],
                        "text": chart_text
                    }
                }
            }

        # First column is categories, others are series
        categories = []
        series_dict = {col: [] for col in columns[1:]}  # skip category column

        for row in result:
            categories.append(row[0])  # first column as category
            for idx, col in enumerate(columns[1:], start=1):
                series_dict[col].append(row[idx])

        # Build series list as required
        bar_series = []
        for name, data in series_dict.items():
            bar_series.append({
                "name": name,
                "data": data
            })

        output = {
            "charts": {
                "Bar": {
                    "series": bar_series,
                    "categories": categories,
                    "text": chart_text
                }
            }
        }

        return output