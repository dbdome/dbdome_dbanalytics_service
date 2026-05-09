# export_nested_report.py
import psycopg2
import json
import time
import logging
from collections import defaultdict
from psycopg2.extras import RealDictCursor
from utils.config_dotenv import  get_connection_string
from utils.log4dbexpert import db_write_log
import os
from widgets.monitoring_dashboard_pattern_table import dashboard_pattern_table
from widgets.monitoring_dashboard_pattern_gauge import dashboard_pattern_gauge
from widgets.monitoring_dashboard_pattern_column import dashboard_pattern_column
from widgets.monitoring_dashboard_pattern_line   import dashboard_pattern_line
from widgets.monitoring_dashboard_pattern_bar   import dashboard_pattern_bar
from widgets.monitoring_dashboard_pattern_area  import dashboard_pattern_area
from widgets.monitoring_dashboard_pattern_pie   import dashboard_pattern_pie

logger = logging.getLogger(__name__)

def widget_dashboard_json_export():
    try:
        logger.info("Starting WIDGET operation...")

        pg_connection_string = get_connection_string()        
        # Database connection
        conn = psycopg2.connect(pg_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)        
        # Execute query
        query = """
        select 
	    w.row_id, w.widget_name, w.widget_json_file_name, w.widget_json_file_location, w.widget_count, w.is_active, w.entry_date ,
	    WCO.row_id, WCO.widget_id, WCO.object_type, WCO.query, WCO.sequence, WCO.is_visible
        from widget.widget w
        JOIN widget.widget_chart_object WCO  ON WCO.WIDGET_ID = W.ROW_ID
		LEFT OUTER join widget.report_items_indicators rii on rii.detailfiles LIKE '%'|| w.widget_json_file_name ||'%'
        WHERE W.IS_ACTIVE = TRUE and is_visible = TRUE and w.row_id >= 2000
        ORDER BY w.widget_name  		
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        
        if not results:
            logger.warning("No data found for nested report export")
            return False
        
        for row in results:
            _row_id=row['row_id']
            _widget_name=row['widget_name']
            _widget_json_file_name=row['widget_json_file_name']
            _widget_json_file_location=row['widget_json_file_location']
            _widget_id=row['widget_id']
            _object_type=row['object_type']
            _query=row['query']        
            # Set main item properties

            match _object_type.lower():
                case "table": 
                    try:
                        result = dashboard_pattern_table(_query)
                        #db_write_log(f"dashboard_pattern_table succeeded", result ,"dashboard_pattern_table","" )                        
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_table failed with error:{e}"   , result ,"dashboard_pattern_table" ,"")
                        result = "{\"charts\": {},\"table\":[]}"                                            
                case "gauge":
                    try:
                        result = dashboard_pattern_gauge(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_gauge failed with error:{e}"   , result ,"dashboard_pattern_gauge" ,"")
                        result = "{\"charts\": {},\"table\":[]}" 
                case "column":
                    try:
                        result = dashboard_pattern_column(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_column failed with error:{e}"   , result ,"dashboard_pattern_column" ,"")
                        result = "{\"charts\": {},\"table\":[]}"    
                case "line":
                    try:
                        result = dashboard_pattern_line(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_line failed with error:{e}"   , result ,"collect_metric_activdashboard_pattern_linee_transactions" ,"")
                        result = "{\"charts\": {},\"table\":[]}"    
                case "bar":
                    try:
                        result = dashboard_pattern_bar(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_bar failed with error:{e}"   , result ,"dashboard_pattern_bar" ,"")
                        result = "{\"charts\": {},\"table\":[]}"    
                case "area":
                    try:
                        result = dashboard_pattern_area(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_area failed with error:{e}"   , result ,"dashboard_pattern_area" ,"")
                        result = "{\"charts\": {},\"table\":[]}"    

                case "pie":
                    try:
                        result = dashboard_pattern_pie(_query,os.path.splitext(_widget_name)[0])
                    except Exception as e:                 
                        db_write_log(f"dashboard_pattern_area failed with error:{e}"   , result ,"dashboard_pattern_pie" ,"")
                        result = "{\"charts\": {},\"table\":[]}"    

            result_list = result
        
        
            output_file = f"{_widget_json_file_location}/{_widget_json_file_name}"
        
        # Save to JSON file
            with open(output_file, 'w', encoding='utf-8') as json_file:
                json.dump(result_list, json_file, indent=2, default=str, ensure_ascii=False)
        
        # Also save as latest version
        #latest_file = "reports/nested_report_structure_latest.json"
        #with open(latest_file, 'w', encoding='utf-8') as json_file:
        #    json.dump(result_list, json_file, indent=2, default=str, ensure_ascii=False)
        
        # Log success
        total_items = len(result_list)
        total_indicators = sum(len(item['indicators']) for item in result_list)
        
        logger.info(f"Nested report export completed successfully")        
        logger.info(f"Report items: {total_items}, Total indicators: {total_indicators}")
        
        return True
        
    except psycopg2.Error as db_error:
        logger.error(f"export_nested_report_operation: {db_error}")
        db_write_log(f"export_nested_report_operation error:{db_error}"   ,0,"export_nested_report_operation" , "" )
        return False
    except Exception as e:
        db_write_log(f"export_nested_report_operation error:{e}"   ,0,"export_nested_report_operation" , "" )
        return False
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
