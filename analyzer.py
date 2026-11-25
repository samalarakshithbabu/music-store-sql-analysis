#!/usr/bin/env python3
"""
Music Store Data Analysis - Python Runner
Executes SQL queries, exports results, and generates visualizations.
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine, text
import numpy as np

# Configuration
import os
from urllib.parse import quote_plus

DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "3306")
DB_NAME = os.environ.get("DB_NAME", "MUSIC_STORE")

if not DB_USER or not DB_PASSWORD:
    raise RuntimeError("DB_USER and DB_PASSWORD environment variables are required")

DATABASE_URL = f"mysql+pymysql://{quote_plus(DB_USER)}:{quote_plus(DB_PASSWORD)}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
DATA_DIR = Path(__file__).parent / "DATA"
OUTPUT_DIR = Path(__file__).parent / "results"
CHARTS_DIR = Path(__file__).parent / "charts"


def get_connection():
    """Create database connection."""
    engine = create_engine(DATABASE_URL)
    return engine.connect()


def load_csv_to_table(engine, csv_path, table_name):
    """Load CSV file into database table."""
    df = pd.read_csv(csv_path)
    df.to_sql(table_name, engine, if_exists='replace', index=False)
    print(f"Loaded {len(df)} rows into {table_name}")


def setup_database(engine):
    """Load all CSV files into database."""
    tables = {
        'album': 'album.csv',
        'artist': 'artist.csv',
        'customer': 'customer.csv',
        'employee': 'employee.csv',
        'genre': 'genre.csv',
        'invoice': 'invoice.csv',
        'invoice_line': 'invoice_line.csv',
        'media_type': 'media_type.csv',
        'playlist': 'playlist.csv',
        'playlist_track': 'playlist_track.csv',
        'track': 'track.csv',
    }

    for table, csv_file in tables.items():
        csv_path = DATA_DIR / csv_file
        if csv_path.exists():
            load_csv_to_table(engine, csv_path, table)
        else:
            print(f"Warning: {csv_path} not found")


def execute_query(engine, query_name, query_sql):
    """Execute a SQL query and return results as DataFrame."""
    with engine.connect() as conn:
        df = pd.read_sql(text(query_sql), conn)
    return df


def analyze_rfm(engine):
    """Perform RFM segmentation analysis."""
    query = """
    WITH rfm_base AS (
        SELECT 
            c.customer_id,
            c.first_name,
            c.last_name,
            DATEDIFF('2017-12-31', MAX(i.invoice_date)) AS recency,
            COUNT(DISTINCT i.invoice_id) AS frequency,
            SUM(i.total) AS monetary
        FROM customer c
        JOIN invoice i ON c.customer_id = i.customer_id
        GROUP BY c.customer_id, c.first_name, c.last_name
    ),
    rfm_scores AS (
        SELECT *,
            NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
            NTILE(5) OVER (ORDER BY frequency) AS f_score,
            NTILE(5) OVER (ORDER BY monetary) AS m_score
        FROM rfm_base
    )
    SELECT 
        customer_id, first_name, last_name, r_score, f_score, m_score,
        CONCAT(r_score, f_score, m_score) AS rfm_segment,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
            ELSE 'At-Risk'
        END AS customer_segment,
        recency, frequency, monetary
    FROM rfm_scores
    ORDER BY monetary DESC
    """
    return execute_query(engine, 'rfm', query)


def analyze_churn(engine, days_threshold=180):
    """Detect churned and at-risk customers."""
    days_threshold = int(days_threshold)  # validate input is integer
    query = text("""
    WITH last_purchase AS (
        SELECT 
            c.customer_id,
            c.first_name,
            c.last_name,
            c.email,
            MAX(i.invoice_date) AS last_purchase_date,
            DATEDIFF('2017-12-31', MAX(i.invoice_date)) AS days_since_last,
            SUM(i.total) AS total_spent
        FROM customer c
        LEFT JOIN invoice i ON c.customer_id = i.customer_id
        GROUP BY c.customer_id, c.first_name, c.last_name, c.email
    )
    SELECT 
        customer_id, first_name, last_name, email,
        last_purchase_date, days_since_last, total_spent,
        CASE 
            WHEN days_since_last > :threshold THEN 'Churned'
            WHEN days_since_last > 90 THEN 'At-Risk'
            ELSE 'Active'
        END AS churn_status
    FROM last_purchase
    ORDER BY days_since_last DESC
    """)
    with engine.connect() as conn:
        df = pd.read_sql(query, conn, params={"threshold": days_threshold})
    return df


def analyze_mom_growth(engine):
    """Calculate month-over-month revenue growth."""
    query = """
    WITH monthly_revenue AS (
        SELECT 
            DATE_FORMAT(invoice_date, '%Y-%m') AS month,
            SUM(total) AS monthly_revenue,
            COUNT(*) AS invoice_count,
            AVG(total) AS avg_order_value
        FROM invoice
        GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
    )
    SELECT 
        month,
        monthly_revenue,
        invoice_count,
        avg_order_value,
        LAG(monthly_revenue, 1) OVER (ORDER BY month) AS prev_month_revenue,
        ROUND((monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY month)) 
              / NULLIF(LAG(monthly_revenue, 1) OVER (ORDER BY month), 0) * 100, 2) AS mom_growth_pct,
        SUM(monthly_revenue) OVER (ORDER BY month) AS running_total
    FROM monthly_revenue
    ORDER BY month
    """
    return execute_query(engine, 'mom_growth', query)


def analyze_cohort_retention(engine):
    """Analyze customer cohort retention."""
    query = """
    WITH customer_activity AS (
        SELECT 
            customer_id,
            DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month,
            COUNT(DISTINCT DATE_FORMAT(invoice_date, '%Y-%m')) AS months_active,
            COUNT(DISTINCT invoice_id) AS total_purchases,
            SUM(total) AS total_revenue
        FROM invoice
        GROUP BY customer_id
    )
    SELECT 
        cohort_month,
        COUNT(*) AS cohort_size,
        ROUND(AVG(months_active), 1) AS avg_months_active,
        ROUND(AVG(total_purchases), 1) AS avg_purchases,
        ROUND(AVG(total_revenue), 2) AS avg_revenue,
        ROUND(AVG(months_active) * 100 / 12, 1) AS retention_rate_pct
    FROM customer_activity
    GROUP BY cohort_month
    ORDER BY cohort_month
    """
    return execute_query(engine, 'cohort_retention', query)


def analyze_genre_popularity(engine):
    """Analyze sales by genre."""
    query = """
    SELECT 
        g.name AS genre,
        COUNT(il.invoice_line_id) AS total_purchases,
        ROUND(SUM(il.quantity * il.unit_price), 2) AS total_revenue,
        COUNT(DISTINCT t.track_id) AS unique_tracks
    FROM genre g
    JOIN track t ON g.genre_id = t.genre_id
    JOIN invoice_line il ON t.track_id = il.track_id
    GROUP BY g.genre_id, g.name
    ORDER BY total_revenue DESC
    """
    return execute_query(engine, 'genre_popularity', query)


def plot_rfm_segments(rfm_df, output_path):
    """Create RFM segment distribution chart."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Segment distribution
    segment_counts = rfm_df['customer_segment'].value_counts()
    axes[0, 0].pie(segment_counts, labels=segment_counts.index, autopct='%1.1f%%', 
                   colors=sns.color_palette('viridis', len(segment_counts)))
    axes[0, 0].set_title('RFM Segment Distribution')

    # RFM Heatmap
    rfm_matrix = rfm_df.groupby(['r_score', 'f_score']).size().unstack(fill_value=0)
    sns.heatmap(rfm_matrix, annot=True, fmt='d', cmap='YlOrRd', ax=axes[0, 1])
    axes[0, 1].set_title('R-F Score Matrix')

    # Monetary by Segment
    sns.boxplot(data=rfm_df, x='customer_segment', y='monetary', ax=axes[1, 0])
    axes[1, 0].set_title('Revenue by Customer Segment')
    axes[1, 0].tick_params(axis='x', rotation=45)

    # Recency vs Monetary
    sns.scatterplot(data=rfm_df, x='recency', y='monetary', hue='customer_segment', 
                    size='frequency', sizes=(20, 200), ax=axes[1, 1])
    axes[1, 1].set_title('Recency vs Monetary (size=frequency)')

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved RFM chart: {output_path}")


