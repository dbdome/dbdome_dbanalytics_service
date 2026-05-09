import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
import json
from pathlib import Path

def save_servers():
    # Load JSON data from file
    file_path = Path("server_data.json")
    if file_path.exists():
        with open("server_data.json", "r") as f:
            data = json.load(f)
            _server_name    = data.get("server_name")
            _ip_address     = data.get("ip_address")
            _port           = data.get("port")
            _db_vendor      = data.get("db_vendor")
            _db_version     = data.get("db_version")
            _auth_type      = data.get("auth_type")
            _user           = data.get("user")
            _password        = data.get("password")
            _add_delete_modify  = data.get("add_dmodify_delete")
        
            delete_file("server_data.json" )

        pg_connection_string = get_connection_string()
        
    
        # ========== 2. Create SQLAlchemy Engines ==========
        # SQL Server (source)
        
        postgres_engine = create_engine(pg_connection_string )
        metadata = MetaData(schema="monitoring")          
        try:
            # Parameters

            # Call the procedure using bind parameters
            

            with postgres_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.upsert_monitored_server(
                :p_ip_address,
                :p_port ,                                   
                :p_server_name,
                :p_db_vendor,
                :p_db_version,
                :p_auth_type,
                :p_username,
                :p_password , 
                :p_add_modify_delete
            )
        """), {
            "p_ip_address": _ip_address,
            "p_port": _port,
            "p_server_name":_server_name ,
            "p_db_vendor": _db_vendor,
            "p_db_version": _db_version,
            "p_auth_type": _auth_type,
            "p_username": _user,
            "p_password": _password,
            "p_add_modify_delete": _add_delete_modify
        })

        except Exception as e:                 
                        db_write_log(f"save_servers failed with error:{e}"   ,0,"save_servers",_server_name , port=_port)
        finally:
                print("✅ save_servers Data sync complete.")               
                return  1
        return 0;
    else:
          return 0;

def delete_file(_file_nanme):      

    file_path = Path(_file_nanme)
    
    try:
        if file_path.exists():
                file_path.unlink()
                print(f"File {_file_nanme}deleted.")
        else:
                print(f"File {_file_nanme} not found.")
    except FileNotFoundError: 
        print("Permission denied.")    
    return 0;
    


def save_mail():
    # Load JSON data from file
    file_path = Path("mail_config.json")
    if file_path.exists():
        with open("mail_config.json", "r") as f:
            data = json.load(f)
            _mail_server    = data.get("mail_server")
            _port           = data.get("port")
            _mail_sender    = data.get("mail_sender")
            _mail_username  = data.get("mail_user")
            _mail_password  = data.get("mail_password")
            _recipients     = data.get("recipients")                    
            delete_file("mail_config.json" )

        pg_connection_string = get_connection_string()
        
    
        # ========== 2. Create SQLAlchemy Engines ==========
        # SQL Server (source)
        
        postgres_engine = create_engine(pg_connection_string )
        metadata = MetaData(schema="monitoring")          
        try:
            # Parameters

            # Call the procedure using bind parameters
            

            with postgres_engine.begin() as conn:
                conn.execute(text("""                    
            call mail.update_mail_service
            (
                :p_mail_server, 
                :p_mail_sender, 
                :p_port , 
                :p_username , 
                :p_mail_password,
                :p_mail_recipients                                  
)
        """), {
            "p_mail_server" :_mail_server,            
            "p_mail_sender" :_mail_sender,
            "p_port"        :_port,
            "p_username":_mail_username , 
            "p_mail_password": _mail_password,
            "p_mail_recipients"   :_recipients

        })

        except Exception as e:                 
                        db_write_log(f"save_servers failed with error:{e}"   ,0,"save_servers","" )
        finally:
                print("✅ save_servers Data sync complete.")               
                return  1
        return 0;
    else:
          return 0;

def delete_file(_file_nanme):      

    file_path = Path(_file_nanme)
    
    try:
        if file_path.exists():
                file_path.unlink()
                print(f"File {_file_nanme}deleted.")
        else:
                print(f"File {_file_nanme} not found.")
    except FileNotFoundError: 
        print("Permission denied.")    
    return 0;