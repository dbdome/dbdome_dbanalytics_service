from email_utils.smtp_email_sender import  send_mail_alert_no_attachment                       
from utils.config_dotenv import get_connection_string
from datetime import datetime
import unittest
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from sqlalchemy import create_engine, func , text  , MetaData, Table , Column, Integer, String, DateTime
import pandas as pd
import argparse
import random
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any
import requests
import psycopg2
import pyodbc
import urllib.parse
import json 
from psycopg2.extras import RealDictCursor

def safe_int(val, default=0):
    try:
        return int(val)
    except (TypeError, ValueError):
        return default



def _id() -> str:
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Vendor connection helpers for process execution
# ---------------------------------------------------------------------------

def _connect_mssql_process(server, database, username, password, auth_type):
    installed_drivers = pyodbc.drivers()
    priority = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"]
    driver = next((d for d in priority if d in installed_drivers), None)
    if driver is None:
        raise RuntimeError("No suitable ODBC driver found for SQL Server")

    if auth_type == "win":
        odbc_str = (f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
                    f"Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;")
    else:
        odbc_str = (f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
                    f"UID={username};PWD={password};Encrypt=yes;TrustServerCertificate=yes;")
    return pyodbc.connect(odbc_str, timeout=30)


def _connect_postgresql_process(server, database, username, password, port):
    return psycopg2.connect(
        host=server, port=port or 5432, dbname=database,
        user=username, password=password, connect_timeout=30
    )


def _connect_oracle_process(server, username, password, port, service_name):
    import oracledb
    dsn = oracledb.makedsn(server, port or 1521, service_name=service_name)
    try:
        return oracledb.connect(user=username, password=password, dsn=dsn, tcp_connect_timeout=30)
    except oracledb.DatabaseError:
        try:
            oracledb.init_oracle_client()
        except oracledb.ProgrammingError:
            pass
        return oracledb.connect(user=username, password=password, dsn=dsn)


def _connect_mysql_process(server, database, username, password, port):
    import pymysql
    return pymysql.connect(
        host=server, port=int(port or 3306), user=username,
        password=password, database=database, connect_timeout=30
    )


def _execute_step_and_record(target_conn, postgres_engine, step_query,
                             step_expected_rows, pid, step_id, process_id,
                             server, port, vendor):
    """Execute a step query on the target DB and record results in processes.executions."""
    started_at = datetime.now(timezone.utc)
    row_count = 0
    error_message = None
    status = "succeeded"

    try:
        cursor = target_conn.cursor()
        # Escape % for psycopg2 (PostgreSQL targets)
        exec_sql = step_query
        if vendor in ("postgresql", "postgres") and '%' in step_query:
            exec_sql = step_query.replace('%', '%%')
        cursor.execute(exec_sql)

        try:
            rows = cursor.fetchall()
            row_count = len(rows)
            # If query returns a single scalar, use that as the count
            if rows and len(rows) == 1 and len(rows[0]) == 1:
                row_count = safe_int(rows[0][0], len(rows))
        except Exception:
            pass

        cursor.close()

        if safe_int(row_count) > safe_int(step_expected_rows):
            status = "succeeded"
        else:
            status = "failed"

    except Exception as e:
        status = "failed"
        error_message = str(e)[:500]

    completed_at = datetime.now(timezone.utc)
    duration_ms = int((completed_at - started_at).total_seconds() * 1000)

    with postgres_engine.begin() as conn_pg:
        conn_pg.execute(
            text("""
                INSERT INTO processes.executions
                (process_id, step_id, status, started_at, completed_at, duration_ms, row_count, error_message)
                VALUES
                (:process_id, :step_id, :status, :started_at, :completed_at, :duration_ms, :row_count, :error_message)
            """),
            {
                "process_id": pid,
                "step_id": step_id,
                "status": status,
                "started_at": started_at.isoformat(),
                "completed_at": completed_at.isoformat(),
                "duration_ms": duration_ms,
                "row_count": row_count,
                "error_message": error_message,
            }
        )

    db_write_log(
        f"Process step {step_id}: {status} (rows={row_count}, {duration_ms}ms)",
        0, "execute_process", server, port=port
    )


