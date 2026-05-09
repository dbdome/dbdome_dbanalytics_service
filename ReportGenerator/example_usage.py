"""
Example usage of the Report Generator module
This script demonstrates how to create reports with tables and charts.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from report_generator import ReportGenerator


def example_sales_report():
    """Example: Generate a sales performance report"""
    
    # Create report instance
    report = ReportGenerator(
        title="Q4 2025 Sales Performance Report",
        author="Sales Analytics Team"
    )
    
    # Add introduction
    report.add_header("Executive Summary")
    report.add_text(
        "This report provides a comprehensive overview of sales performance for Q4 2025. "
        "The analysis includes revenue trends, regional performance, and product category breakdowns."
    )
    
    # Create sample sales data
    sales_data = pd.DataFrame({
        'Month': ['October', 'November', 'December'],
        'Revenue ($)': [125000, 145000, 198000],
        'Units Sold': [450, 520, 710],
        'Avg Price ($)': [278, 279, 279]
    })
    
    # Add sales table
    report.add_header("Monthly Sales Summary")
    report.add_table(sales_data)
    
    # Create revenue trend chart
    fig1, ax1 = plt.subplots(figsize=(8, 5))
    months = sales_data['Month']
    revenue = sales_data['Revenue ($)']
    
    ax1.plot(months, revenue, marker='o', linewidth=2, markersize=8, color='#2c5aa0')
    ax1.fill_between(range(len(months)), revenue, alpha=0.3, color='#2c5aa0')
    ax1.set_xlabel('Month', fontsize=12)
    ax1.set_ylabel('Revenue ($)', fontsize=12)
    ax1.set_title('Q4 Revenue Trend', fontsize=14, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    ax1.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))
    plt.tight_layout()
    
    report.add_chart(fig1, caption="Figure 1: Monthly revenue showing strong growth in Q4")
    
    # Regional performance data
    regional_data = pd.DataFrame({
        'Region': ['North', 'South', 'East', 'West'],
        'Revenue ($)': [145000, 98000, 132000, 93000],
        'Growth (%)': [12.5, 8.3, 15.2, 6.1]
    })
    
    report.add_header("Regional Performance")
    report.add_table(regional_data)
    
    # Create regional performance chart
    fig2, ax2 = plt.subplots(figsize=(8, 5))
    regions = regional_data['Region']
    regional_revenue = regional_data['Revenue ($)']
    
    bars = ax2.bar(regions, regional_revenue, color=['#2c5aa0', '#4a7bc8', '#6a9bd8', '#8ab5e8'])
    ax2.set_xlabel('Region', fontsize=12)
    ax2.set_ylabel('Revenue ($)', fontsize=12)
    ax2.set_title('Revenue by Region', fontsize=14, fontweight='bold')
    ax2.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))
    
    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2., height,
                f'${height:,.0f}',
                ha='center', va='bottom', fontsize=10)
    
    plt.tight_layout()
    report.add_chart(fig2, caption="Figure 2: Regional revenue distribution for Q4")
    
    # Product category analysis
    report.add_header("Product Category Analysis")
    category_data = pd.DataFrame({
        'Category': ['Electronics', 'Home & Garden', 'Sports', 'Clothing', 'Books'],
        'Units': [1250, 890, 670, 1100, 540],
        'Revenue ($)': [178000, 123000, 89000, 145000, 33000]
    })
    
    report.add_table(category_data)
    
    # Create pie chart for category revenue
    fig3, ax3 = plt.subplots(figsize=(8, 6))
    colors_pie = ['#1f4788', '#2c5aa0', '#4a7bc8', '#6a9bd8', '#8ab5e8']
    
    wedges, texts, autotexts = ax3.pie(
        category_data['Revenue ($)'],
        labels=category_data['Category'],
        autopct='%1.1f%%',
        colors=colors_pie,
        startangle=90
    )
    
    # Beautify the pie chart
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
        autotext.set_fontsize(10)
    
    ax3.set_title('Revenue Share by Product Category', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    report.add_chart(fig3, caption="Figure 3: Product category contribution to total revenue")
    
    # Conclusions
    report.add_header("Key Findings")
    report.add_text(
        "• Revenue increased by 58% from October to December, showing strong holiday season performance.<br/>"
        "• The East region showed the highest growth rate at 15.2%.<br/>"
        "• Electronics and Clothing were the top-performing categories, contributing 56% of total revenue.<br/>"
        "• Average transaction value remained stable throughout the quarter at approximately $279."
    )
    
    # Generate both formats
    report.generate_pdf('/mnt/user-data/outputs/sales_report.pdf')
    report.generate_html('/mnt/user-data/outputs/sales_report.html')
    
    # Close all figures to free memory
    plt.close('all')
    
    print("\n✓ Sales report generated successfully!")


def example_data_analysis_report():
    """Example: Generate a data analysis report"""
    
    report = ReportGenerator(
        title="Customer Behavior Analysis",
        author="Data Science Team"
    )
    
    report.add_header("Overview")
    report.add_text(
        "This analysis examines customer purchasing patterns and behavior trends "
        "based on data collected over the past year."
    )
    
    # Generate sample data
    np.random.seed(42)
    dates = pd.date_range('2025-01-01', periods=12, freq='ME')
    customers = np.random.randint(800, 1500, 12)
    avg_order = np.random.uniform(45, 85, 12)
    
    monthly_data = pd.DataFrame({
        'Month': [d.strftime('%B') for d in dates],
        'Active Customers': customers,
        'Avg Order Value ($)': [round(x, 2) for x in avg_order],
        'Total Orders': np.random.randint(1200, 2500, 12)
    })
    
    report.add_header("Monthly Customer Metrics")
    report.add_table(monthly_data)
    
    # Create customer trend chart
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    
    # Active customers
    ax1.plot(range(12), customers, marker='s', linewidth=2, color='#2c5aa0')
    ax1.set_xlabel('Month', fontsize=11)
    ax1.set_ylabel('Active Customers', fontsize=11)
    ax1.set_title('Active Customer Trend', fontsize=12, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    ax1.set_xticks(range(12))
    ax1.set_xticklabels([d.strftime('%b') for d in dates], rotation=45)
    
    # Average order value
    ax2.bar(range(12), avg_order, color='#4a7bc8', alpha=0.8)
    ax2.set_xlabel('Month', fontsize=11)
    ax2.set_ylabel('Avg Order Value ($)', fontsize=11)
    ax2.set_title('Average Order Value', fontsize=12, fontweight='bold')
    ax2.grid(True, alpha=0.3, axis='y')
    ax2.set_xticks(range(12))
    ax2.set_xticklabels([d.strftime('%b') for d in dates], rotation=45)
    
    plt.tight_layout()
    report.add_chart(fig, caption="Customer behavior metrics across 2025")
    
    # Customer segments
    segment_data = pd.DataFrame({
        'Segment': ['Premium', 'Regular', 'Occasional', 'New'],
        'Count': [245, 678, 421, 189],
        'Avg Lifetime Value ($)': [2450, 890, 320, 125]
    })
    
    report.add_header("Customer Segmentation")
    report.add_table(segment_data)
    
    report.add_text(
        "The customer base is well-distributed across segments, with Regular customers "
        "representing the largest group. Premium customers, while fewer in number, "
        "contribute significantly to overall revenue with high lifetime values."
    )
    
    # Generate reports
    report.generate_pdf('/mnt/user-data/outputs/customer_analysis.pdf')
    report.generate_html('/mnt/user-data/outputs/customer_analysis.html')
    
    plt.close('all')
    print("\n✓ Customer analysis report generated successfully!")


def quick_example():
    """Quick example with minimal code"""
    
    # Create a simple report
    report = ReportGenerator(title="Weekly Summary Report")
    
    # Add some content
    report.add_header("Performance Metrics")
    
    # Add a simple table
    data = [
        ['KPI', 'Value', 'Target', 'Status'],
        ['Revenue', '$52,000', '$50,000', '✓'],
        ['New Users', '145', '150', '✗'],
        ['Conversion Rate', '3.2%', '3.0%', '✓']
    ]
    report.add_table(data[1:], headers=data[0])
    
    # Create a simple chart
    fig, ax = plt.subplots(figsize=(6, 4))
    categories = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
    values = [120, 145, 132, 158, 171]
    ax.plot(categories, values, marker='o', linewidth=2, color='#2c5aa0')
    ax.set_title('Daily Active Users', fontweight='bold')
    ax.set_ylabel('Users')
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    
    report.add_chart(fig, caption="User activity throughout the week")
    
    # Generate both formats
    report.generate('/mnt/user-data/outputs/quick_report.pdf', format='pdf')
    report.generate('/mnt/user-data/outputs/quick_report.html', format='html')
    
    plt.close('all')
    print("\n✓ Quick report generated!")


if __name__ == "__main__":
    print("=" * 60)
    print("Report Generator - Example Usage")
    print("=" * 60)
    
    print("\n1. Generating comprehensive sales report...")
    example_sales_report()
    
    print("\n2. Generating customer analysis report...")
    example_data_analysis_report()
    
    print("\n3. Generating quick report example...")
    quick_example()
    
    print("\n" + "=" * 60)
    print("All reports generated successfully!")
    print("Check the /mnt/user-data/outputs/ directory for the files.")
    print("=" * 60)
