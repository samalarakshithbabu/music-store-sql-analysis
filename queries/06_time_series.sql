-- ============================================================================
-- TIME-SERIES ANALYSIS
-- Month-over-month growth, cohort retention, running totals
-- ============================================================================

-- Q1. Month-over-Month Revenue Growth
WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(invoice_date, '%Y-%m') AS month,
        SUM(total) AS monthly_revenue,
        COUNT(*) AS invoice_count,
        AVG(total) AS avg_order_value,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM invoice
    GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
)
SELECT 
    month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    invoice_count,
    ROUND(avg_order_value, 2) AS avg_order_value,
    unique_customers,
    LAG(monthly_revenue, 1) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND((monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY month)) 
          / NULLIF(LAG(monthly_revenue, 1) OVER (ORDER BY month), 0) * 100, 2) AS mom_growth_pct,
    SUM(monthly_revenue) OVER (ORDER BY month) AS running_total
FROM monthly_revenue
ORDER BY month;

-- Q2. Customer Cohort Retention Analysis
WITH customer_first_purchase AS (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(invoice_date, '%Y-%m')) AS cohort_month
    FROM invoice
    GROUP BY customer_id
),
monthly_activity AS (
    SELECT 
        cfp.customer_id,
        cfp.cohort_month,
        DATE_FORMAT(i.invoice_date, '%Y-%m') AS activity_month,
        COUNT(DISTINCT i.invoice_id) AS orders
    FROM customer_first_purchase cfp
    JOIN invoice i ON cfp.customer_id = i.customer_id
    GROUP BY cfp.customer_id, cfp.cohort_month, DATE_FORMAT(i.invoice_date, '%Y-%m')
)
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN activity_month = cohort_month THEN customer_id END) AS m0_active,
    COUNT(DISTINCT CASE WHEN activity_month > cohort_month THEN customer_id END) AS retained,
    ROUND(COUNT(DISTINCT CASE WHEN activity_month > cohort_month THEN customer_id END) 
          * 100.0 / NULLIF(COUNT(DISTINCT customer_id), 0), 1) AS retention_pct
FROM monthly_activity
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q3. Running Revenue Totals by Country
WITH country_monthly AS (
    SELECT 
        DATE_FORMAT(i.invoice_date, '%Y-%m') AS month,
        i.billing_country AS country,
        SUM(i.total) AS monthly_revenue
    FROM invoice i
    GROUP BY DATE_FORMAT(i.invoice_date, '%Y-%m'), i.billing_country
)
SELECT 
    month,
    country,
    monthly_revenue,
    SUM(monthly_revenue) OVER (PARTITION BY country ORDER BY month) AS running_total
FROM country_monthly
ORDER BY country, month;

-- Q4. Weekly Revenue Pattern
SELECT 
    DAYNAME(invoice_date) AS day_of_week,
    COUNT(*) AS invoice_count,
    ROUND(SUM(total), 2) AS total_revenue,
    ROUND(AVG(total), 2) AS avg_order
FROM invoice
GROUP BY DAYNAME(invoice_date), WEEKDAY(invoice_date)
ORDER BY WEEKDAY(invoice_date);

-- Q5. Revenue by Day of Month
SELECT 
    DAY(invoice_date) AS day,
    COUNT(*) AS invoice_count,
    ROUND(SUM(total), 2) AS daily_revenue
FROM invoice
GROUP BY DAY(invoice_date)
ORDER BY day;

-- Q6. Quarter-over-Quarter Comparison
WITH quarterly_revenue AS (
    SELECT 
        QUARTER(invoice_date) AS quarter,
        YEAR(invoice_date) AS year,
        SUM(total) AS quarterly_revenue
    FROM invoice
    GROUP BY QUARTER(invoice_date), YEAR(invoice_date)
)
SELECT 
    CONCAT(year, '-Q', quarter) AS period,
    quarterly_revenue,
    LAG(quarterly_revenue, 1) OVER (ORDER BY year, quarter) AS prev_quarter,
    ROUND((quarterly_revenue - LAG(quarterly_revenue, 1) OVER (ORDER BY year, quarter)) 
          / NULLIF(LAG(quarterly_revenue, 1) OVER (ORDER BY year, quarter), 0) * 100, 2) AS qoq_growth_pct
FROM quarterly_revenue
ORDER BY year, quarter;

-- Q7. Cumulative Purchases by Customer
WITH customer_purchases AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        i.invoice_date,
        i.total,
        SUM(i.total) OVER (PARTITION BY c.customer_id ORDER BY i.invoice_date) AS cumulative_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    ORDER BY c.customer_id, i.invoice_date
)
SELECT *
FROM customer_purchases
WHERE cumulative_spent < 100;

-- Q8. Moving Average Revenue (7-day rolling)
SELECT 
    DATE(invoice_date) AS date,
    ROUND(SUM(total), 2) AS daily_revenue,
    ROUND(AVG(SUM(total)) OVER (ORDER BY DATE(invoice_date) 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7day_avg
FROM invoice
GROUP BY DATE(invoice_date)
ORDER BY date;