def execute_process():
    try:
        pg_connection_string = get_connection_string()

        # Connect to the PostgreSQL database
        postgres_engine = create_engine(pg_connection_string )
        
        conn = psycopg2.connect(pg_connection_string)

        # Create a cursor
        cur = conn.cursor()

        # Query the view
        cur.execute("select server , database , username , password , port , auth_type , service_name , vendor , process_id from processes.v_servers_processes")

        # Fetch and print rows
        rows = cur.fetchall()
        for row in rows:
            server      = row[0]
            database    = row[1]
            username    = row[2]
            password    = row[3]
            port  = row[4]        
            auth_type  = row[5]
            service_name = row[6]
            vendor = row[7]   
            pid = row[8] 
            cur.execute("select activity, api_key, api_url, organization_name, org_id, category, schedule_type, process_expected_duration_ms, process_name, schedule_expr, process_id, description, step_name, step_order, step_type, step_expected_ms, step_expected_rows  , step_query , step_id from processes.v_processes_steps order by process_id  , step_order")    

            # Fetch and print rows
            rows = cur.fetchall()
            for row in rows:
                activity    = row[0] 
                api_key     = row[1]  
                api_url     = row[2] 
                organization_name   = row[3] 
                org_id              = row[4] 
                category            = row[5] 
                schedule_type                   = row[6] 
                process_expected_duration_ms    = row[7] 
                process_name                    = row[8] 
                schedule_expr                   = row[9] 
                process_id                      = row[10] 
                description                     = row[11] 
                step_name                       = row[12] 
                step_order                      = row[13] 
                step_type                       = row[14]
                step_expected_ms                = row[15]    
                step_expected_rows              = row[16] 
                step_query                      = row[17]
                step_id                         = row[18]
            
                match vendor:
                    case "mssql" | "sqlserver":
                        target_conn = _connect_mssql_process(server, database, username, password, auth_type)
                    case "postgresql" | "postgres":
                        target_conn = _connect_postgresql_process(server, database, username, password, port)
                    case "oracle" | "oracle-19c" | "oracle-21c" | "oracle-23ai":
                        target_conn = _connect_oracle_process(server, username, password, port, service_name)
                    case "mysql" | "mariadb":
                        target_conn = _connect_mysql_process(server, database, username, password, port)
                    case _:
                        db_write_log(f"Unsupported vendor: {vendor}", 0, "execute_process", server, port=port)
                        continue

                try:
                    _execute_step_and_record(
                        target_conn, postgres_engine, step_query,
                        step_expected_rows, pid, step_id, process_id,
                        server, port, vendor
                    )
                except Exception as e:
                    db_write_log(f"❌ execute_process failed for {vendor}/{server}: {e}", 0, "execute_process", server, port=port)
                finally:
                    try:
                        target_conn.close()
                    except Exception:
                        pass
        
    except Exception as e:
        db_write_log(f"❌ execute_process failed with error: {e}", 0, "v", "")                    
        return 0  
    finally:
        process_update(conn);           


