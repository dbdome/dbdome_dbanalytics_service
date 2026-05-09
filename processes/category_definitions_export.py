"""
Category Definitions Export

Queries rootcause.v_category_definitions and writes CategoryDefinitions.json
to the file path configured in config.global_params key 'categorydefinitions'.

Registered in scheduler as 'category_definitions_export'.
"""

import json
import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def export_category_definitions():
    """Query the rootcause taxonomy and write CategoryDefinitions.json."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()

    try:
        # Get output file path from config
        cur.execute("SELECT value FROM config.global_params WHERE key = 'categorydefinitions'")
        row = cur.fetchone()
        if not row or not row[0]:
            db_write_log("categorydefinitions path not configured in config.global_params", 0, "category_definitions_export", "")
            return

        output_path = row[0]

        # Query the view
        cur.execute("SELECT result FROM rootcause.v_category_definitions")
        row = cur.fetchone()
        if not row:
            db_write_log("No data from rootcause.v_category_definitions", 0, "category_definitions_export", "")
            return

        category_data = row[0]

        # Write JSON file
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(category_data, f, indent=2, ensure_ascii=False)

        domain_count = len(category_data.get('domains', []))
        area_count = len(category_data.get('areas', []))
        category_count = len(category_data.get('categories', []))
        server_count = len(category_data.get('servers', []) or [])

        db_write_log(
            f"CategoryDefinitions.json exported: {domain_count} domains, {area_count} areas, "
            f"{category_count} categories, {server_count} servers -> {output_path}",
            0, "category_definitions_export", ""
        )

    except Exception as e:
        db_write_log(f"category_definitions_export failed: {e}", 0, "category_definitions_export", "")

    finally:
        cur.close()
        conn.close()
