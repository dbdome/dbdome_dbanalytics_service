# Report Generator Module

A powerful, easy-to-use Python module for generating professional PDF and HTML reports with data tables and charts.

## Features

✨ **Multiple Output Formats**: Generate both PDF and HTML reports from the same code  
📊 **Data Tables**: Easily add tables from pandas DataFrames or Python lists  
📈 **Charts & Graphs**: Embed matplotlib figures seamlessly  
🎨 **Professional Styling**: Clean, modern design out of the box  
🔧 **Flexible API**: Simple methods for common tasks, customizable for advanced use

## Installation

Required dependencies:
```bash
pip install reportlab matplotlib pandas
```

## Quick Start

```python
from report_generator import ReportGenerator
import matplotlib.pyplot as plt

# Create a report
report = ReportGenerator(title="My First Report", author="Your Name")

# Add a header
report.add_header("Sales Summary")

# Add a table
data = [
    ['Product', 'Revenue', 'Units'],
    ['Widget A', '$50,000', '250'],
    ['Widget B', '$75,000', '380']
]
report.add_table(data[1:], headers=data[0])

# Add a chart
fig, ax = plt.subplots(figsize=(6, 4))
ax.bar(['Widget A', 'Widget B'], [50000, 75000])
ax.set_ylabel('Revenue ($)')
ax.set_title('Product Revenue')
report.add_chart(fig)

# Generate the report
report.generate('my_report.pdf', format='pdf')
report.generate('my_report.html', format='html')
```

## API Reference

### ReportGenerator Class

#### Constructor

```python
ReportGenerator(title="Report", author="", page_size=letter)
```

**Parameters:**
- `title` (str): Main title of the report
- `author` (str): Author name (optional)
- `page_size`: Page size for PDF (use `letter` or `A4` from reportlab.lib.pagesizes)

#### Methods

##### add_title(title)
Add a title section to the report.

```python
report.add_title("Q4 Performance Analysis")
```

##### add_header(header)
Add a section header.

```python
report.add_header("Revenue Breakdown")
```

##### add_text(text)
Add a text paragraph.

```python
report.add_text("This section provides an overview of key metrics...")
```

##### add_table(data, headers=None, col_widths=None)
Add a data table to the report.

**Parameters:**
- `data`: Can be a pandas DataFrame, list of lists, or list of dicts
- `headers`: Optional list of column headers (auto-detected for DataFrames)
- `col_widths`: Optional list of column widths

**Examples:**

```python
# From pandas DataFrame
import pandas as pd
df = pd.DataFrame({
    'Month': ['Jan', 'Feb', 'Mar'],
    'Revenue': [10000, 12000, 15000]
})
report.add_table(df)

# From list of lists
data = [
    ['Product', 'Price', 'Stock'],
    ['Item A', '$99', '50'],
    ['Item B', '$149', '32']
]
report.add_table(data[1:], headers=data[0])

# With custom column widths
report.add_table(data[1:], headers=data[0], col_widths=[100, 80, 80])
```

##### add_chart(fig, caption="")
Add a matplotlib chart to the report.

**Parameters:**
- `fig`: matplotlib Figure object
- `caption`: Optional caption text for the chart

**Example:**

```python
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot([1, 2, 3, 4], [10, 20, 25, 30], marker='o')
ax.set_xlabel('Quarter')
ax.set_ylabel('Revenue ($K)')
ax.set_title('Quarterly Revenue')

report.add_chart(fig, caption="Figure 1: Revenue trend over four quarters")
plt.close(fig)  # Good practice to close figures after adding
```

##### generate_pdf(filename)
Generate a PDF report.

```python
report.generate_pdf('output/report.pdf')
```

##### generate_html(filename)
Generate an HTML report.

```python
report.generate_html('output/report.html')
```

##### generate(filename, format='pdf')
Generate a report in the specified format.

```python
report.generate('report.pdf', format='pdf')
report.generate('report.html', format='html')
```

## Complete Examples

### Example 1: Sales Report with Charts