def process_update(conn):
    try:
        cur = conn.cursor()
        
        p_sql_cmd = f"""      
                select org_id, organization_name, api_key, api_url, processes  from processes.v_processes_steps_json """
        cur.execute (p_sql_cmd)
        rows = cur.fetchall()
        
        for row in rows :            
                        org_id  = row[0]
                        org_name = row[1]
                        api_key= row[2]
                        api_url = row[3]
                        processes_json  = row[4]
                        parser = argparse.ArgumentParser(description=org_name)
                        parser.add_argument("--api-url", default=api_url, help="Ingest API base URL")
                        parser.add_argument("--token", default=api_key, help="X-Ingest-API-Key token")
                        parser.add_argument("--dry-run", action="store_true", help="Print payloads without sending")
                        args = parser.parse_args()

                        headers = {
                            "X-Ingest-API-Key": str(args.token),
                            "Content-Type": "application/json",
                        }
                        session = requests.Session()
                        session.headers.update(headers)

                        db_write_log(f"API URL: {args.api_url}", 0, "process_update", "")
                        db_write_log(f"Seeding {len(processes_json)} processes...\n", 0, "process_update", "")

                        all_executions = []
                        processes_json = row[4]  # the JSON column

                        # check what you actually got
                        print(type(processes_json))

                        
                        process_id = processes_json["id"]
                            
                        payload, step_ids = build_process_payload(processes_json)

                        db_write_log(f"  [{processes_json['category']}] {processes_json['name']}", 0, "process_update", "")
                        db_write_log(f"    ID: {process_id}", 0, "process_update", "")
                        db_write_log(f"    Steps: {len(payload['steps'])}, Edges: {len(payload['edges'])}", 0, "process_update", "")

                        if not args.dry_run:
                            # Upsert process definition
                                url = f"{args.api_url}/processes/{process_id}"
                                resp = session.put(url, json=payload)
                                if resp.status_code == 200:
                                    data = resp.json()
                                    db_write_log(f"    -> Created: slug={data['slug']}, v{data['version']}", 0, "process_update", "")
                                    print(f"    -> Created: slug={data['slug']}, v{data['version']}")
                                else:
                                    db_write_log(f"    -> FAILED: {resp.status_code} {resp.text}", 0, "process_update", "")
                                    print(f"    -> FAILED: {resp.status_code} {resp.text}")
                                    continue

                                # Generate execution history
                                executions = generate_executions(processes_json, step_ids, payload["steps"], count=5)
                                all_executions.extend(executions)
                                db_write_log(f"    Executions: {len(executions)} (1 failed, 1 slow, 3 normal)", 0, "process_update", "")

                                # Push all executions in one batch
                                db_write_log(f"\nPushing {len(all_executions)} executions...", 0, "process_update", "")

                                if not args.dry_run:
                                    batch_payload = {"executions": all_executions}
                                    resp = session.post(f"{args.api_url}/process-executions", json=batch_payload)
                                if resp.status_code == 200:
                                    data = resp.json()
                                    db_write_log(f"  -> Accepted: {data['accepted']}, Anomalies created: {data['anomalies_created']}", 0, "process_update", "")
                                else:
                                    db_write_log(f"  -> FAILED: {resp.status_code} {resp.text}", 0, "process_update", "")
                        else:
                                    db_write_log("  (dry-run, skipped)", 0, "process_update", "")

                        db_write_log("\nDone! Visit https://dbexpert.ai/processes to see the results.", 0, "process_update", "")

    except Exception as e:
            db_write_log(f"root_cause_result_send failed with error: {e}", 0, "root_cause_result_send", "")
    finally:
         conn.close() 

    

def build_process_payload(proc_def: dict) -> dict:
    """Build the PUT /processes/{id} payload from a definition."""
    try:
        steps = []
        step_ids = []

        for s in proc_def["steps"]:
            sid = _id()
            step_ids.append(sid)
            steps.append({
                "id": sid,
                "name": s["name"],
                "step_type": s["type"],
                "step_order": s["order"],
                "expected_duration_ms": s.get("expected_ms"),
                "expected_row_count": s.get("expected_rows"),
                "timeout_ms": (s["expected_ms"] * 3) if s.get("expected_ms") else None,
                "duration_warn_pct": 0.2,
                "row_count_drift_pct": 0.1,
            })

        edges = []
        for i in range(len(steps) - 1):
            edge_type = "conditional" if steps[i]["step_type"] == "decision" else "sequence"
            edges.append({
                "from_step_id": step_ids[i],
                "to_step_id": step_ids[i + 1],
                "edge_type": edge_type,
                "label": "pass" if edge_type == "conditional" else None,
            })

        payload = {
            "name": proc_def["name"],
            "description": proc_def["description"],
            "category": proc_def["category"],
            "version": 1,
            "status": "active",
            "schedule_type": proc_def["schedule_type"],
            "schedule_expr": proc_def.get("schedule_expr"),
            "expected_duration_ms": proc_def["expected_duration_ms"],
            "steps": steps,
            "edges": edges,
        }

        return payload, step_ids

    except Exception as e:
            db_write_log(...)
            return {}, []

