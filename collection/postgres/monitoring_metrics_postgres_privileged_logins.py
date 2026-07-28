#monitoring_metrics_mssql_latency
import pandas as pd
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
try:
    from analysis.self_activity_filter import filter_excluded_logins as _dbdome_filter_excluded_logins
except Exception:
    def _dbdome_filter_excluded_logins(df, *a, **k):
        return df

def collect_metric_postgres_privileged_logins(pg_server,pg_servername  ,pg_port, pg_database , pg_username , pg_password , pg_driver ):
    
    # Create the PG monitoried connection string

    pg_monitored_connection_string = f"postgresql://{pg_username}:{pg_password}@{pg_server}:{pg_port}/{pg_database}?sslmode=disable"
    #postgresql connection
    pg_home_connection_string = get_connection_string()
   
    try:
        # ========== 2. Create SQLAlchemy Engines ==========
        # SQL Server (source)
        pg_home_server_engine = create_engine(pg_home_connection_string )
        # PostgreSQL (target)
        pg_monitored_engine = create_engine(pg_monitored_connection_string )
        metadata = MetaData(schema="monitoring")  
        
        raw_conn = pg_monitored_engine.raw_connection()    
        p_sql_cmd = f"""              
                    SELECT
                         '{pg_servername}' servername,
                        member.rolname AS login_name,
                        role.rolname AS role_name
                    FROM pg_auth_members m
                    JOIN pg_roles role ON m.roleid = role.oid
                    JOIN pg_roles member ON m.member = member.oid
                    WHERE
                        role.rolsuper = true
                    ORDER BY
                        role.rolname, member.rolname;
                        """           
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)    
        df = _dbdome_filter_excluded_logins(df)
        raw_conn.close()
        # ========== 4. Bulk UPSERT into PostgreSQL ==========
        if df.empty:
            return 1
        with pg_home_server_engine.begin() as conn:                                                                  
                conn.execute(
                text("delete from monitoring.sensitive_schema where server =:server"),
                        [{                      
                      "server":row[0]
                       } for row in df.itertuples(index=False)]
        )
                        
        with pg_home_server_engine.begin() as conn:                                                                  
                conn.execute(
                text("INSERT INTO monitoring.privileged_logins (server ,  LoginName , ServerRole )\
                      VALUES (:server , :LoginName , :ServerRole )"),
                        [{                      
                      "server":row[0],
                      "login_name":row[1],
                      "role_name":row[2]
                       } for row in df.itertuples(index=False)]
        )
    except Exception as e:                 
                    db_write_log(f"collect_metric_postgres_sensitive_data_activity failed with error:{e}"   ,0,"collect_metric_postgres_sensitive_data_activity" , pg_server , port=pg_port)
    finally:
            db_write_log(f"collect_metric_postgres_sensitive_data_activity success"   ,0,"collect_metric_postgres_sensitive_data_activity" , pg_server , port=pg_port)
            raw_conn.close()
    return  1
    return 0;

