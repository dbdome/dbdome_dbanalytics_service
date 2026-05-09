"""
Report Generator Module
A flexible module for generating PDF and HTML reports with tables and charts.
"""

import pandas as pd
import matplotlib.pyplot as plt
import io
import base64
from datetime import datetime
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT


class ReportGenerator:
    """
    A class to generate professional reports in PDF and HTML formats.
    
    Features:
    - Add titles, headers, and text sections
    - Insert data tables from pandas DataFrames or lists
    - Embed matplotlib charts
    - Multiple output formats (PDF, HTML)
    """
    
    def __init__(self, title="Report", author="", page_size=letter):
        """
        Initialize the report generator.
        
        Args:
            title (str): Report title
            author (str): Report author
            page_size: Page size for PDF (letter or A4)
        """
        self.title = title
        self.author = author
        self.page_size = page_size
        self.sections = []
        self.styles = getSampleStyleSheet()
        
        # Create custom styles
        self.styles.add(ParagraphStyle(
            name='CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#1f4788'),
            spaceAfter=30,
            alignment=TA_CENTER
        ))
        
        self.styles.add(ParagraphStyle(
            name='SectionHeader',
            parent=self.styles['Heading2'],
            fontSize=16,
            textColor=colors.HexColor('#2c5aa0'),
            spaceAfter=12,
            spaceBefore=12
        ))
    
    def add_section(self, section_type, content, **kwargs):
        """
        Add a section to the report.
        
        Args:
            section_type (str): Type of section ('title', 'text', 'table', 'chart', 'header')
            content: Content for the section
            **kwargs: Additional parameters specific to section type
        """
        self.sections.append({
            'type': section_type,
            'content': content,
            'kwargs': kwargs
        })
    
    def add_title(self, title):
        """Add a title section."""
        self.add_section('title', title)
    
    def add_header(self, header):
        """Add a section header."""
        self.add_section('header', header)
    
    def add_text(self, text):
        """Add a text paragraph."""
        self.add_section('text', text)
    
    def add_table(self, data, headers=None, col_widths=None):
        """
        Add a data table.
        
        Args:
            data: pandas DataFrame, list of lists, or list of dicts
            headers: Optional list of column headers
            col_widths: Optional list of column widths
        """
        if isinstance(data, pd.DataFrame):
            headers = list(data.columns) if headers is None else headers
            data = data.values.tolist()
        
        self.add_section('table', data, headers=headers, col_widths=col_widths)
    
    def add_chart(self, fig, caption=""):
        """
        Add a matplotlib chart.
        
        Args:
            fig: matplotlib Figure object
            caption: Optional caption for the chart
        """
        self.add_section('chart', fig, caption=caption)
    
    def _build_pdf_elements(self):
        """Build PDF elements from sections."""
        elements = []
        
        # Add main title
        title_para = Paragraph(self.title, self.styles['CustomTitle'])
        elements.append(title_para)
        
        if self.author:
            author_para = Paragraph(f"By: {self.author}", self.styles['Normal'])
            elements.append(author_para)
        
        date_para = Paragraph(f"Generated: {datetime.now().strftime('%B %d, %Y')}", 
                             self.styles['Normal'])
        elements.append(date_para)
        elements.append(Spacer(1, 0.3*inch))
        
        # Process sections
        for section in self.sections:
            section_type = section['type']
            content = section['content']
            kwargs = section['kwargs']
            
            if section_type == 'title':
                para = Paragraph(content, self.styles['CustomTitle'])
                elements.append(para)
                elements.append(Spacer(1, 0.2*inch))
                
            elif section_type == 'header':
                para = Paragraph(content, self.styles['SectionHeader'])
                elements.append(para)
                
            elif section_type == 'text':
                para = Paragraph(content, self.styles['BodyText'])
                elements.append(para)
                elements.append(Spacer(1, 0.1*inch))
                
            elif section_type == 'table':
                headers = kwargs.get('headers')
                col_widths = kwargs.get('col_widths')
                
                table_data = []
                if headers:
                    table_data.append(headers)
                table_data.extend(content)
                
                table = Table(table_data, colWidths=col_widths)
                
                # Style the table
                style = TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c5aa0')),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                    ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 12),
                    ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                    ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                    ('GRID', (0, 0), (-1, -1), 1, colors.black),
                    ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                    ('FONTSIZE', (0, 1), (-1, -1), 10),
                    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey])
                ])
                table.setStyle(style)
                
                elements.append(table)
                elements.append(Spacer(1, 0.2*inch))
                
            elif section_type == 'chart':
                caption = kwargs.get('caption', '')
                
                # Save figure to bytes
                img_buffer = io.BytesIO()
                content.savefig(img_buffer, format='png', bbox_inches='tight', dpi=150)
                img_buffer.seek(0)
                
                # Create image
                img = Image(img_buffer, width=6*inch, height=4*inch)
                elements.append(img)
                
                if caption:
                    cap_para = Paragraph(f"<i>{caption}</i>", self.styles['Normal'])
                    elements.append(cap_para)
                
                elements.append(Spacer(1, 0.2*inch))
        
        return elements
    
    def _build_html(self):
        """Build HTML from sections."""
        html_parts = [f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{self.title}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 40px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .report-container {{
            background-color: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #1f4788;
            text-align: center;
            border-bottom: 3px solid #2c5aa0;
            padding-bottom: 20px;
        }}
        h2 {{
            color: #2c5aa0;
            margin-top: 30px;
            margin-bottom: 15px;
        }}
        .metadata {{
            text-align: center;
            color: #666;
            margin-bottom: 30px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th {{
            background-color: #2c5aa0;
            color: white;
            padding: 12px;
            text-align: center;
            font-weight: bold;
        }}
        td {{
            padding: 10px;
            text-align: center;
            border: 1px solid #ddd;
        }}
        tr:nth-child(even) {{
            background-color: #f9f9f9;
        }}
        tr:hover {{
            background-color: #f0f0f0;
        }}
        .chart {{
            text-align: center;
            margin: 20px 0;
        }}
        .chart img {{
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
        }}
        .caption {{
            font-style: italic;
            color: #666;
            text-align: center;
            margin-top: 10px;
        }}
        p {{
            line-height: 1.6;
            color: #333;
        }}
    </style>
</head>
<body>
    <div class="report-container">
        <h1>{self.title}</h1>
        <div class="metadata">
"""]
        
        if self.author:
            html_parts.append(f"<p><strong>Author:</strong> {self.author}</p>")
        
        html_parts.append(f"<p><strong>Generated:</strong> {datetime.now().strftime('%B %d, %Y at %H:%M')}</p>")
        html_parts.append("</div>")
        
        # Process sections
        for section in self.sections:
            section_type = section['type']
            content = section['content']
            kwargs = section['kwargs']
            
            if section_type == 'title':
                html_parts.append(f"<h1>{content}</h1>")
                
            elif section_type == 'header':
                html_parts.append(f"<h2>{content}</h2>")
                
            elif section_type == 'text':
                html_parts.append(f"<p>{content}</p>")
                
            elif section_type == 'table':
                headers = kwargs.get('headers')
                
                html_parts.append("<table>")
                
                if headers:
                    html_parts.append("<thead><tr>")
                    for header in headers:
                        html_parts.append(f"<th>{header}</th>")
                    html_parts.append("</tr></thead>")
                
                html_parts.append("<tbody>")
                for row in content:
                    html_parts.append("<tr>")
                    for cell in row:
                        html_parts.append(f"<td>{cell}</td>")
                    html_parts.append("</tr>")
                html_parts.append("</tbody></table>")
                
            elif section_type == 'chart':
                caption = kwargs.get('caption', '')
                
                # Convert figure to base64
                img_buffer = io.BytesIO()
                content.savefig(img_buffer, format='png', bbox_inches='tight', dpi=150)
                img_buffer.seek(0)
                img_base64 = base64.b64encode(img_buffer.read()).decode()
                
                html_parts.append('<div class="chart">')
                html_parts.append(f'<img src="data:image/png;base64,{img_base64}" alt="Chart">')
                if caption:
                    html_parts.append(f'<p class="caption">{caption}</p>')
                html_parts.append('</div>')
        
        html_parts.append("""
    </div>
</body>
</html>
""")
        
        return ''.join(html_parts)
    
    def generate_pdf(self, filename):
        """
        Generate a PDF report.
        
        Args:
            filename (str): Output PDF filename
        """
        doc = SimpleDocTemplate(filename, pagesize=self.page_size)
        elements = self._build_pdf_elements()
        doc.build(elements)
        print(f"PDF report generated: {filename}")
    
    def generate_html(self, filename):
        """
        Generate an HTML report.
        
        Args:
            filename (str): Output HTML filename
        """
        html = self._build_html()
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(html)
        print(f"HTML report generated: {filename}")
    
    def generate(self, filename, format='pdf'):
        """
        Generate a report in the specified format.
        
        Args:
            filename (str): Output filename
            format (str): Output format ('pdf' or 'html')
        """
        if format.lower() == 'pdf':
            self.generate_pdf(filename)
        elif format.lower() == 'html':
            self.generate_html(filename)
        else:
            raise ValueError(f"Unsupported format: {format}. Use 'pdf' or 'html'.")