def generate_executions(proc_def: dict, step_ids: list[str], steps: list[dict], count: int = 5) -> list[dict]:
    """Generate realistic execution history with some anomalies."""
    now = datetime.now(timezone.utc)
    executions = []
    error_msg = None

    try:
        for i in range(count):
            started = now - timedelta(days=count - i, hours=random.randint(0, 3))
            exec_key = f"{proc_def['category']}-run-{started.strftime('%Y%m%d-%H%M')}"

            if i == count - 2:
                speed_factor = 1.8
                exec_status = "completed"
            elif i == count - 3 and count > 3:
                speed_factor = 0.6
                exec_status = "failed"
            else:
                speed_factor = random.uniform(0.7, 1.1)
                exec_status = "failed"

            step_execs = []
            cursor = started
            failed_at_step = None

            for j, s_def in enumerate(proc_def["steps"]):
                sid = step_ids[j]
                expected_ms = s_def.get("expected_ms")
                expected_rows = s_def.get("expected_rows")

                if s_def["type"] in ("start", "end"):
                    step_execs.append({
                        "step_id": sid,
                        "status": "completed" if exec_status != "failed" or failed_at_step is None else "skipped",
                        "started_at": cursor.isoformat(),
                        "completed_at": (cursor + timedelta(seconds=1)).isoformat(),
                        "duration_ms": 100,
                    })
                    cursor += timedelta(seconds=1)
                    continue

                if failed_at_step is not None:
                    step_execs.append({
                        "step_id": sid,
                        "status": "skipped",
                    })
                    continue

                actual_ms = 0
                step_started = cursor
                step_completed = cursor + timedelta(milliseconds=actual_ms)
                cursor = step_completed

                actual_rows = 0 if expected_rows else None

                if exec_status == "failed" and j == len(proc_def["steps"]) // 2:
                    error_msg = f" בסנכרון כשלון {s_def['name'].lower()}"
                    step_execs.append({
                        "step_id": sid,
                        "status": "failed",
                        "started_at": step_started.isoformat(),
                        "completed_at": step_completed.isoformat(),
                        "duration_ms": actual_ms,
                        "row_count": actual_rows,
                        "error_message": error_msg,
                    })
                    failed_at_step = j
                    continue

                step_execs.append({
                    "step_id": sid,
                    "status": "completed",
                    "started_at": step_started.isoformat(),
                    "completed_at": step_completed.isoformat(),
                    "duration_ms": actual_ms,
                    "row_count": actual_rows,
                })

            executions.append({
                "process_id": proc_def["id"],
                "execution_key": exec_key,
                "status": exec_status,
                "started_at": started.isoformat(),
                "completed_at": cursor.isoformat(),
                "steps": step_execs,
            })

    except Exception as e:
        db_write_log(f"Executions failed with error: {e}", 0, "Executions", "")
        return []

    # ✅ finally replaced with safe post-processing
    print(executions)

    try:
        send_mail_alert_no_attachment(
            proc_def["name"],
            proc_def["description"],
            proc_def.get("schedule_expr"),
            proc_def["name"],
            proc_def["name"],
            error_msg or "Execution issue",
            error_msg or "Execution issue",
            error_msg or "Execution issue",
            error_msg or "Execution issue",
            error_msg or "Execution issue",
            3
        )
    except Exception as mail_error:
        db_write_log(f"Mail failed: {mail_error}", 0, "Executions", "")

    return executions







def list_processes(api_key , api_url) -> list[dict]:
    API_URL = "https://dbexpertai.com/api/ingest"
    headers = {
    "X-Ingest-API-Key": api_key,
    "Content-Type": "application/json",
}
    """Get all processes for the org. Returns list of {id, name, slug, category, status}."""
    resp = requests.get(f"{API_URL}/processes", headers=headers)
    resp.raise_for_status()
    return resp.json()


def ensure_list(val):
    if isinstance(val, str):
        return json.loads(val)
    return val