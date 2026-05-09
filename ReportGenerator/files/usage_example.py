"""
Simple Usage Example - JSON Report Generator
===========================================
This example shows how to use the JSON-based report generator.
"""

from json_report_generator import JSONReportGenerator

# Method 1: Use an existing JSON config file
generator = JSONReportGenerator('report_config.json')
generator.generate()

# Method 2: Create config programmatically and save it
import json

config = {
    "report": {
        "title": "Monthly Sales Report",
        "author": "Sales Team",
        "date": "auto"
    },
    "database": {
        "host": "localhost",
        "port": 5432,
        "database": "sales_db",
        "user": "postgres",
        "password": "your_password"
    },
    "sections": [
        {
            "type": "header",
            "level": 1,
            "text": "Overview"
        },
        {
            "type": "text",
            "content": "This report summarizes our sales performance."
        },
        {
            "type": "table",
            "query": "SELECT * FROM monthly_summary ORDER BY month DESC LIMIT 12",
            "headers": ["Month", "Revenue", "Orders", "Customers"],
            "format": {
                "Revenue": "currency"
            }
        }
    ],
    "output": {
        "pdf": "C:\ProgramData\dbdome\bin\reports\monthly_sales.pdf",
        "html": "C:\ProgramData\dbdome\bin\reports\monthly_sales.html"
    }
}

# Save config
with open('my_report_config.json', 'w') as f:
    json.dump(config, f, indent=2)

# Generate report
generator = JSONReportGenerator('my_report_config.json')
generator.generate()