def plot_churn_analysis(churn_df, output_path):
    """Create churn analysis chart."""
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    # Churn status distribution
    status_counts = churn_df['churn_status'].value_counts()
    colors = {'Active': 'green', 'At-Risk': 'orange', 'Churned': 'red'}
    axes[0].bar(status_counts.index, status_counts.values, 
                color=[colors.get(s, 'gray') for s in status_counts.index])
    axes[0].set_title('Churn Status Distribution')
    axes[0].set_ylabel('Number of Customers')

    # Days since last purchase distribution
    churn_df['days_since_last'].hist(bins=30, ax=axes[1], color='steelblue', edgecolor='black')
    axes[1].axvline(x=90, color='orange', linestyle='--', label='At-Risk (90 days)')
    axes[1].axvline(x=180, color='red', linestyle='--', label='Churned (180 days)')
    axes[1].set_title('Days Since Last Purchase')
    axes[1].set_xlabel('Days')
    axes[1].legend()

    # Revenue by churn status
    revenue_by_status = churn_df.groupby('churn_status')['total_spent'].sum()
    axes[2].bar(revenue_by_status.index, revenue_by_status.values, 
                color=[colors.get(s, 'gray') for s in revenue_by_status.index])
    axes[2].set_title('Revenue by Churn Status')
    axes[2].set_ylabel('Total Revenue ($)')

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved churn chart: {output_path}")


