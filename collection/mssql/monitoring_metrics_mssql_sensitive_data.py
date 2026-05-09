# monitoring_metrics_mssql_latency
import pandas as pd
from sqlalchemy import create_engine, text, MetaData
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
import pyodbc
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

def collect_metric_mssql_sensitive_data_activity(mssql_server, mssql_servername, mssql_port, mssql_database, mssql_username, mssql_password, mssql_driver,auth_type):
    # Create the MSSQL monitored connection string
    
    installed_drivers = pyodbc.drivers()
    print("Installed drivers:", installed_drivers)

    # Define priority list
    priority = ["ODBC Driver 18 for SQL Server",
            "ODBC Driver 17 for SQL Server",
            "SQL Server"]

    # Select the first available driver by priority
    selected_driver = next((d for d in priority if d in installed_drivers), None)

    if selected_driver is None:
        raise RuntimeError("No suitable ODBC driver found!")

    print("Selected driver:", selected_driver)


    driver =selected_driver

    #mssql_monitored_connection_string = f"mssql+pyodbc://{mssql_username}:{mssql_password}@{mssql_server}/{mssql_database}?driver={mssql_driver}"
    if not mssql_database:
        mssql_database = "master";
    server_with_port = f"{mssql_server},{mssql_port}" if mssql_port else mssql_server
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={mssql_database};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={mssql_database};
            UID={mssql_username};
            PWD={mssql_password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    params = quote_plus(odbc_str)

    # Create the connection string
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)


    # PostgreSQL connection string
    pg_home_connection_string = get_connection_string()

    try:
        # ========== 1. Create SQLAlchemy Engines ==========
        pg_home_server_engine = create_engine(pg_home_connection_string, echo=True)
        mssql_engine = create_engine(connection_string, echo=True)

        # ========== 2. Get list of databases ==========
        db_query = """
        SELECT name 
        FROM sys.databases
        WHERE state = 0 -- online
        AND name NOT IN ('master', 'tempdb', 'model', 'msdb');
        """

        db_list = pd.read_sql_query(db_query, con=mssql_engine)

        # ========== 3. Loop through each database ==========
        all_results = []

        for db in db_list['name']:
            print(f"🔍 Scanning database: {db}")
            # Dynamic query per database
            p_sql_cmd = f"""
            SELECT 
                '{mssql_server}' AS server,                             
                TABLE_CATALOG AS database_name,
                TABLE_SCHEMA,
                TABLE_NAME,
                COLUMN_NAME,
                DATA_TYPE
            FROM [{db}].INFORMATION_SCHEMA.COLUMNS
            WHERE 
                LOWER(COLUMN_NAME) LIKE '%password%' 
                OR LOWER(COLUMN_NAME) LIKE '%pass%' 
                OR LOWER(COLUMN_NAME) LIKE '%secret%' 
                OR LOWER(COLUMN_NAME) LIKE '%token%' 
                OR LOWER(COLUMN_NAME) LIKE '%key%' 
                OR LOWER(COLUMN_NAME) LIKE '%credit%' 
                OR LOWER(COLUMN_NAME) LIKE '%card%' 
                OR LOWER(COLUMN_NAME) LIKE '%ssn%' 
                OR LOWER(COLUMN_NAME) LIKE '%email%' 
                OR LOWER(COLUMN_NAME) LIKE '%phone%' 
                OR LOWER(COLUMN_NAME) LIKE '%address%' 
                OR LOWER(COLUMN_NAME) LIKE '%dob%' 
                OR LOWER(COLUMN_NAME) LIKE '%birth%' 
                OR LOWER(COLUMN_NAME) LIKE '%salary%'
            ORDER BY 
                TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME;
            """
            df = pd.read_sql_query(p_sql_cmd, con=mssql_engine)
            if not df.empty:
                all_results.append(df)

        # ========== 4. Concatenate all results ==========
        if all_results:
            final_df = pd.concat(all_results, ignore_index=True)
        else:
            print("✅ No sensitive columns found in any database.")
            return 1

        # ========== 5. Sync to PostgreSQL ==========
        with pg_home_server_engine.begin() as conn:
            # Delete existing for this server
            conn.execute(
                text("DELETE FROM monitoring.sensitive_schema WHERE server = :server"),
                {"server": mssql_server}
            )

            # Insert new
            conn.execute(
                text("""
                INSERT INTO monitoring.sensitive_schema (server, database_name, table_schema, table_name, column_name, data_type)
                VALUES (:server, :database_name, :table_schema, :table_name, :column_name, :data_type)
                """),
                [ 
                    {
                        "server": row['server'],
                        "database_name": row['database_name'],
                        "table_schema": row['TABLE_SCHEMA'],
                        "table_name": row['TABLE_NAME'],
                        "column_name": row['COLUMN_NAME'],
                        "data_type": row['DATA_TYPE']
                    } 
                    for _, row in final_df.iterrows()
                ]
            )
            db_write_log(f"✅ collect_metric_mssql_sensitive_data_activity Data sync complete", 0, "collect_metric_mssql_sensitive_data_activity", mssql_servername, port=mssql_port)
        return 1

    except Exception as e:
        db_write_log(f"collect_metric_mssql_sensitive_data_activity failed with error: {e}", 0, "collect_metric_mssql_sensitive_data_activity", mssql_servername, port=mssql_port)
        return 0
