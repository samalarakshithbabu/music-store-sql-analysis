-- ============================================================================
-- ADVANCED ANALYSIS QUERIES
-- ============================================================================

-- Q1. Customer spending on best-selling artist
WITH BestSellingArtist AS (
    SELECT ar.artist_id, ar.name, SUM(il.quantity * il.unit_price) AS total_sales
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
    GROUP BY ar.artist_id
    ORDER BY total_sales DESC
    LIMIT 1
)
SELECT c.customer_id, c.first_name, c.last_name, 
       bsa.name AS artist_name,
       ROUND(SUM(il.quantity * il.unit_price), 2) AS amount_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN BestSellingArtist bsa ON al.artist_id = bsa.artist_id
GROUP BY c.customer_id, c.first_name, c.last_name, bsa.name
ORDER BY amount_spent DESC;

-- Q2. Most popular genre per country
WITH GenrePurchases AS (
    SELECT c.country, g.genre_id, g.name AS genre_name,
           SUM(il.quantity) AS total_purchases
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY c.country, g.genre_id, g.name
),
RankedGenres AS (
    SELECT country, genre_name, total_purchases,
           RANK() OVER (PARTITION BY country ORDER BY total_purchases DESC) AS genre_rank
    FROM GenrePurchases
)
SELECT country, genre_name AS top_genre, total_purchases
FROM RankedGenres
WHERE genre_rank = 1
ORDER BY country;

-- Q3. Highest-spending customer per country
WITH CustomerSpending AS (
    SELECT c.country, c.customer_id, c.first_name, c.last_name,
           SUM(i.total) AS amount_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.country, c.customer_id, c.first_name, c.last_name
),
RankedCustomers AS (
    SELECT country, customer_id, first_name, last_name, amount_spent,
           RANK() OVER (PARTITION BY country ORDER BY amount_spent DESC) AS spend_rank
    FROM CustomerSpending
)
SELECT country, customer_id, first_name, last_name, amount_spent
FROM RankedCustomers
WHERE spend_rank = 1
ORDER BY country;

-- Q4. Track purchase frequency
SELECT t.name AS track_name, g.name AS genre,
       COUNT(il.invoice_line_id) AS purchase_count,
       ROUND(AVG(il.unit_price), 2) AS avg_price
FROM track t
JOIN genre g ON t.genre_id = g.genre_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY t.track_id
ORDER BY purchase_count DESC
LIMIT 10;

-- Q5. Monthly customer acquisition
SELECT DATE_FORMAT(MIN(i.invoice_date), '%Y-%m') AS cohort_month,
       c.country,
       COUNT(DISTINCT c.customer_id) AS new_customers
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY DATE_FORMAT(MIN(i.invoice_date), '%Y-%m'), c.country
ORDER BY cohort_month;

-- Q6. Revenue by hour of day
SELECT HOUR(i.invoice_date) AS hour_of_day,
       COUNT(*) AS invoice_count,
       ROUND(SUM(i.total), 2) AS total_revenue
FROM invoice i
GROUP BY HOUR(i.invoice_date)
ORDER BY hour_of_day;

-- Q7. Customer lifetime value
SELECT c.customer_id, c.first_name, c.last_name,
       COUNT(DISTINCT i.invoice_id) AS total_orders,
       ROUND(SUM(i.total), 2) AS total_revenue,
       ROUND(DATEDIFF('2017-12-31', MIN(i.invoice_date))) AS customer_lifetime_days,
       ROUND(SUM(i.total) / NULLIF(COUNT(DISTINCT i.invoice_id), 0), 2) AS avg_order_value
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY total_revenue DESC
LIMIT 10;

-- Q8. Album value analysis
SELECT al.title AS album_title, ar.name AS artist_name,
       g.name AS genre,
       COUNT(t.track_id) AS track_count,
       ROUND(SUM(il.quantity * il.unit_price), 2) AS album_revenue,
       ROUND(AVG(il.quantity), 2) AS avg_tracks_per_purchase
FROM album al
JOIN artist ar ON al.artist_id = ar.artist_id
JOIN track t ON al.album_id = t.album_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY al.album_id
ORDER BY album_revenue DESC
LIMIT 10;