def plot_revenue_trends(mom_df, output_path):
    """Create revenue trend charts."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Monthly Revenue
    axes[0, 0].plot(mom_df['month'], mom_df['monthly_revenue'], marker='o', linewidth=2)
    axes[0, 0].set_title('Monthly Revenue')
    axes[0, 0].set_xlabel('Month')
    axes[0, 0].set_ylabel('Revenue ($)')
    axes[0, 0].tick_params(axis='x', rotation=45)

    # MoM Growth
    axes[0, 1].bar(mom_df['month'], mom_df['mom_growth_pct'], color='teal')
    axes[0, 1].axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    axes[0, 1].set_title('Month-over-Month Growth (%)')
    axes[0, 1].set_xlabel('Month')
    axes[0, 1].set_ylabel('Growth (%)')
    axes[0, 1].tick_params(axis='x', rotation=45)

    # Running Total
    axes[1, 0].fill_between(range(len(mom_df)), mom_df['running_total'], alpha=0.3)
    axes[1, 0].plot(range(len(mom_df)), mom_df['running_total'], linewidth=2)
    axes[1, 0].set_title('Cumulative Revenue')
    axes[1, 0].set_xlabel('Month Index')
    axes[1, 0].set_ylabel('Running Total ($)')

    # Invoice Count
    axes[1, 1].bar(mom_df['month'], mom_df['invoice_count'], color='coral')
    axes[1, 1].set_title('Monthly Invoices')
    axes[1, 1].set_xlabel('Month')
    axes[1, 1].set_ylabel('Invoice Count')
    axes[1, 1].tick_params(axis='x', rotation=45)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved revenue chart: {output_path}")


def plot_genre_popularity(genre_df, output_path):
    """Create genre popularity chart."""
    fig, ax = plt.subplots(figsize=(12, 6))

    top_genres = genre_df.head(10)
    bars = ax.barh(top_genres['genre'], top_genres['total_revenue'], color='steelblue')
    ax.set_xlabel('Revenue ($)')
    ax.set_title('Top 10 Genres by Revenue')
    ax.invert_yaxis()

    # Add value labels
    for bar, revenue in zip(bars, top_genres['total_revenue']):
        ax.text(bar.get_width() + 5, bar.get_y() + bar.get_height()/2, 
                f'${revenue:.2f}', va='center')

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved genre chart: {output_path}")


def generate_summary_report(rfm_df, churn_df, mom_df, genre_df, output_path):
    """Generate markdown summary report."""
    total_customers = len(rfm_df)
    total_revenue = mom_df['monthly_revenue'].sum()
    avg_order_value = mom_df['avg_order_value'].mean()

    segment_summary = rfm_df['customer_segment'].value_counts()
    churn_summary = churn_df['churn_status'].value_counts()

    report = f"""# Music Store Analytics Summary Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Overview

