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

def metrics_category_definitions():
    # PostgreSQL connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)
    metadata = MetaData(schema="monitoring")
    raw_conn = postgres_engine.raw_connection()

    p_sql_cmd_category_definition = """
        select widget_json_file_location || '/'||widget_json_file_name file_name   from widget.widget   where lower(widget_name) = 'categorydefinitions.json'
    """

    try:
        df = pd.read_sql_query(p_sql_cmd_category_definition, con=postgres_engine)
        if df.empty:
            print("⚠️ No category queries found.")
            return

        for _, row in df.iterrows():
            file_name    = row["file_name"]
        CategoryDefinitions = []  # collect all advisories here



        p_sql_servers_cmd = """
        select server name  , db_vendor dbtype   , db_version version   from metrics.servers  where is_active =true
        """


        df = pd.read_sql_query(p_sql_servers_cmd, con=postgres_engine)
        if df.empty:
            print("⚠️ No category queries found.")
            return
        servers = []
        for _, row in df.iterrows():
            name            = row['name']
            dbType          = row['dbtype']
            version         = row['version']                        
            # Execute main query
            servers.append({
                    "name":   f"{name}", 
                    "dbType": f"{dbType}", 
                    "version": f"{version}"
            })
        
        
        config = []
        config.append(
              {
                "name": "Configuration Screen",            
                "aliases": ["config", "admin", "settings"],
                "id": "config", 
                "url": "/config",
                "parent_url": "/"
              })
        config.append(
    {
        "name": "Configuration Screen",
        "aliases": ["config", "admin", "settings"],
        "id": "config", 
        "url": "/config",
        "parent_url": "/"
    }              )
        config.append(
{
        "name": "Server Monitoring Configuration",
        "aliases": ["server monitoring", "server config", "monitor setup", "server settings"],
        "id": "config-server-monitoring",
        "url": "/config/server-monitoring",
        "parent_url": "/config"
    })
        
        config.append({
        "name": "Notification Settings for Alerts and Reports",
        "aliases": ["email settings", "config email", "configure email", "configure reports", "alert settings", "notification settings", "email config", "report settings", "email alert"],
        "id": "config-email",
        "url": "/config/email",
        "parent_url": "/config"
    })
        config.append(
        {
        "name": "Support Contact Information on the Config Screen",
        "aliases": ["support info", "technical support", "contact support", "customer support", "billing support", "help desk"],
        "id": "config-support",
        "url": "/config",
        "parent_url": "/config"
        })
        config.append(
        {
        "name": "License Key Form", 
        "aliases": ["license", "subscription", "billing", "account details", "plan details", "upgrade"],
        "id": "config-license",
        "url": "/config/license", 
        "parent_url": "/config"
    })
        

        p_sql_domains_cmd = """
        select  Id , name , Icon , description from widget.domains order by Id
        """

    
        df = pd.read_sql_query(p_sql_domains_cmd, con=postgres_engine)
        if df.empty:
            print("⚠️ No category queries found.")
            return
        domains = []
        for _, row in df.iterrows():
            id            = row["id"]
            name          = row["name"]
            icon          = row["icon"]                        
            description   = row["description"]                        
            # Execute main query
            domains.append({
                     "id": f"{id}",
                     "name": f"{name}",
                    "icon": f"{icon}",
                    "description": f"{description}"
            })
        


        p_sql_areas_cmd = """
        select  d.id || a.Id id , a.name , a.Icon , a.description from widget.areas a 
        join widget.domains d on d.id = a.domain_id
        order by a.sequence , a.Id
        """

    
        df = pd.read_sql_query(p_sql_areas_cmd, con=postgres_engine)
        if df.empty:
            print("⚠️ No category queries found.")
            return
        areas = []
        for _, row in df.iterrows():
            id            = row["id"]
            name          = row["name"]
            icon          = row["icon"]                        
            description   = row["description"]                        
            # Execute main query
            areas.append({
                     "id": f"{id}",
                     "name": f"{name}",
                    "icon": f"{icon}",
                    "description": f"{description}"
            })
        
        
        p_sql_categories_cmd = """
        select c.domain_id|| c.area_id || c.id id  , c.name , c.Icon , c.description  from widget.categories c
        order by sequence , id
        """
        
    
        df = pd.read_sql_query(p_sql_categories_cmd, con=postgres_engine)
        if df.empty:
            print("⚠️ No category queries found.")
            return
        categories = []
        for _, row in df.iterrows():
            id            = row["id"]
            name          = row["name"]
            icon          = row["icon"]                        
            description   = row["description"]                        
            # Execute main query
            categories.append({
                     "id": f"{id}",
                     "name": f"{name}",
                    "icon": f"{icon}",
                    "description": f"{description}" , 
                    "detailFiles": getdetailfilesbycategory(id)
            })
            
        CategoryDefinition = {                    
                    "servers"   :servers , 
                    "config"    :config  , 
                    "domains"   :domains , 
                    "areas"     :areas , 
                    "categories":categories

                }

                
        



        
        # Save all advisories into one JSON file
        output_file = file_name
        with open(output_file, "w") as f:
            json.dump(CategoryDefinition, f, indent=4, default=str)

        print(f"✅ Saved {len(CategoryDefinitions)} advisories to {output_file}")

    except Exception as e:
        db_write_log(f"metrics_category_definitions failed with error: {e}", 0, "metrics_category_definitions", "")
    finally:
        raw_conn.close()
        db_write_log("metrics_category_definitions finished successfully", 0, "metrics_category_definitions", "")

    return 1


def getdetailfilesbycategory(category_id):
    engine = create_engine(get_connection_string())
    raw_conn = engine.raw_connection()

    try:
        sql = text("""
            SELECT 
                cdf.detailfile,
                c.domain_id || c.area_id || c.id AS category_code
            FROM widget.category_detailfiles cdf
            JOIN widget.categories c 
              ON c.row_id = cdf.category_row_id 
            WHERE c.domain_id || c.area_id || c.id = :category_id
        """)

        df = pd.read_sql_query(sql, con=engine, params={"category_id": category_id})

        # Convert 'detailfile' column to list
        detail_files = df['detailfile'].tolist() if not df.empty else []
        return detail_files

    except Exception as e:
        print(f"Error in getdetailfilesbycategory: {e}")
        return []

    finally:
        raw_conn.close()