```python
from report_generator import ReportGenerator
import pandas as pd
import matplotlib.pyplot as plt

# Create report
report = ReportGenerator(
    title="Monthly Sales Report",
    author="Sales Team"
)

# Add introduction
report.add_header("Executive Summary")
report.add_text(
    "This report summarizes sales performance for the current month, "
    "including revenue trends and top-performing products."
)

# Add sales data table
sales_data = pd.DataFrame({
    'Product': ['Product A', 'Product B', 'Product C'],
    'Units Sold': [150, 230, 180],
    'Revenue ($)': [15000, 34500, 27000]
})

report.add_header("Product Performance")
report.add_table(sales_data)

# Create and add a bar chart
fig, ax = plt.subplots(figsize=(8, 5))
products = sales_data['Product']
revenue = sales_data['Revenue ($)']

ax.bar(products, revenue, color='#2c5aa0')
ax.set_ylabel('Revenue ($)')
ax.set_title('Revenue by Product')
ax.grid(True, alpha=0.3, axis='y')

# Add value labels on bars
for i, v in enumerate(revenue):
    ax.text(i, v + 1000, f'${v:,}', ha='center', va='bottom')

plt.tight_layout()
report.add_chart(fig, caption="Product revenue comparison")
plt.close(fig)

# Generate reports
report.generate_pdf('monthly_sales.pdf')
report.generate_html('monthly_sales.html')

print("Reports generated successfully!")
```

### Example 2: Data Analysis Report

```python
from report_generator import ReportGenerator
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Create report
report = ReportGenerator(
    title="Website Analytics Report",
    author="Analytics Team"
)

report.add_header("Traffic Overview")
report.add_text(
    "Analysis of website traffic patterns over the past 30 days."
)

# Traffic data
daily_visitors = pd.DataFrame({
    'Day': list(range(1, 31)),
    'Visitors': np.random.randint(800, 1500, 30),
    'Page Views': np.random.randint(2000, 4000, 30)
})

# Summary statistics
summary = pd.DataFrame({
    'Metric': ['Avg Daily Visitors', 'Total Page Views', 'Avg Pages per Visit'],
    'Value': [
        f"{daily_visitors['Visitors'].mean():.0f}",
        f"{daily_visitors['Page Views'].sum():,}",
        f"{daily_visitors['Page Views'].sum() / daily_visitors['Visitors'].sum():.2f}"
    ]
})

report.add_header("Key Metrics")
report.add_table(summary)

# Create trend chart
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

# Visitors trend
ax1.plot(daily_visitors['Day'], daily_visitors['Visitors'], 
         linewidth=2, color='#2c5aa0', marker='o', markersize=4)
ax1.set_xlabel('Day')
ax1.set_ylabel('Visitors')
ax1.set_title('Daily Visitors')
ax1.grid(True, alpha=0.3)

# Page views trend
ax2.plot(daily_visitors['Day'], daily_visitors['Page Views'], 
         linewidth=2, color='#4a7bc8', marker='s', markersize=4)
ax2.set_xlabel('Day')
ax2.set_ylabel('Page Views')
ax2.set_title('Daily Page Views')
ax2.grid(True, alpha=0.3)

plt.tight_layout()
report.add_chart(fig, caption="30-day traffic trends")
plt.close(fig)

# Top pages
top_pages = pd.DataFrame({
    'Page': ['/home', '/products', '/about', '/contact', '/blog'],
    'Views': [15420, 12380, 8950, 6720, 10240]
})

report.add_header("Top Pages")
report.add_table(top_pages)

# Generate reports
report.generate_pdf('analytics_report.pdf')
report.generate_html('analytics_report.html')
```

### Example 3: Financial Report