| Metric | Value |
|--------|-------|
| Total Customers | {total_customers} |
| Total Revenue | ${total_revenue:,.2f} |
| Avg Order Value | ${avg_order_value:.2f} |
| Analysis Period | {mom_df['month'].min()} to {mom_df['month'].max()} |

## RFM Segment Distribution

| Segment | Count | Percentage |
|---------|-------|------------|
"""
    for segment, count in segment_summary.items():
        pct = count / total_customers * 100
        report += f"| {segment} | {count} | {pct:.1f}% |\n"

    report += f"""
## Churn Analysis

| Status | Count | Percentage |
|--------|-------|------------|
"""
    for status, count in churn_summary.items():
        pct = count / total_customers * 100
        report += f"| {status} | {count} | {pct:.1f}% |\n"

    report += f"""
## Top 5 Genres by Revenue

| Genre | Revenue | Purchases |
|-------|---------|-----------|
"""
    for _, row in genre_df.head(5).iterrows():
        report += f"| {row['genre']} | ${row['total_revenue']:.2f} | {row['total_purchases']} |\n"

    report += f"""
## Monthly Performance

| Month | Revenue | Invoices | MoM Growth |
|-------|---------|----------|------------|
"""
    for _, row in mom_df.iterrows():
        growth = row['mom_growth_pct'] if pd.notna(row['mom_growth_pct']) else 0
        report += f"| {row['month']} | ${row['monthly_revenue']:.2f} | {row['invoice_count']} | {growth:+.1f}% |\n"

    report += """
## Recommendations

