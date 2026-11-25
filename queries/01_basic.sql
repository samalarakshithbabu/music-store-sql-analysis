-- ============================================================================
-- BASIC ANALYSIS QUERIES (Easy)
-- ============================================================================

-- Q1. Senior most employee by hire date
SELECT employee_id, first_name, last_name, title, hire_date
FROM employee
ORDER BY hire_date ASC
LIMIT 1;

-- Q2. Countries with most invoices
SELECT billing_country, COUNT(invoice_id) AS invoice_count
FROM invoice
GROUP BY billing_country
ORDER BY invoice_count DESC;

-- Q3. Top 3 invoice totals
SELECT total, invoice_id, invoice_date, billing_city, billing_country
FROM invoice
ORDER BY total DESC
LIMIT 3;

-- Q4. City with highest revenue
SELECT billing_city, billing_country, SUM(total) AS revenue
FROM invoice
GROUP BY billing_city, billing_country
ORDER BY revenue DESC
LIMIT 1;

-- Q5. Best customer by total spending
SELECT c.customer_id, c.first_name, c.last_name, c.country, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 1;

-- Q6. Average invoice value
SELECT ROUND(AVG(total), 2) AS avg_invoice_value
FROM invoice;

-- Q7. Invoice count by month
SELECT DATE_FORMAT(invoice_date, '%Y-%m') AS month, COUNT(*) AS invoice_count
FROM invoice
GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
ORDER BY month;

-- Q8. Top 5 countries by revenue
SELECT billing_country, COUNT(*) AS invoice_count, ROUND(SUM(total), 2) AS total_revenue
FROM invoice
GROUP BY billing_country
ORDER BY total_revenue DESC
LIMIT 5;

-- Q9. Customer count by country
SELECT country, COUNT(*) AS customer_count
FROM customer
GROUP BY country
ORDER BY customer_count DESC;

-- Q10. Employees by title
SELECT title, COUNT(*) AS employee_count
FROM employee
GROUP BY title;