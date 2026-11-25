-- ============================================================================
-- PERFORMANCE TUNING: Index Analysis with EXPLAIN
-- ============================================================================

-- STEP 1: Check current query performance (before indexes)
-- Run EXPLAIN on a common query pattern

EXPLAIN 
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
WHERE i.invoice_date >= '2017-01-01'
GROUP BY c.customer_id;

EXPLAIN 
SELECT g.name, COUNT(*) AS track_count
FROM genre g
JOIN track t ON g.genre_id = t.genre_id
GROUP BY g.genre_id;

EXPLAIN
SELECT 
    c.customer_id,
    COUNT(DISTINCT i.invoice_id) AS frequency,
    SUM(i.total) AS monetary
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id;

-- STEP 2: Create Indexes for Performance

-- Invoice table indexes (high cardinality columns)
CREATE INDEX idx_invoice_customer_id ON invoice(customer_id);
CREATE INDEX idx_invoice_date ON invoice(invoice_date);
CREATE INDEX idx_invoice_total ON invoice(total);
CREATE INDEX idx_invoice_billing_country ON invoice(billing_country);

-- InvoiceLine table indexes (join and filter columns)
CREATE INDEX idx_invoiceline_invoice_id ON invoice_line(invoice_id);
CREATE INDEX idx_invoiceline_track_id ON invoice_line(track_id);

-- Track table indexes (join and filter columns)
CREATE INDEX idx_track_album_id ON track(album_id);
CREATE INDEX idx_track_genre_id ON track(genre_id);
CREATE INDEX idx_track_media_type_id ON track(media_type_id);

-- Customer table indexes
CREATE INDEX idx_customer_country ON customer(country);
CREATE INDEX idx_customer_email ON customer(email);

-- STEP 3: Verify Performance Improvement (after indexes)

EXPLAIN 
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
WHERE i.invoice_date >= '2017-01-01'
GROUP BY c.customer_id;

EXPLAIN 
SELECT g.name, COUNT(*) AS track_count
FROM genre g
JOIN track t ON g.genre_id = t.genre_id
GROUP BY g.genre_id;

EXPLAIN
SELECT 
    c.customer_id,
    COUNT(DISTINCT i.invoice_id) AS frequency,
    SUM(i.total) AS monetary
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id;

-- STEP 4: Analyze Table Statistics
ANALYZE TABLE invoice;
ANALYZE TABLE invoice_line;
ANALYZE TABLE track;
ANALYZE TABLE customer;

-- STEP 5: Query Optimization Examples

-- BEFORE: Non-optimized query
-- SELECT * FROM invoice WHERE YEAR(invoice_date) = 2017;

-- AFTER: Optimized with index
-- SELECT * FROM invoice WHERE invoice_date >= '2017-01-01' AND invoice_date < '2018-01-01';

-- BEFORE: Correlated subquery (slow)
-- SELECT c.customer_id, 
--        (SELECT SUM(total) FROM invoice WHERE customer_id = c.customer_id) AS total_spent
-- FROM customer c;

-- AFTER: JOIN with aggregation (fast)
-- SELECT c.customer_id, SUM(i.total) AS total_spent
-- FROM customer c
-- LEFT JOIN invoice i ON c.customer_id = i.customer_id
-- GROUP BY c.customer_id;

-- STEP 6: Composite Index Example for RFM Analysis
CREATE INDEX idx_invoice_cust_date_total ON invoice(customer_id, invoice_date, total);

-- Verify the composite index is used
EXPLAIN
SELECT customer_id, SUM(total)
FROM invoice
WHERE invoice_date >= '2017-01-01'
GROUP BY customer_id;

-- STEP 7: Performance Monitoring Query
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_size_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_size_mb
FROM information_schema.tables
WHERE table_schema = 'MUSIC_STORE'
ORDER BY DATA_LENGTH DESC;

-- STEP 8: Slow Query Log Analysis (if enabled)
-- SELECT * FROM mysql.slow_log 
-- WHERE start_time > DATE_SUB(NOW(), INTERVAL 24 HOUR)
-- ORDER BY query_time DESC;