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
import pyodbc
from collection.mssql.mssql_driver_util  import get_installed_driver_by_priority
pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders
from urllib.parse import quote_plus  # <-- this is required
import urllib.parse

def collect_metric_mssql_table_schema(mssql_server,mssql_servername  , mssql_database , mssql_username , mssql_password , mssql_driver,auth_type , mssql_port=None):
    server = mssql_server
    servername = mssql_servername
    database = mssql_database
    if database is None:
          database = "master"
    username = mssql_username
    password = mssql_password

    
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
    server_with_port = f"{servername},{mssql_port}" if mssql_port else servername
    if auth_type == "win":
        odbc_str = f"""
                DRIVER={{{driver}}};
                SERVER={server_with_port};
                DATABASE={database};
                Trusted_Connection=yes;
                Encrypt=yes;
                TrustServerCertificate=yes;
                """
    else:
        odbc_str = f"""
            DRIVER={{{driver}}};
            SERVER={server_with_port};
            DATABASE={database};
            UID={username};
            PWD={password};
            Encrypt=yes;
            TrustServerCertificate=yes;
"""

    params = quote_plus(odbc_str)

    # Create the connection string
    connection_string =  "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(odbc_str)

    #postgresql connection
    pg_connection_string = get_connection_string()
   
    # ========== 2. Create SQLAlchemy Engines ==========
    # SQL Server (source)
    try:
        sql_server_engine = create_engine(connection_string, echo=True)
        postgres_engine = create_engine(pg_connection_string)
        metadata = MetaData(schema="monitoring")
        raw_conn = sql_server_engine.raw_connection()

        p_sql_cmd = """
       SET NOCOUNT ON;

DECLARE @dbname sysname;
DECLARE @sql NVARCHAR(MAX);

DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbname;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @sql = N'SELECT
                        ''' + @dbname + ''' AS TABLE_CATALOG,
                        t.name AS TABLE_NAME,
                        c.name AS COLUMN_NAME,
                        ty.name AS DATA_TYPE
                    FROM ' + QUOTENAME(@dbname) + '.sys.tables t
                    JOIN ' + QUOTENAME(@dbname) + '.sys.columns c
                        ON t.object_id = c.object_id
                    JOIN ' + QUOTENAME(@dbname) + '.sys.types ty
                        ON c.user_type_id = ty.user_type_id
                    WHERE t.is_ms_shipped = 0;';

        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Skipping database: ' + @dbname + ' due to error: ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM db_cursor INTO @dbname;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;
        """

        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)

        # ✅ Guard clause
        if df is None or df.empty:
            db_write_log("⚠ No schema data returned from SQL Server.", 0, "collect_metric_mssql_table_schema", servername, port=mssql_port)
            return 1

        with postgres_engine.begin() as conn:
            conn.execute(
                text("DELETE FROM monitoring.SCHEMA WHERE SERVER = :SERVER and is_enabled is true"),
                [{"SERVER": server}]
        )

        conn.execute(
            text("""
                INSERT INTO monitoring.SCHEMA (
                    SERVER, TABLE_CATALOG, TABLE_NAME, COLUMN_NAME, DATA_TYPE
                )
                VALUES (
                    :SERVER, :TABLE_CATALOG, :TABLE_NAME, :COLUMN_NAME, :DATA_TYPE
                )
            """),
            [
                {
                    "SERVER": server,
                    "TABLE_CATALOG": row.TABLE_CATALOG,
                    "TABLE_NAME": row.TABLE_NAME,
                    "COLUMN_NAME": row.COLUMN_NAME,
                    "DATA_TYPE": row.DATA_TYPE,
                }
                for row in df.itertuples(index=False)
            ]
        )

    except Exception as e:
        db_write_log(f"collect_metric_mssql_table_schema failed with error: {e}", 0,
                 "collect_metric_mssql_table_schema", servername, port=mssql_port)
    finally:
        try:
            raw_conn.close()
        except Exception:
            pass
        db_write_log("✅ collect_metric_mssql_table_schema Data sync complete.", 0,
                 "collect_metric_mssql_table_schema", servername, port=mssql_port)
    return 1
    return 0;

