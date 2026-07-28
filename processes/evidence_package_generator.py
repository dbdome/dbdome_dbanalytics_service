"""GRC Phase 10: Audit Evidence Package Generator
Produces PDF (plain-text fallback) + CSV ZIP bundles with SHA-256 hashes.
"""
import csv
import hashlib
import io
import os
import threading
import zipfile
from datetime import date, datetime, timedelta
from pathlib import Path

import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

REPORT_DIR = Path(os.getenv('REPORT_DIR', 'reports')) / 'evidence'

SECTIONS = [
    ('Firewall Audit Log',     'log.firewall_audit_log',      'event_time',
     ['event_time','server_name','db_user','client_ip','action_taken','policy_name','risk_score']),
    ('DDL Audit Log',          'log.ddl_audit_log',           'event_time',
     ['event_time','server_name','db_user','ddl_command','object_name','risk_level','regulation']),
    ('Privilege Changes',      'log.privilege_change_log',    'event_time',
     ['event_time','server_name','grantor_user','grantee_user','operation','privilege_type','object_name','regulation']),
    ('SoD Violations',         'log.sod_violations',          'detected_at',
     ['detected_at','server_name','db_user','rule_name','severity','regulation','is_acknowledged']),
    ('TLS Violations',         'log.tls_violations',          'detected_at',
     ['detected_at','server_name','db_user','client_ip','ssl_mode','risk_level','regulation']),
    ('Vulnerability Findings', 'log.vulnerability_findings',  'detected_at',
     ['detected_at','server_name','vendor','db_version','cve_id','severity','patch_status']),
    ('Retention Executions',   'log.retention_executions',    'executed_at',
     ['executed_at','policy_name','target_table','cutoff_date','rows_deleted','success','sha256_manifest']),
    ('Threat Response Log',    'log.threat_response_log',     'triggered_at',
     ['triggered_at','server_name','subject','response_type','outcome']),
]


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _collect_section(conn, table: str, ts_col: str, columns: list,
                     period_start: date, period_end: date,
                     regulation: str = None):
    cols_sql = ', '.join(columns)
    reg_filter = "AND regulation=%s" if regulation else ""
    params = [str(period_start), str(period_end)]
    if regulation:
        params.append(regulation)
    try:
        cur = conn.cursor()
        cur.execute(
            f"SELECT {cols_sql} FROM {table} "
            f"WHERE {ts_col}::date BETWEEN %s AND %s {reg_filter} "
            f"ORDER BY {ts_col} DESC LIMIT 10000",
            params)
        rows = cur.fetchall()
        cur.close()
        return columns, rows
    except Exception:
        return columns, []


def _build_csv_zip(sections_data: list) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        for section_name, columns, rows in sections_data:
            csv_buf = io.StringIO()
            w = csv.writer(csv_buf)
            w.writerow(columns)
            for row in rows:
                w.writerow(['' if v is None else str(v) for v in row])
            zf.writestr(f"{section_name.replace(' ', '_')}.csv", csv_buf.getvalue())
    return buf.getvalue()


def _build_text_report(sections_data: list, meta: dict) -> bytes:
    lines = [
        "DBDOME GRC Audit Evidence Package",
        f"Regulation : {meta.get('regulation') or 'ALL'}",
        f"Period     : {meta['period_start']} to {meta['period_end']}",
        f"Generated  : {meta['generated_at']}",
        "=" * 80,
    ]
    for section_name, columns, rows in sections_data:
        lines.append(f"\n--- {section_name} ({len(rows)} records) ---")
        lines.append('\t'.join(str(c) for c in columns))
        for row in rows[:500]:
            lines.append('\t'.join('' if v is None else str(v) for v in row))
    return '\n'.join(lines).encode('utf-8')


def generate_evidence_package(regulation: str = None, period_start: date = None,
                               period_end: date = None, generated_by: str = 'system',
                               package_id: int = None) -> int:
    if period_end is None:
        period_end = date.today()
    if period_start is None:
        prev = period_end.replace(day=1) - timedelta(days=1)
        period_start = prev.replace(day=1)

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    conn = _get_conn()
    try:
        if package_id is None:
            pkg_name = f"GRC Evidence {regulation or 'ALL'} {period_start} to {period_end}"
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO log.evidence_packages
                    (package_name, regulation, period_start, period_end,
                     generated_by, package_type, status, included_sections)
                VALUES (%s,%s,%s,%s,%s,'ON_DEMAND','GENERATING','{}')
                RETURNING package_id
            """, (pkg_name, regulation, period_start, period_end, generated_by))
            package_id = cur.fetchone()[0]
            conn.commit()
            cur.close()

        sections_data = []
        included = []
        for section_name, table, ts_col, columns in SECTIONS:
            cols, rows = _collect_section(conn, table, ts_col, columns,
                                          period_start, period_end, regulation)
            sections_data.append((section_name, cols, rows))
            included.append(section_name)

        meta = {
            'regulation': regulation, 'period_start': str(period_start),
            'period_end': str(period_end),
            'generated_at': datetime.utcnow().isoformat(),
        }
        pdf_bytes = _build_text_report(sections_data, meta)
        csv_bytes = _build_csv_zip(sections_data)

        sha_pdf = hashlib.sha256(pdf_bytes).hexdigest()
        sha_csv = hashlib.sha256(csv_bytes).hexdigest()

        pdf_path = REPORT_DIR / f"evidence_{package_id}.txt"
        csv_path = REPORT_DIR / f"evidence_{package_id}.zip"
        pdf_path.write_bytes(pdf_bytes)
        csv_path.write_bytes(csv_bytes)

        cur = conn.cursor()
        cur.execute("""
            UPDATE log.evidence_packages
               SET status='COMPLETE', pdf_path=%s, csv_zip_path=%s,
                   sha256_pdf=%s, sha256_csv=%s,
                   included_sections=%s,
                   file_size_bytes=%s
             WHERE package_id=%s
        """, (str(pdf_path), str(csv_path), sha_pdf, sha_csv,
              included, len(pdf_bytes) + len(csv_bytes), package_id))
        conn.commit()
        cur.close()
        print(f"[evidence] Package {package_id} complete ({len(included)} sections)")
        return package_id

    except Exception as e:
        try:
            c = conn.cursor()
            c.execute("UPDATE log.evidence_packages SET status='FAILED', error_message=%s WHERE package_id=%s",
                      (str(e)[:500], package_id))
            conn.commit()
            c.close()
        except Exception:
            pass
        db_write_log(f"generate_evidence_package: {e}", 0, "evidence_package_generator", "")
        return package_id
    finally:
        conn.close()


def run_evidence_package_generation():
    """Monthly scheduled entry — one package per active regulation."""
    for reg in ['PCI-DSS', 'HIPAA', 'GDPR', 'SOC2']:
        t = threading.Thread(
            target=generate_evidence_package,
            kwargs={'regulation': reg, 'generated_by': 'scheduler'},
            daemon=True)
        t.start()