```python
from report_generator import ReportGenerator
import pandas as pd
import matplotlib.pyplot as plt

report = ReportGenerator(
    title="Quarterly Financial Report - Q4 2025",
    author="Finance Department"
)

# Income statement
income_statement = pd.DataFrame({
    'Category': ['Revenue', 'Cost of Goods Sold', 'Gross Profit', 
                 'Operating Expenses', 'Net Income'],
    'Amount ($)': [500000, 200000, 300000, 150000, 150000],
    '% of Revenue': ['100%', '40%', '60%', '30%', '30%']
})

report.add_header("Income Statement")
report.add_table(income_statement)

# Create profit margin chart
fig, ax = plt.subplots(figsize=(8, 6))
categories = ['Revenue', 'COGS', 'Gross Profit', 'Op Expenses', 'Net Income']
amounts = [500000, -200000, 300000, -150000, 150000]
colors = ['green' if x > 0 else 'red' for x in amounts]

bars = ax.barh(categories, amounts, color=colors, alpha=0.7)
ax.set_xlabel('Amount ($)')
ax.set_title('Financial Breakdown')
ax.axvline(x=0, color='black', linewidth=0.8)
ax.grid(True, alpha=0.3, axis='x')

# Format x-axis
ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x/1000:.0f}K'))

plt.tight_layout()
report.add_chart(fig, caption="Q4 Financial Performance")
plt.close(fig)

# Key ratios
ratios = pd.DataFrame({
    'Ratio': ['Gross Margin', 'Operating Margin', 'Net Margin', 'ROI'],
    'Value': ['60%', '30%', '30%', '15%'],
    'Industry Avg': ['55%', '25%', '20%', '12%']
})

report.add_header("Key Financial Ratios")
report.add_table(ratios)

report.add_text(
    "The company's financial performance in Q4 2025 exceeded industry benchmarks "
    "across all key metrics, demonstrating strong operational efficiency and "
    "effective cost management."
)

report.generate_pdf('financial_report.pdf')
report.generate_html('financial_report.html')
```

## Tips and Best Practices

### 1. Always Close Matplotlib Figures
After adding charts to your report, close the figures to free memory:

```python
report.add_chart(fig, caption="My chart")
plt.close(fig)  # or plt.close('all') to close all figures
```

### 2. Use Consistent Styling
For professional-looking reports, maintain consistent colors and fonts in your charts:

```python
BRAND_COLOR = '#2c5aa0'
ACCENT_COLOR = '#4a7bc8'

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(x, y, color=BRAND_COLOR, linewidth=2)
# ... rest of chart setup
```

### 3. Format Numbers in Tables
Format numbers for better readability:

```python
df['Revenue'] = df['Revenue'].apply(lambda x: f'${x:,.2f}')
df['Percentage'] = df['Percentage'].apply(lambda x: f'{x:.1f}%')
```

### 4. Organize Your Report Structure
Plan your report structure before coding:

```python
# 1. Title and introduction
report.add_header("Executive Summary")
report.add_text("...")

# 2. Data sections with tables and charts
report.add_header("Section 1: ...")
report.add_table(...)
report.add_chart(...)

# 3. Conclusions
report.add_header("Conclusions")
report.add_text("...")
```

### 5. Test Both Output Formats
Always test both PDF and HTML outputs to ensure they look correct:

```python
report.generate_pdf('test.pdf')
report.generate_html('test.html')
```

## Customization

### Custom Page Sizes

```python
from reportlab.lib.pagesizes import A4, letter, legal

report = ReportGenerator(title="Report", page_size=A4)
```

### Custom Column Widths

```python
# Specify widths in points (1 inch = 72 points)
report.add_table(data, headers=headers, col_widths=[100, 150, 100, 100])
```

## Troubleshooting

### PDF Generation Issues
- Ensure all image buffers are properly closed
- Check that matplotlib figures are created before adding to report
- Verify file permissions for output directory

### HTML Rendering
- HTML reports use inline base64 images, so they can be large for many charts
- Test HTML output in different browsers for compatibility

### Memory Management
- Close matplotlib figures after adding them to reports
- For very large reports, consider generating sections separately

## License

This module is provided as-is for educational and commercial use.

## Support

For issues or questions, refer to the example files or modify the code to suit your needs.
