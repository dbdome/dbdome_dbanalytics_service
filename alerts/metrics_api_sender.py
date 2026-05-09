import requests
from datetime import datetime
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from sqlalchemy import create_engine, MetaData
import pandas as pd
import math


    
def send_results(
    _api_url ,
    _api_key ,
    _server_id:str,
    _server:str,
    _root_cause_id:str,
    _status:str,
    _result_count:str,
    _evidence:str,
    _severity:str,
    impact_score:int,
):
    try:
        root_cause_result_send(
              _api_url ,
            _api_key ,
            _server_id , 
            _server,
            _root_cause_id,
            _result_count,
            _evidence,
            _severity,
            impact_score,
            _status
        )
    except Exception as e:
        db_write_log(f"❌ root_cause_result_send Request failed: {e}", 0, "root_cause_result_send", "")


def root_cause_result_send(
    _api_url , 
    _api_key  , 
    _server_id , 
    _server,
    _root_cause_id: str,
    _result_count: int,
    _evidence: str,
    _severity: str,
    impact_score: int,
    _status: str 
):
    response = None

    try:
        api_key = _api_key

        ingest_url = _api_url

        # --- Build request ---
        headers = {
            "accept": "application/json",
            "X-Ingest-API-Key": api_key,
            "Content-Type": "application/json"
        }
        _impact_score = 0
        if '"metric_metadata": []' in _evidence:                
            _status = 'clear'
            _severity = 'low'  
            _impact_score = 0
            _result_count = 0
        else:
            _status = 'finding'
            _impact_score = 1
        payload = {
            "server_id": str(_server_id),
            "results": [
                {
                    "root_cause_id": str(_root_cause_id),
                    "status": str(_status),
                    "result_count": _result_count,
                    "evidence": str(_evidence),
                    "severity": str(_severity),
                    "impact_score": impact_score, 
                    "checked_at": get_utc_timestamp()
                }
            ],
        }

        db_write_log(f"Sending payload: {payload}", 0, "root_cause_result_send", "")

        # --- Send request ---
        try:
            response = requests.post(f"{ingest_url}/results", headers=headers, json=payload, timeout=10)
            response.raise_for_status()
            db_write_log(f"✅ Request succeeded: {response.json()}", 0, "root_cause_result_send", "")
            print("Status:", response.status_code)
            print("Response:", response.json())

        except requests.exceptions.Timeout:
            db_write_log("❌ Request timed out", 0, "root_cause_result_send", "")
            print("❌ Request timed out")

        except requests.exceptions.HTTPError as e:
            error_body = response.text if response is not None else "no response body"
            db_write_log(f"❌ HTTP error: {e} | Server said: {error_body}", 0, "root_cause_result_send", "")
            print("❌ HTTP error:", e)
            print("Server response:", error_body)

        except requests.exceptions.RequestException as e:
            db_write_log(f"❌ Request failed: {e}", 0, "root_cause_result_send", "")
            print("❌ Request failed:", e)

    except Exception as e:
        db_write_log(f"❌ Unexpected error in root_cause_result_send: {e}", 0, "root_cause_result_send", "")

    finally:
        db_write_log("root_cause_result_send finished", 0, "root_cause_result_send", "")
        print("🔚 Request finished")





def server_upsert(_api_url   , _api_key,  _server, _server_id, _vendor_slug="sqlserver", _port=None, _environment="prod"):
    """
    Upsert a server to the frontend API via PUT /api/ingest/servers/{server_id}.
    Called before posting detection results to ensure the server is registered.
    """

    try:

        if not _api_key or not _api_url:
            db_write_log("Missing INGEST_API_KEY or INGEST_URL", 0, "server_upsert", _server, port=_port)
            return

        if not _server_id:
            db_write_log(f"No server_id for {_server}, skipping upsert", 0, "server_upsert", _server, port=_port)
            return

        # --- Build request ---
        headers = {
            "accept": "application/json",
            "X-Ingest-API-Key": _api_key,
            "Content-Type": "application/json",
        }

        payload = {
            "name": _server,
            "host": _server,
            "vendor_slug": _vendor_slug,
            "port": int(_port) if _port else None,
            "environment": _environment,
            "metadata": {},
            "checked_at": get_utc_timestamp(),
        }

        response = requests.put(
            f"{_api_url}/servers/{str(_server_id)}",
            headers=headers, json=payload, timeout=10
        )
        response.raise_for_status()
        db_write_log(f"Server upserted: {_server}", 0, "server_upsert", _server, port=_port)

    except requests.exceptions.Timeout:
        db_write_log(f"Server upsert timed out for {_server}", 0, "server_upsert", _server, port=_port)

    except requests.exceptions.HTTPError as e:
        error_body = response.text if response is not None else "no response body"
        db_write_log(f"Server upsert HTTP error for {_server}: {e} | {error_body}", 0, "server_upsert", _server, port=_port)

    except requests.exceptions.RequestException as e:
        db_write_log(f"Server upsert failed for {_server}: {e}", 0, "server_upsert", _server, port=_port)

    except Exception as e:
        db_write_log(f"Server upsert unexpected error for {_server}: {e}", 0, "server_upsert", _server, port=_port)



from datetime import datetime, timezone

def get_utc_timestamp():
    return datetime.now(timezone.utc).isoformat()
