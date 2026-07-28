"""
JSON-Based Report Generator with PostgreSQL Integration
========================================================
This module allows you to define reports in JSON and automatically
populate them with data from PostgreSQL queries.
"""

import csv
import json
import os
import re
import sys
import tempfile
import psycopg2
from psycopg2.extras import RealDictCursor
import matplotlib
matplotlib.use("Agg")  # headless, non-interactive backend. MUST be set before
# importing pyplot: in the web service (no display / worker thread) the default
# GUI backend (Tk) blocks forever, which made the IPS report hang/time out.
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
from ReportGenerator.report_generator import ReportGenerator

# Default reporting window when a template uses Grafana time macros
# ($__timeFrom/$__timeTo/$__timeFilter) — a report has no dashboard time-picker,
# so we substitute a fixed look-back. Override per report with report.time_window_hours.
_DEFAULT_WINDOW_HOURS = 168  # 7 days


def _reports_dir():
    """Return an absolute directory where generated report files are saved."""
    if getattr(sys, 'frozen', False):
        base = os.path.dirname(sys.executable)
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base, "reports")
    os.makedirs(path, exist_ok=True)
    return path


class JSONReportGenerator:
    """Generate reports from JSON configuration files with PostgreSQL queries."""
    
    def __init__(self, config_file, server_name=None):
        """
        Initialize the report generator with a JSON config file.

        Args:
            config_file: Path to JSON configuration file
            server_name: Optional server filter; replaces the {server}
                placeholder in template queries ('%' when not set, so
                `server LIKE '{server}'` matches all servers)
        """
        # utf-8-sig: nearly every shipped template starts with a UTF-8 BOM, which
        # plain json.load rejects ("Expecting value: line 1 column 1"). -sig strips
        # a BOM when present and is a no-op when it isn't.
        with open(config_file, 'r', encoding='utf-8-sig') as f:
            self.config = json.load(f)

        self.conn = None
        self.report = None
        self.server_name = server_name
        # Raw table data collected while rendering, so generate() can also emit
        # a CSV alongside every PDF: [(section_title, headers, rows-as-dicts)].
        self._csv_tables = []

        # Fixed reporting window for Grafana time macros. Computed once so every
        # section of the report covers the same range.
        try:
            window_h = int(self.config.get('report', {}).get('time_window_hours',
                                                              _DEFAULT_WINDOW_HOURS))
        except (TypeError, ValueError):
            window_h = _DEFAULT_WINDOW_HOURS
        self._time_to = datetime.now()
        self._time_from = self._time_to - timedelta(hours=window_h)

    def _substitute_time_macros(self, query):
        """Replace Grafana time macros with SQL-literal timestamps so template
        queries authored for Grafana run in the report generator. Without this,
        '$__timeFrom()' reaches PostgreSQL verbatim and raises 'syntax error at
        or near "$"', so the whole section renders empty."""
        if not query or '$__time' not in query:
            return query
        frm = "'" + self._time_from.strftime('%Y-%m-%d %H:%M:%S') + "'"
        to  = "'" + self._time_to.strftime('%Y-%m-%d %H:%M:%S') + "'"
        q = re.sub(r'\$__timeFrom\s*\(\s*\)', frm, query)
        q = re.sub(r'\$__timeTo\s*\(\s*\)',   to,  q)
        q = re.sub(r'\$__timeFrom\b(?!\s*\()', frm, q)
        q = re.sub(r'\$__timeTo\b(?!\s*\()',   to,  q)
        q = re.sub(r'\$__timeFilter\s*\(\s*([a-zA-Z_][\w\.]*)\s*\)',
                   lambda m: f"{m.group(1)} BETWEEN {frm} AND {to}", q)
        return q
    
    def connect_database(self):
        """Establish connection to PostgreSQL database.

        Credentials come from the JSON `database` block. When the block omits a
        password (recommended - so report templates carry no secrets), fall back
        to the service's standard connection resolver, which reads the .env.
        """
        db_config = self.config.get('database', {})

        if not db_config.get('password'):
            for mod in ('utils.config_dotenv', 'utils.utils_config_dotenv'):
                try:
                    import importlib
                    get_cs = importlib.import_module(mod).get_connection_string
                    self.conn = psycopg2.connect(get_cs())
                    return
                except Exception:
                    continue

        self.conn = psycopg2.connect(
            host=db_config.get('host', 'localhost'),
            port=db_config.get('port', 5432),
            database=db_config.get('database'),
            user=db_config.get('user'),
            password=db_config.get('password')
        )
    
    def execute_query(self, query):
        """
        Execute a SQL query and return results.
        
        Args:
            query: SQL query string
            
        Returns:
            List of dictionaries containing query results
        """
        if query and '{server}' in query:
            value = (self.server_name or '').replace("'", "''") or '%'
            query = query.replace('{server}', value)
        # Substitute Grafana time macros ($__timeFrom/$__timeTo/$__timeFilter) that
        # templates carry over from their dashboard panels — otherwise PostgreSQL
        # raises 'syntax error at or near "$"' and the section renders empty.
        query = self._substitute_time_macros(query)
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query)
        results = cursor.fetchall()
        cursor.close()
        return results
    
    def format_value(self, value, format_type):
        """
        Format a value according to specified format type.
        
        Args:
            value: Value to format
            format_type: Format type ('currency', 'percentage', 'number', etc.)
            
        Returns:
            Formatted string
        """
        if format_type == 'currency':
            return f'${value:,.2f}'
        elif format_type == 'percentage':
            return f'{value:.1f}%'
        elif format_type == 'number':
            return f'{value:,.0f}'
        else:
            return str(value)
    
    def process_table(self, section):
        """Process a table section from the config."""
        query = section['query']
        results = self.execute_query(query)

        if not results:
            self.report.add_text("No data available.")
            return

        col_keys = list(results[0].keys())
        headers = section.get('headers', col_keys)
        if len(headers) != len(col_keys):
            headers = col_keys

        # Keep the raw (unformatted) rows for the CSV companion file.
        self._csv_tables.append((
            section.get('title') or section.get('caption') or f"Table {len(self._csv_tables) + 1}",
            col_keys, headers, results,
        ))

        table_data = []
        format_config = section.get('format', {})

        for row in results:
            formatted_row = []
            for i, key in enumerate(col_keys):
                value = row[key]
                if headers[i] in format_config:
                    value = self.format_value(value, format_config[headers[i]])
                formatted_row.append(str(value) if value is not None else '')
            table_data.append(formatted_row)

        self.report.add_table(table_data, headers=headers)
    
    def process_chart(self, section):
        """Process a chart section from the config.

        Column detection is automatic — no x_column/y_column needed:
          - 2-column result  → col[0] = labels/x, col[1] = values/y
          - 3-column line    → col[0] = x-axis, col[1] = series category,
                               col[2] = value  (pivoted into multi-series)
        """
        query = section['query']
        results = self.execute_query(query)

        if not results:
            self.report.add_text("No data available for chart.")
            return

        chart_type = section.get('chart_type', 'bar')
        caption = section.get('chart_text', section.get('caption', ''))
        cols = list(results[0].keys())

        fig, ax = plt.subplots(figsize=(10, 5))

        if chart_type == 'pie':
            labels = [str(row[cols[0]]) for row in results]
            values = [float(row[cols[1]] or 0) for row in results]
            ax.pie(values, labels=labels, autopct='%1.1f%%', startangle=140)

        elif chart_type == 'line' and len(cols) == 3:
            # Pivot: col[0]=x, col[1]=series, col[2]=value
            from collections import defaultdict
            series_data = defaultdict(dict)
            x_vals = []
            for row in results:
                x = str(row[cols[0]])
                series = str(row[cols[1]])
                val = float(row[cols[2]] or 0)
                series_data[series][x] = val
                if x not in x_vals:
                    x_vals.append(x)

            colors = {'critical': '#d32f2f', 'high': '#f57c00',
                      'medium': '#fbc02d', 'low': '#388e3c', 'info': '#1976d2'}
            for series, xy in series_data.items():
                y_vals = [xy.get(x, 0) for x in x_vals]
                ax.plot(x_vals, y_vals, marker='o', linewidth=2,
                        label=series, color=colors.get(series))
            ax.legend()
            ax.grid(True, alpha=0.3)
            plt.xticks(rotation=45, ha='right')

        elif chart_type == 'line':
            x_data = [str(row[cols[0]]) for row in results]
            y_data = [float(row[cols[1]] or 0) for row in results]
            ax.plot(x_data, y_data, marker='o', linewidth=2, color='#2c5aa0')
            ax.grid(True, alpha=0.3)
            plt.xticks(rotation=45, ha='right')

        elif chart_type == 'bar':
            x_data = [str(row[cols[0]]) for row in results]
            y_data = [float(row[cols[1]] or 0) for row in results]
            ax.bar(x_data, y_data, color='#2c5aa0')
            plt.xticks(rotation=45, ha='right')

        if caption:
            ax.set_title(caption)
        if 'x_label' in section and chart_type != 'pie':
            ax.set_xlabel(section['x_label'])
        if 'y_label' in section and chart_type != 'pie':
            ax.set_ylabel(section['y_label'])

        plt.tight_layout()
        self.report.add_chart(fig, caption=caption)
        plt.close(fig)
    
    def process_text(self, section):
        """Process a text section from the config."""
        if 'query' in section:
            # Text with dynamic content from query
            query = section['query']
            results = self.execute_query(query)
            
            if results:
                template = section.get('template', '')
                # Replace placeholders with query results
                text = template.format(**results[0])
                self.report.add_text(text)
        else:
            # Static text
            self.report.add_text(section['content'])
    
    def generate(self):
        """Generate the complete report from JSON configuration."""
        # Initialize report
        report_config = self.config['report']
        
        # Handle auto date
        author = report_config.get('author', 'Report Generator')
        if report_config.get('date') == 'auto':
            author = f"{author} - {datetime.now().strftime('%Y-%m-%d')}"
        
        # Landscape A4: these are wide data tables (many columns), which do not fit
        # a portrait page.
        from reportlab.lib.pagesizes import A4, landscape
        self.report = ReportGenerator(
            title=report_config['title'],
            author=author,
            page_size=landscape(A4),
        )
        
        # Connect to database
        if 'database' in self.config:
            self.connect_database()
        
        # Process each section
        for section in self.config.get('sections', []):
            section_type = section['type']
            
            if section_type == 'header':
                # ReportGenerator.add_header() doesn't support level parameter
                # Level 1 headers are added as headers, level 2 as bold text
                level = section.get('level', 1)
                if level == 1:
                    self.report.add_header(section['text'])
                else:
                    # For level 2, add as bold text with spacing
                    self.report.add_text(f"\n**{section['text']}**\n")
            
            elif section_type == 'text':
                self.process_text(section)
            
            elif section_type == 'table':
                self.process_table(section)
            
            elif section_type == 'chart':
                self.process_chart(section)
        
        # Generate output files
        output_config = self.config.get('output', {})
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        out_dir = _reports_dir()
        pdf_filename = None
        html_filename = None
        csv_filename = None

        if 'pdf' in output_config:
            pdf_filename = os.path.join(out_dir, f"{output_config['pdf']}_{timestamp}.pdf")
            self.report.generate_pdf(pdf_filename)
            print(f"✓ PDF generated: {pdf_filename}")

        if 'html' in output_config:
            html_filename = os.path.join(out_dir, f"{output_config['html']}_{timestamp}.html")
            self.report.generate_html(html_filename)
            print(f"✓ HTML generated: {html_filename}")

        # Every PDF report also ships a CSV companion with the raw rows of every
        # table section (charts/text have no tabular data). Opt out per template
        # with output.csv = false; override the base name with output.csv = "name".
        csv_base = output_config.get('csv', output_config.get('pdf'))
        if csv_base and self._csv_tables:
            csv_filename = os.path.join(out_dir, f"{csv_base}_{timestamp}.csv")
            self._write_csv(csv_filename)
            print(f"✓ CSV generated: {csv_filename}")

        # Close database connection
        if self.conn:
            self.conn.close()
        return pdf_filename, html_filename, csv_filename

    def _write_csv(self, path):
        """Write every collected table section into one CSV file.

        Sections are separated by a blank line and introduced by a single
        '# <section title>' row, then the header row, then the raw
        (unformatted) values — so numbers stay machine-readable even when the
        PDF shows currency/percentage formatting. utf-8-sig so Excel opens it
        with the right encoding."""
        with open(path, "w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f)
            first = True
            for title, col_keys, headers, rows in self._csv_tables:
                if not first:
                    w.writerow([])
                first = False
                w.writerow([f"# {title}"])
                w.writerow(headers)
                for row in rows:
                    w.writerow(["" if row[k] is None else row[k] for k in col_keys])

def main():
    """Example usage of JSON-based report generator."""
    # Generate report from JSON config
    generator = JSONReportGenerator('report_config.json')
    generator.generate()


if __name__ == '__main__':
    main()
