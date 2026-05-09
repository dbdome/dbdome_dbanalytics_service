import psycopg2
import pandas as pd
from utils.config_dotenv import get_connection_string
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.log4dbexpert import db_write_log
from datetime import datetime, timezone
import json
from pathlib import Path

def issue_root_causes():
    category_definitions();
    issue_rootcause_workflow();  


def issue_rootcause_workflow():
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)
    metadata = MetaData(schema="monitoring")
    raw_conn = postgres_engine.raw_connection()
    data_folder                 = None
    issue_id                    = None   
    issue_file_name             = None
    try: 
        p_sql_cmd = f"""      
                select  value  from config.global_params where key = 'DasboardData_folder'            
                """
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            return
        data_folder = None
        for _, row in df.iterrows():            
                        data_folder  = row[0]
        
        p_sql_cmd = f"""      
                select 
                    distinct issue_id 
                    from monitoring.v_rootcauses 
                    order by issue_id
                """
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            return
        
        for _, row in df.iterrows():            
                        issue_id  = row[0]
                        issue_file_path = Path(data_folder) / f"{issue_id}.json"                                             
                        cur = raw_conn.cursor()
                        cur.execute(
                            "SELECT monitoring.build_flowchart(%s)",
                            (issue_id,)
                        )
                        
                        result = cur.fetchone()

                        if not result or not result[0]:
                            continue

                        final_json = result[0]
                   
                        with open(issue_file_path, "w", encoding="utf-8") as f:
                            json.dump(final_json, f, indent=4)

                        print(f"File created at: {issue_file_path}")
 
                        cur.close()

    except Exception as e:
        db_write_log(f"category_definitions failed with error: {e}", 0, "category_definitions", "")

    finally:
        db_write_log("category_definitions finished successfully", 0, "category_definitions", "")





def category_definitions():
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)
    metadata = MetaData(schema="monitoring")
    raw_conn = postgres_engine.raw_connection()
    category_definitions_folder = None
    try: 
        p_sql_cmd = f"""      
            select value from config.global_params where key = 'CategoryDefinitions.json_path'
            """
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            return
        
        for _, row in df.iterrows():            
                category_definitions_folder          = row[0]
        folder = Path(category_definitions_folder)   # or "/home/user/output"
        category_definitions_filename = "CategoryDefinitions.json"    
        full_path = folder / category_definitions_filename   # This safely concatenates

        # Make sure folder exists
        folder.mkdir(parents=True, exist_ok=True)
        cur = raw_conn.cursor()
        cur.execute("""
                        select id, name, icon, severity ,description  from rootcause.issue_domains
                        
                    """)
        domains = [
        {
            "id": r[0],
            "name": r[1],
            "icon": r[2],
            "severity": int(r[3]),
            "status": get_traffic_light(r[0]),
            "trafficLight": get_traffic_light(r[0]),
            "advisoryCount": get_advisory_count(r[0])
        }
        for r in cur.fetchall()
        ]

# ---- Areas ----
        cur.execute("""
		SELECT a.id, a.name, a.icon , d.severity FROM rootcause.issue_areas a
			join  rootcause.issue_domains d on a.id like '%'||d.id || '%'        
                    
        """)
        areas = [
        {
            "id": r[0],
            "name": r[1],
            "icon": r[2],
            "severity": r[3],
            "status": get_traffic_light(r[0]),
            "trafficLight": get_traffic_light(r[0])        
        }
        for r in cur.fetchall()
    ]

        # ---- Categories ----
        cur.execute("""
            SELECT distinct c.id, c.name, c.icon  , d.severity  , p.issue_id
            FROM rootcause.issue_categories c
			join (select distinct issue_id  , category_id   from rootcause.issue_patterns) p on p.category_id = c.id		
            join  rootcause.issue_domains d on c.id like '%'||d.id || '%' 
			join  ( select distinct metric_name from  monitoring.general_metric_metadata_results ) r on r.metric_name  like  '%'||p.issue_id ||'%'

        """)
        categories = [
        {
        "id": r[0],
        "name": r[1],
        "icon": r[2],
        "severity": r[3],
        "status":   get_traffic_light(r[0]),
        "trafficLight": get_traffic_light(r[0]),
       "detailFiles": [
    r[4] if r[4].endswith(".json") else f"{r[4]}.json"
] if r[4] else []
    }
        for r in cur.fetchall()
    ]

    # ---- Servers ----
        cur.execute("""
		        SELECT server
        		    FROM metrics.servers where is_active is true
        """)
        servers = [r[0] for r in cur.fetchall()]

# =========================
# BUILD FINAL JSON
# =========================

        final_json = {
        "adminConsoleURL": f"http://{get_local_ip()}:8000/admin",
        "domains": domains,
        "areas": areas,
        "categories": categories,
        "servers": servers
        }



        with open(full_path, "w", encoding="utf-8") as f:
                json.dump(final_json, f, indent=4)

        print(f"File created at: {full_path}")

    except Exception as e:
            db_write_log(f"category_definitions failed with error: {e}", 0, "category_definitions", "")
    finally:           
            db_write_log("category_definitions finished successfully", 0, "category_definitions", "")



def to_iso_z(value):
    if isinstance(value, datetime):
        dt = value
    else:
        try:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S.%f")
        except ValueError:
            dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")

def get_traffic_light(_id):
     return "green";

def get_advisory_count(_id):        
        return "green"

def get_local_ip():
    _local_ip = None
    try:
        pg_connection_string = get_connection_string()
        postgres_engine = create_engine(pg_connection_string)
        metadata = MetaData(schema="monitoring")
        raw_conn = postgres_engine.raw_connection()
        p_sql_cmd = f"""      
            select value from config.global_params where key = 'local_ip'
            """
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            return
        for _, row in df.iterrows():            
            _local_ip =  row["value"]
    except Exception as e:
        db_write_log(f"get_local_ip failed with error: {e}", 0, "get_local_ip", "")
    finally:
        raw_conn.close()
        db_write_log("get_local_ip finished successfully", 0, "get_local_ip", "")

    return _local_ip
