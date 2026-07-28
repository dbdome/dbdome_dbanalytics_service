import sys, warnings
sys.path.insert(0, r"C:\dev\dbdome_dbanalytics_service")
import pandas as pd, psycopg2
from utils.config_dotenv import get_connection_string
conn = psycopg2.connect(get_connection_string())

# control: default behaviour -> warning emitted
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter("default")
    pd.read_sql_query("SELECT 1 AS x", conn)
    ctrl = [str(x.message)[:60] for x in w if "SQLAlchemy" in str(x.message)]

# with the entry-point suppression applied
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter("default")
    warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy connectable")
    pd.read_sql_query("SELECT 1 AS x", conn)
    supp = [str(x.message)[:60] for x in w if "SQLAlchemy" in str(x.message)]

conn.close()
print("control (no filter)  -> SQLAlchemy warnings:", len(ctrl), ctrl[:1])
print("with suppression     -> SQLAlchemy warnings:", len(supp))
print("RESULT:", "SUPPRESSED OK" if len(ctrl) >= 1 and len(supp) == 0 else "CHECK")
