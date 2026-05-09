from dotenv import load_dotenv
import os
import sys

def get_connection_string():
    load_dotenv()        
    pg_user = os.getenv("PG_USER")
    pg_password = os.getenv("PG_PASSWORD")
    pg_host = os.getenv("PG_HOST")
    pg_port = os.getenv("PG_PORT")
    pg_db = os.getenv("PG_DB")
    
    return f"postgresql://{pg_user}:{pg_password}@{pg_host}:{pg_port}/{pg_db}"

def get_ssrs_SERVER_config():
    SSRS_SERVER = os.getenv("SSRS_SERVER")
    return SSRS_SERVER

def get_ssrs_NTLM_USER():
    NTLM_USER = os.getenv("NTLM_USER")
    return NTLM_USER

def get_ssrs_NTLM_PASSWORD():
    NTLM_PASSWORD = os.getenv("NTLM_PASSWORD")
    return NTLM_PASSWORD

def get_ssrs_role_name():
    role_name = os.getenv("role_name")
    return role_name

def get_ssrs_report_path():
    report_path = os.getenv("report_path")
    return report_path

def get_public_or_ip():
    load_dotenv(os.path.join(os.path.dirname(sys.executable), ".env"))
    report_ip = os.getenv("org_ip")
    return report_ip