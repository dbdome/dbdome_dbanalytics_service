"""
QUICK START GUIDE - Report Generator
====================================

This is the simplest possible example to get you started.
Copy and modify this code for your own reports.
"""

from report_generator import ReportGenerator
import matplotlib.pyplot as plt

# Step 1: Create a report instance
report = ReportGenerator(
    title="My First Report",
    author="Your Name"
)

# Step 2: Add content

# Add a section header
report.add_header("Introduction")

# Add some text
report.add_text(
    "This is my first report using the Report Generator module. "
    "It's easy to create professional-looking reports!"
)

# Add a table
report.add_header("Sample Data Table")
data = [
    ['Item', 'Quantity', 'Price'],
    ['Apples', '50', '$2.99'],
    ['Oranges', '30', '$3.49'],
    ['Bananas', '40', '$1.99']
]
report.add_table(data[1:], headers=data[0])

# Add a chart
report.add_header("Sample Chart")
fig, ax = plt.subplots(figsize=(6, 4))

items = ['Apples', 'Oranges', 'Bananas']
quantities = [50, 30, 40]

ax.bar(items, quantities, color='#2c5aa0')
ax.set_ylabel('Quantity')
ax.set_title('Inventory Levels')
ax.grid(True, alpha=0.3, axis='y')

plt.tight_layout()
report.add_chart(fig, caption="Current inventory by product")
plt.close(fig)

# Step 3: Generate the report (both formats)
report.generate_pdf('/mnt/user-data/outputs/my_first_report.pdf')
report.generate_html('/mnt/user-data/outputs/my_first_report.html')

print("✓ Report generated successfully!")
print("  - PDF: my_first_report.pdf")
print("  - HTML: my_first_report.html")
