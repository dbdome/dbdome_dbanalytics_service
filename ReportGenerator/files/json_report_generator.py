"""
JSON-Based Report Generator with PostgreSQL Integration
========================================================
This module allows you to define reports in JSON and automatically
populate them with data from PostgreSQL queries.
"""

import json
import os
import sys
import tempfile
import psycopg2
from psycopg2.extras import RealDictCursor
import matplotlib.pyplot as plt
from datetime import datetime
from ReportGenerator.report_generator import ReportGenerator


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
    
    def __init__(self, config_file):
        """
        Initialize the report generator with a JSON config file.
        
        Args:
            config_file: Path to JSON configuration file
        """
        with open(config_file, 'r') as f:
            self.config = json.load(f)
        
        self.conn = None
        self.report = None
    
    def connect_database(self):
        """Establish connection to PostgreSQL database."""
        db_config = self.config.get('database', {})
        
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
        
        self.report = ReportGenerator(
            title=report_config['title'],
            author=author
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

        if 'pdf' in output_config:
            pdf_filename = os.path.join(out_dir, f"{output_config['pdf']}_{timestamp}.pdf")
            self.report.generate_pdf(pdf_filename)
            print(f"✓ PDF generated: {pdf_filename}")

        if 'html' in output_config:
            html_filename = os.path.join(out_dir, f"{output_config['html']}_{timestamp}.html")
            self.report.generate_html(html_filename)
            print(f"✓ HTML generated: {html_filename}")

        # Close database connection
        if self.conn:
            self.conn.close()
        return pdf_filename, html_filename

def main():
    """Example usage of JSON-based report generator."""
    # Generate report from JSON config
    generator = JSONReportGenerator('report_config.json')
    generator.generate()


if __name__ == '__main__':
    main()