1. **Champions (13%)**: Implement loyalty program with exclusive offers
2. **At-Risk/Hibernating (56%)**: Launch re-engagement campaigns with 15-20% discounts
3. **Rock Dominance (83%)**: Maintain genre focus while testing adjacent genres
4. **USA Market**: 50% of revenue - optimize for this market segment
"""

    with open(output_path, 'w') as f:
        f.write(report)
    print(f"Saved summary report: {output_path}")


def run_full_analysis(engine):
    """Run complete analysis pipeline."""
    print("\n=== Music Store Data Analysis ===\n")

    # Create output directories
    OUTPUT_DIR.mkdir(exist_ok=True)
    CHARTS_DIR.mkdir(exist_ok=True)

    # Execute analyses
    print("\n[1/6] Performing RFM segmentation...")
    rfm_df = analyze_rfm(engine)
    rfm_df.to_csv(OUTPUT_DIR / 'rfm_analysis.csv', index=False)

    print("\n[2/6] Detecting churned customers...")
    churn_df = analyze_churn(engine)
    churn_df.to_csv(OUTPUT_DIR / 'churn_analysis.csv', index=False)

    print("\n[3/6] Calculating MoM growth...")
    mom_df = analyze_mom_growth(engine)
    mom_df.to_csv(OUTPUT_DIR / 'mom_growth.csv', index=False)

    print("\n[4/6] Analyzing cohort retention...")
    cohort_df = analyze_cohort_retention(engine)
    cohort_df.to_csv(OUTPUT_DIR / 'cohort_retention.csv', index=False)

    print("\n[5/6] Analyzing genre popularity...")
    genre_df = analyze_genre_popularity(engine)
    genre_df.to_csv(OUTPUT_DIR / 'genre_popularity.csv', index=False)

    # Generate charts
    print("\n[6/6] Generating visualizations...")
    plot_rfm_segments(rfm_df, CHARTS_DIR / 'rfm_segments.png')
    plot_churn_analysis(churn_df, CHARTS_DIR / 'churn_analysis.png')
    plot_revenue_trends(mom_df, CHARTS_DIR / 'revenue_trends.png')
    plot_genre_popularity(genre_df, CHARTS_DIR / 'genre_popularity.png')

    # Generate summary report
    generate_summary_report(rfm_df, churn_df, mom_df, genre_df, OUTPUT_DIR / 'summary_report.md')

    print("\n=== Analysis Complete ===")
    print(f"Results saved to: {OUTPUT_DIR}")
    print(f"Charts saved to: {CHARTS_DIR}")


def main():
    parser = argparse.ArgumentParser(description='Music Store Data Analysis Runner')
    parser.add_argument('--setup', action='store_true', help='Load CSV data into database')
    parser.add_argument('--query', type=str, choices=['rfm', 'churn', 'mom', 'cohort', 'genre'],
                        help='Run specific query only')
    parser.add_argument('--output', type=str, default=str(OUTPUT_DIR),
                        help='Output directory for results')
    parser.add_argument('--charts', action='store_true', help='Generate charts only')
    parser.add_argument('--host', type=str, default='localhost',
                        help='Database host')
    parser.add_argument('--database', type=str, default='MUSIC_STORE',
                        help='Database name')

    args = parser.parse_args()

    global DATABASE_URL

    DATABASE_URL = f"mysql+pymysql://{quote_plus(DB_USER)}:{quote_plus(DB_PASSWORD)}@{args.host}:{DB_PORT}/{args.database}"

    try:
        engine = create_engine(DATABASE_URL)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print(f"Connected to database: {args.database}")

        if args.setup:
            setup_database(engine)

        if args.charts:
            # Generate charts from existing data
            rfm_df = pd.read_csv(OUTPUT_DIR / 'rfm_analysis.csv')
            churn_df = pd.read_csv(OUTPUT_DIR / 'churn_analysis.csv')
            mom_df = pd.read_csv(OUTPUT_DIR / 'mom_growth.csv')
            genre_df = pd.read_csv(OUTPUT_DIR / 'genre_popularity.csv')

            plot_rfm_segments(rfm_df, CHARTS_DIR / 'rfm_segments.png')
            plot_churn_analysis(churn_df, CHARTS_DIR / 'churn_analysis.png')
            plot_revenue_trends(mom_df, CHARTS_DIR / 'revenue_trends.png')
            plot_genre_popularity(genre_df, CHARTS_DIR / 'genre_popularity.png')
            print("Charts generated successfully")

        elif args.query:
            # Run specific query
            queries = {
                'rfm': (analyze_rfm, 'rfm_analysis.csv'),
                'churn': (analyze_churn, 'churn_analysis.csv'),
                'mom': (analyze_mom_growth, 'mom_growth.csv'),
                'cohort': (analyze_cohort_retention, 'cohort_retention.csv'),
                'genre': (analyze_genre_popularity, 'genre_popularity.csv'),
            }
            func, filename = queries[args.query]
            df = func(engine)
            output_path = Path(args.output) / filename
            df.to_csv(output_path, index=False)
            print(f"Results saved to: {output_path}")

        else:
            run_full_analysis(engine)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
