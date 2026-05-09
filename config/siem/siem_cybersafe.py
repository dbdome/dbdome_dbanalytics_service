import psycopg2
import pandas as pd
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
from sqlalchemy import create_engine, func , text
import requests
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert

def siem_cybersafe( _source , _severity , _message ,_time ):

    # PostgreSQL (target)
    pg_connection_string = get_connection_string()
    try:      
        postgres_engine = create_engine(pg_connection_string )
        metadata = MetaData(schema="config")  
        raw_conn = postgres_engine.raw_connection()    
        p_sql_cmd = f""" 
            select siem_url ,app_key from config.sime_interface where siem_interface_name = 'cybersafe'
            """                
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if not df.empty:          
                for index, row in df.iterrows():
                    app_key         = row['app_key'] ,
                    siem_url        = row['siem_url']                     
                alert_payload = {
                "source": _source,
                "severity": _severity,
                "message": _message,
                "timestamp": _time
                }
                headers = {"Authorization": f"Bearer {app_key}", "Content-Type": "application/json"}  
                r = requests.post(siem_url, json=alert_payload, headers=headers)
                db_write_log(
                    f"report: {r.status_code}",
                    r.text,
                    "siem_cybersafe"
        )
    except:
        r = requests.post(siem_url, json=alert_payload, headers=headers)
        db_write_log(
                f"failed to post report: {r.status_code}",
                r.text,
                "siem_cybersafe"
        )

    



   
                
