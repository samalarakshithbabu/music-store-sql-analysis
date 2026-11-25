-- ============================================================================
-- CHURN DETECTION ANALYSIS
-- Identifies customers at risk of churning based on purchase inactivity
-- ============================================================================

-- Churn Analysis Base
WITH last_purchase AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        c.email,
        COALESCE(MAX(i.invoice_date), c.created_date) AS last_purchase_date,
        DATEDIFF('2017-12-31', COALESCE(MAX(i.invoice_date), c.created_date)) AS days_since_last,
        COUNT(i.invoice_id) AS total_orders,
        COALESCE(SUM(i.total), 0) AS total_spent
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country, c.email, c.created_date
),
churn_segments AS (
    SELECT *,
        CASE 
            WHEN days_since_last > 180 THEN 'Churned'
            WHEN days_since_last > 90 THEN 'At Risk'
            WHEN days_since_last > 60 THEN 'Dormant'
            ELSE 'Active'
        END AS churn_status,
        CASE 
            WHEN days_since_last > 180 THEN 4
            WHEN days_since_last > 90 THEN 3
            WHEN days_since_last > 60 THEN 2
            ELSE 1
        END AS churn_risk_score
    FROM last_purchase
)
SELECT 
    customer_id, first_name, last_name, country, email,
    last_purchase_date, days_since_last, total_orders, total_spent,
    churn_status, churn_risk_score
FROM churn_segments
ORDER BY days_since_last DESC;

-- Churn Status Summary
SELECT 
    churn_status,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM churn_segments), 1) AS percentage,
    ROUND(AVG(total_spent), 2) AS avg_spent,
    ROUND(AVG(total_orders), 1) AS avg_orders
FROM churn_segments
GROUP BY churn_status
ORDER BY churn_risk_score DESC;

-- Customers at Risk (90-180 days inactive)
SELECT customer_id, first_name, last_name, country, email,
       days_since_last, total_orders, total_spent
FROM churn_segments
WHERE churn_status = 'At Risk'
ORDER BY total_spent DESC;

-- Churned Customers (180+ days inactive)
SELECT customer_id, first_name, last_name, country, email,
       days_since_last, total_orders, total_spent
FROM churn_segments
WHERE churn_status = 'Churned'
ORDER BY total_spent DESC;

-- High-Value Churned Customers (for win-back campaigns)
SELECT customer_id, first_name, last_name, country, email,
       days_since_last, total_orders, total_spent
FROM churn_segments
WHERE churn_status = 'Churned' AND total_spent > 50
ORDER BY total_spent DESC;

-- Customer Activity Timeline
SELECT 
    DATE_FORMAT(invoice_date, '%Y-%m') AS month,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(*) AS total_invoices,
    ROUND(SUM(total), 2) AS monthly_revenue
FROM invoice
GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
ORDER BY month;

-- Reactivation Recommendations
SELECT 
    customer_id, first_name, last_name, email, country,
    days_since_last, total_spent,
    CASE 
        WHEN total_spent > 100 THEN 'Premium Reactivation Campaign'
        WHEN total_spent > 50 THEN 'Standard Reactivation Campaign'
        ELSE 'Basic Re-engagement Email'
    END AS recommended_action
FROM churn_segments
WHERE churn_status IN ('At Risk', 'Dormant')
ORDER BY total_spent DESC;