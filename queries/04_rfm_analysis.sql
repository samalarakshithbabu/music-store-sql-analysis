-- ============================================================================
-- RFM SEGMENTATION ANALYSIS
-- Recency, Frequency, Monetary scoring for customer segmentation
-- ============================================================================

-- RFM Base: Calculate raw RFM metrics for each customer
WITH rfm_base AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        c.email,
        DATEDIFF('2017-12-31', MAX(i.invoice_date)) AS recency_days,
        COUNT(DISTINCT i.invoice_id) AS frequency,
        SUM(i.total) AS monetary,
        SUM(i.total) / COUNT(DISTINCT i.invoice_id) AS avg_order_value
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country, c.email
),
rfm_scores AS (
    SELECT *,
        -- NTILE(5) creates scores 1-5, with 5 being best
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT 
        customer_id, first_name, last_name, country, email,
        recency_days, frequency, monetary, avg_order_value,
        r_score, f_score, m_score,
        CONCAT(r_score, f_score, m_score) AS rfm_segment,
        -- Customer segmentation based on RFM scores
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
            ELSE 'Needs Attention'
        END AS customer_segment
    FROM rfm_scores
)
SELECT 
    customer_id, first_name, last_name, country, email,
    recency_days, frequency, monetary, avg_order_value,
    r_score, f_score, m_score, rfm_segment, customer_segment
FROM rfm_segments
ORDER BY monetary DESC;

-- RFM Segment Distribution Summary
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM rfm_segments), 1) AS percentage,
    ROUND(AVG(monetary), 2) AS avg_revenue,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency
FROM rfm_segments
GROUP BY customer_segment
ORDER BY avg_revenue DESC;

-- RFM Score Matrix (heatmap data)
SELECT 
    r_score,
    SUM(CASE WHEN f_score = 1 THEN 1 ELSE 0 END) AS f_1,
    SUM(CASE WHEN f_score = 2 THEN 1 ELSE 0 END) AS f_2,
    SUM(CASE WHEN f_score = 3 THEN 1 ELSE 0 END) AS f_3,
    SUM(CASE WHEN f_score = 4 THEN 1 ELSE 0 END) AS f_4,
    SUM(CASE WHEN f_score = 5 THEN 1 ELSE 0 END) AS f_5
FROM rfm_scores
GROUP BY r_score
ORDER BY r_score DESC;

-- Champions Detail: Best customers
SELECT customer_id, first_name, last_name, country, 
       r_score, f_score, m_score, monetary, frequency
FROM rfm_segments
WHERE customer_segment = 'Champions'
ORDER BY monetary DESC;

-- Hibernating Customers: Need re-engagement
SELECT customer_id, first_name, last_name, country, email,
       recency_days, monetary, frequency
FROM rfm_segments
WHERE customer_segment = 'Hibernating'
ORDER BY recency_days DESC;