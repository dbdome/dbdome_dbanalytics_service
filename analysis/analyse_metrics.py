from analysis.analyse_metrics_active_transactions    import metrics_active_transactions_analysis
from analysis.analyse_metrics_active_sessions        import metrics_active_sessions_analysis
from analysis.analyse_metrics_sql_injection          import metrics_sql_injection_analysis
from analysis.analyse_metrics_sensitive_column_access import metrics_sensitive_column_access_analysis
from analysis.analyse_mssql_unification              import metrics_sql_unification
from analysis.analyse_custom_metrics                 import metrics_custom_metrics_analysis
from analysis.analyse_user_risk                      import run_user_risk_scoring
#from analysis.analyse_threats                        import metrics_analyse_threats
import psycopg2
from utils.log4dbexpert import db_write_log

def analyse_metrics_operation():
    try:
        result = metrics_active_transactions_analysis()
        db_write_log(f"Function succeeded", result ,"metrics_active_transactions_analysis","" )                
    except Exception as e:                 
        db_write_log(f"metrics_active_transactions_analysis failed with error:{e}"   , result ,"metrics_active_transactions_analysis" ,"")
        result = 0
    try:
        
        
        db_write_log(f"Function succeeded", result ,"metrics_sql_unification","" )                
    except Exception as e:                 
        db_write_log(f"metrics_custom_metrics_analysis failed with error:{e}"   , result ,"metrics_custom_metrics_analysis" ,"")
        result = 0
    finally:
        result = 1
        db_write_log(f"Function succeeded", result ,"metrics_sql_unification" ,"")

    try:
        run_user_risk_scoring()
    except Exception as e:
        db_write_log(f"run_user_risk_scoring failed with error:{e}", 0, "analyse_metrics_operation", "")

    try:
        metrics_sensitive_column_access_analysis()
    except Exception as e:
        db_write_log(f"metrics_sensitive_column_access_analysis failed with error:{e}", 0, "analyse_metrics_operation", "")
