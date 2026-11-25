-- ============================================================================
-- MODERATE ANALYSIS QUERIES
-- ============================================================================

-- Q1. Rock music listeners - email, first name, last name
SELECT DISTINCT c.email, c.first_name, c.last_name, g.name AS genre
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE g.name = 'Rock'
ORDER BY c.email;

-- Q2. Top 10 rock artists by track count
SELECT a.name AS artist_name, COUNT(t.track_id) AS track_count
FROM artist a
JOIN album al ON a.artist_id = al.artist_id
JOIN track t ON al.album_id = t.album_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE g.name = 'Rock'
GROUP BY a.artist_id
ORDER BY track_count DESC
LIMIT 10;

-- Q3. Tracks longer than average length
SELECT name, milliseconds, ROUND(milliseconds / 60000, 2) AS minutes
FROM track
WHERE milliseconds > (SELECT AVG(milliseconds) FROM track)
ORDER BY milliseconds DESC;

-- Q4. Albums per artist
SELECT a.name AS artist, COUNT(al.album_id) AS album_count
FROM artist a
LEFT JOIN album al ON a.artist_id = al.artist_id
GROUP BY a.artist_id
ORDER BY album_count DESC;

-- Q5. Total tracks per genre
SELECT g.name AS genre, COUNT(t.track_id) AS track_count
FROM genre g
LEFT JOIN track t ON g.genre_id = t.genre_id
GROUP BY g.genre_id
ORDER BY track_count DESC;

-- Q6. Customer spending by country
SELECT c.country, COUNT(DISTINCT c.customer_id) AS customer_count,
       ROUND(SUM(i.total), 2) AS total_revenue,
       ROUND(AVG(i.total), 2) AS avg_order_value
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY total_revenue DESC;

-- Q7. Top selling tracks
SELECT t.name AS track_name, a.title AS album_title, ar.name AS artist_name,
       SUM(il.quantity) AS total_quantity_sold,
       ROUND(SUM(il.quantity * il.unit_price), 2) AS total_revenue
FROM track t
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY t.track_id
ORDER BY total_revenue DESC
LIMIT 10;

-- Q8. Playlist track count
SELECT p.name AS playlist_name, COUNT(pt.track_id) AS track_count
FROM playlist p
JOIN playlist_track pt ON p.playlist_id = pt.playlist_id
GROUP BY p.playlist_id
ORDER BY track_count DESC;

-- Q9. Media type distribution
SELECT m.name AS media_type, COUNT(t.track_id) AS track_count
FROM media_type m
LEFT JOIN track t ON m.media_type_id = t.media_type_id
GROUP BY m.media_type_id
ORDER BY track_count DESC;

-- Q10. Composer track count
SELECT CASE 
         WHEN composer IS NULL THEN 'Unknown'
         ELSE composer
       END AS composer_name,
       COUNT(*) AS track_count
FROM track
GROUP BY composer
ORDER BY track_count DESC
LIMIT 10;