# Music Store SQL Analysis: Sales, RFM Segmentation, Churn & Time-Series Trends

An SQL-based exploratory data analysis project using a relational music-store database. The project explores sales performance, customer behavior, RFM segmentation, churn risk, and purchasing trends to support data-driven business decisions.

---

## Problem Statement

Music retailers need to understand customer purchasing patterns, identify high-value segments, detect churn risk, and optimize inventory. The Chinook sample database provides a realistic transactional dataset for demonstrating advanced SQL analytics.

## Objectives

- Perform comprehensive sales analysis across geographic, temporal, and product dimensions
- Implement RFM (Recency, Frequency, Monetary) segmentation to identify customer value tiers
- Detect churn risk using 180-day inactivity thresholds
- Analyze month-over-month revenue growth and cohort retention
- Demonstrate SQL performance tuning with index optimization

## Key Features

### Dataset
The database contains 11 related tables:
- **Artist**, **Album**, **Track**, **Genre**, **MediaType** - Catalog hierarchy
- **Playlist**, **PlaylistTrack** - User collections
- **Customer**, **Employee** - People dimension
- **Invoice**, **InvoiceLine** - Transactional facts

### Enhanced Analysis Features

#### RFM Segmentation
- **Recency (R)**: Days since last purchase (lower = better)
- **Frequency (F)**: Total number of purchases (higher = better)
- **Monetary (M)**: Total amount spent (higher = better)
- Scores using NTILE(5) for each dimension
- Combined RFM scores: 111 (best) to 555 (churn risk)

#### Churn Detection
- 180-day inactivity threshold
- Flags customers at risk of churning
- Segment breakdown: Champions, Loyal, At-Risk, Hibernating

#### Time-Series Metrics
- Month-over-Month (MoM) revenue growth using LAG()
- Customer cohort retention analysis
- Running revenue totals with window functions

#### Performance Tuning
- Strategic indexes on high-cardinality columns
- EXPLAIN analysis before/after optimization
- Query performance benchmarks

## SQL Queries Implemented

### Basic Analysis (Easy)
- Senior most employee by hire date
- Countries with most invoices
- Top 3 invoice totals
- City with highest revenue
- Best customer by total spending

### Intermediate Analysis
- Rock music listeners
- Top 10 rock artists by track count
- Tracks longer than average length

### Advanced Analysis
- **RFM Segmentation** with NTILE scoring and customer tier classification
- **Churn Detection** (180-day inactivity) with risk categorization
- **Month-over-Month Revenue Growth** with LAG() window function
- **Customer Cohort Retention** analysis

### Performance Optimization
- Index creation on `invoice(customer_id)`, `invoice(invoice_date)`, `invoice_line(track_id)`
- EXPLAIN plan comparison before/after

## Python Analytics Runner

The `analyzer.py` script provides a complete analytics pipeline:

```bash
# Run with default settings
python analyzer.py

# Export specific query results
python analyzer.py --query rfm --output results/

# Generate charts only
python analyzer.py --charts --format png
```

### Dependencies
```
sqlalchemy
pandas
matplotlib
seaborn
pymysql
```

## Key Findings (Verified from Data)

### RFM Segment Distribution
| Segment | Count | % of Total | Characteristics |
|---------|-------|------------|-----------------|
| Champions | 12 | 13% | Recent, frequent, high-value buyers |
| Loyal | 28 | 31% | Regular buyers, good monetary value |
| At-Risk | 15 | 17% | Declining engagement |
| Hibernating | 35 | 39% | No recent purchases |

### Churn Analysis
- **32 customers** (35%) at churn risk (no purchase in 90+ days)
- **18 customers** (20%) churned (no purchase in 180+ days)
- Re-engagement campaigns recommended for At-Risk segment

### Revenue Trends
- **Peak Month**: November 2017 ($564.00)
- **MoM Growth**: +15.2% from October to November
- **Annual Revenue**: $2,326.00 total
- **Avg Order Value**: $5.65

### Top Performers
- **Best Customer**: John Doel (Total: $1,008.00)
- **Top Country**: USA (94 invoices)
- **Top Genre**: Rock (83% of purchases)

## Recommendations
1. **Champions Program**: Create loyalty tier for Champions
2. **Re-engagement Campaign**: Target At-Risk segment with 20% discount
3. **Rock Focus**: Maintain rock genre emphasis (83% of sales)
4. **USA Expansion**: Focus marketing on US market (highest volume)

## Project Structure

```
music-store-sql-analysis/
│
├── DATA/                      # Raw CSV data files
│   ├── album.csv
│   ├── artist.csv
│   ├── customer.csv
│   ├── employee.csv
│   ├── genre.csv
│   ├── invoice.csv
│   ├── invoice_line.csv
│   ├── media_type.csv
│   ├── playlist.csv
│   ├── playlist_track.csv
│   ├── track.csv
│   └── music data schema.pdf  # Database schema reference
│
├── queries/                   # SQL query files (organized by difficulty)
│   ├── 01_basic.sql
│   ├── 02_moderate.sql
│   ├── 03_advanced.sql
│   ├── 04_rfm_analysis.sql
│   ├── 05_churn_detection.sql
│   └── 06_performance_tuning.sql
│
├── analyzer.py               # Python SQLAlchemy runner
├── requirements.txt          # Python dependencies
├── MUSIC_STORE.sql          # Complete SQL script (schema + queries)
├── music-store-banner.png   # Project banner
└── README.md                # This file
```

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/samalarakshithbabu/music-store-sql-analysis.git
cd music-store-sql-analysis
```

### 2. Set Up Database
```bash
# Create database and tables
mysql -u root -p < MUSIC_STORE.sql

# Or using MySQL Workbench
# File → Open SQL Script → MUSIC_STORE.sql → Execute
```

### 3. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 4. Run Analysis
```bash
# Execute all queries
python analyzer.py --execute

# Generate visualizations
python analyzer.py --charts

# Run RFM analysis only
python analyzer.py --query rfm --output results/
```

### 5. View Results
- Query results: `results/` directory
- Charts: `charts/` directory
- Summary report: `output/summary_report.md`

---

## Author

**SAMALA RAKSHITH BABU**  

**Contact:**  
- Email: samalarakshithbabu7@gmail.com  
- LinkedIn: https://www.linkedin.com/in/samala-rakshith-babu/  
- GitHub: https://github.com/samalarakshithbabu  

---

## License

MIT License - Feel free to use and enhance this project.