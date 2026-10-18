-- =====================================================================
-- FOOD DELIVERY SQL ANALYTICS PROJECT
-- PostgreSQL | Schema: customers, restaurants, orders, riders, deliveries
-- =====================================================================


-- =====================================================================
-- Q1. Data Quality Check: find NULLs in customers and restaurants
-- =====================================================================
SELECT COUNT(*) FROM customers
WHERE customer_name IS NULL
   OR reg_date IS NULL;

SELECT COUNT(*) FROM restaurants
WHERE opening_hours IS NULL
   OR city IS NULL
   OR restaurant_name IS NULL;

SELECT * FROM riders
WHERE rider_name IS NULL
   OR sign_up IS NULL;


-- =====================================================================
-- Q2. Data Cleaning: fix/remove bad rows
-- =====================================================================
UPDATE restaurants SET opening_hours = 'Not Available' WHERE opening_hours IS NULL;
UPDATE restaurants SET city = 'Unknown' WHERE city IS NULL;

-- Remove orders missing critical fields, and their orphaned deliveries first
DELETE FROM deliveries
WHERE order_id IN (
    SELECT order_id FROM orders
    WHERE order_item   IS NULL
       OR total_amount IS NULL
       OR order_time   IS NULL
       OR order_status IS NULL
       OR order_date   IS NULL
);

DELETE FROM orders
WHERE order_item   IS NULL
   OR total_amount IS NULL
   OR order_time   IS NULL
   OR order_status IS NULL
   OR order_date   IS NULL;

COMMIT;


-- =====================================================================
-- Q3. Find customers with duplicate names in the customers table
-- =====================================================================
SELECT
    customer_name,
    COUNT(*) AS times_repeated
FROM customers
GROUP BY customer_name
HAVING COUNT(*) > 1
ORDER BY times_repeated DESC;


-- =====================================================================
-- Q4. Top 5 dishes ordered by a specific customer ('Shreya Menon N.')
--     in the last 1 year
-- =====================================================================
SELECT
    customer_name,
    dishes,
    order_dish
FROM (
    SELECT
        c.customer_id,
        c.customer_name,
        o.order_item AS dishes,
        COUNT(*) AS order_dish,
        DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 Year'
      AND c.customer_name = 'Shreya Menon N.'
    GROUP BY c.customer_id, o.order_item, c.customer_name
) AS t1
WHERE rnk <= 5;


-- =====================================================================
-- Q5. Bucket all orders into 2-hour time slots, count orders per slot
-- =====================================================================
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 0  AND 1  THEN '00:00 - 02:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 2  AND 3  THEN '02:00 - 04:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 4  AND 5  THEN '04:00 - 06:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 6  AND 7  THEN '06:00 - 08:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 8  AND 9  THEN '08:00 - 10:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 10 AND 11 THEN '10:00 - 12:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 12 AND 13 THEN '12:00 - 14:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 14 AND 15 THEN '14:00 - 16:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 16 AND 17 THEN '16:00 - 18:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 18 AND 19 THEN '18:00 - 20:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 20 AND 21 THEN '20:00 - 22:00'
        WHEN EXTRACT(HOUR FROM order_time) BETWEEN 22 AND 23 THEN '22:00 - 24:00'
    END AS time_slot,
    COUNT(order_id) AS order_count
FROM orders
WHERE order_time IS NOT NULL
GROUP BY time_slot
ORDER BY order_count DESC;


-- =====================================================================
-- Q6. Average Order Value (AOV) for customers with more than 25 orders
-- =====================================================================
SELECT
    c.customer_name,
    AVG(o.total_amount) AS aov
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.customer_name
HAVING COUNT(o.order_id) > 25;


-- =====================================================================
-- Q7. High-value customers: total lifetime spend > 10,000
-- =====================================================================
SELECT
    c.customer_name,
    o.customer_id,
    SUM(total_amount) AS total_spend
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY o.customer_id, c.customer_name
HAVING SUM(total_amount) > 10000;


-- =====================================================================
-- Q8. Orders that have no matching delivery record at all
-- =====================================================================
SELECT *
FROM orders o
LEFT JOIN restaurants r ON r.restaurant_id = o.restaurant_id
LEFT JOIN deliveries d  ON d.order_id = o.order_id
WHERE d.delivery_id IS NULL;


-- =====================================================================
-- Q9. Top restaurants by revenue, for the last calendar year
--     NOTE: this window is relative to CURRENT_DATE, so it moves forward
--     every January -- confirm this is the intended behavior.
-- =====================================================================
SELECT
    r.restaurant_name,
    r.city,
    SUM(total_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(total_amount) DESC) AS rnk
FROM orders o
LEFT JOIN restaurants r ON r.restaurant_id = o.restaurant_id
WHERE o.order_date >= date_trunc('year', CURRENT_DATE) - INTERVAL '1 year'
  AND o.order_date <  date_trunc('year', CURRENT_DATE)
GROUP BY r.restaurant_name, r.city;


-- =====================================================================
-- Q10. Most-ordered dish per city (Pattern 1: Top-N per Group)
-- =====================================================================
SELECT *
FROM (
    SELECT
        r.city,
        o.order_item,
        COUNT(o.order_id) AS no_of_orders,
        RANK() OVER (PARTITION BY r.city ORDER BY COUNT(o.order_id) DESC) AS rnk
    FROM orders o
    JOIN restaurants r ON r.restaurant_id = o.restaurant_id
    GROUP BY r.city, o.order_item
) AS t1
WHERE rnk = 1;


-- =====================================================================
-- Q11. Customers who ordered in 2025 but NOT in 2026
-- =====================================================================
SELECT DISTINCT customer_id
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2025
  AND customer_id NOT IN (
      SELECT DISTINCT customer_id FROM orders
      WHERE EXTRACT(YEAR FROM order_date) = 2026
  );


-- =====================================================================
-- Q12. Order cancellation ratio per restaurant, 2025 vs 2026
-- FIX: original had two stacked `WITH` keywords (invalid) and referenced
--      an undefined CTE name (`cancel_ratio`) in the final SELECTs.
--      Rebuilt as one WITH chain, two properly comma-separated CTEs,
--      each queried in its own final SELECT.
-- =====================================================================
WITH cancel_ratio_25 AS (
    SELECT
        o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o
    LEFT JOIN deliveries d ON d.order_id = o.order_id
    WHERE EXTRACT(YEAR FROM order_date) = 2025
    GROUP BY o.restaurant_id
),
cancel_ratio_26 AS (
    SELECT
        o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o
    LEFT JOIN deliveries d ON d.order_id = o.order_id
    WHERE EXTRACT(YEAR FROM order_date) = 2026
    GROUP BY o.restaurant_id
)
SELECT
    restaurant_id,
    total_orders,
    not_delivered,
    ROUND(not_delivered::numeric / total_orders::numeric * 100, 2) AS cancel_ratio_2025
FROM cancel_ratio_25;

-- Repeat for 2026:
-- SELECT restaurant_id, total_orders, not_delivered,
--        ROUND(not_delivered::numeric / total_orders::numeric * 100, 2) AS cancel_ratio_2026
-- FROM cancel_ratio_26;


-- =====================================================================
-- Q13. Delivery time per order, in minutes, handling the overnight case
--      (delivery_time can be "earlier" than order_time if it crosses midnight)
-- =====================================================================
SELECT
    o.order_id,
    o.order_time,
    d.delivery_time,
    d.rider_id,
    d.delivery_time - o.order_time AS time_difference,
    ROUND(
        EXTRACT(EPOCH FROM (
            d.delivery_time - o.order_time
            + CASE WHEN d.delivery_time < o.order_time
                   THEN INTERVAL '1 day'
                   ELSE INTERVAL '0 day'
              END
        )) / 60
    , 2) AS time_difference_min
FROM orders o
JOIN deliveries d ON d.order_id = o.order_id
WHERE d.delivery_status = 'Delivered';


-- =====================================================================
-- Q14. Rider Ratings Analysis
--   < 15 min  -> 5-star
--   15-20 min -> 4-star
--   > 20 min  -> 3-star
--   Output: count of each rating per rider.
-- =====================================================================
WITH DeliveryRatings AS (
    SELECT
        d.rider_id,
        EXTRACT(EPOCH FROM (d.delivery_time - o.order_time)) / 60 AS diff_minutes,
        CASE
            WHEN EXTRACT(EPOCH FROM (d.delivery_time - o.order_time)) / 60 < 15 THEN '5-star'
            WHEN EXTRACT(EPOCH FROM (d.delivery_time - o.order_time)) / 60 BETWEEN 15 AND 20 THEN '4-star'
            ELSE '3-star'
        END AS rating
    FROM deliveries d
    JOIN orders o ON o.order_id = d.order_id
)
SELECT
    rider_id,
    COUNT(CASE WHEN rating = '5-star' THEN 1 END) AS five_star_count,
    COUNT(CASE WHEN rating = '4-star' THEN 1 END) AS four_star_count,
    COUNT(CASE WHEN rating = '3-star' THEN 1 END) AS three_star_count
FROM DeliveryRatings
GROUP BY rider_id
ORDER BY rider_id;


-- =====================================================================
-- Q15. Month-over-month order growth ratio, per restaurant
--      (Pattern 3: Period-over-Period Comparison, only Delivered orders)
-- =====================================================================
WITH growth_ratio AS (
    SELECT
        o.restaurant_id,
        TO_CHAR(o.order_date, 'mm-yy') AS month,
        COUNT(o.order_id) AS cr_month_orders,
        LAG(COUNT(o.order_id), 1) OVER (
            PARTITION BY o.restaurant_id ORDER BY TO_CHAR(o.order_date, 'mm-yy')
        ) AS prev_month
    FROM orders o
    JOIN deliveries d ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
    GROUP BY o.restaurant_id, TO_CHAR(o.order_date, 'mm-yy')
    ORDER BY o.restaurant_id, TO_CHAR(o.order_date, 'mm-yy')
)
SELECT
    restaurant_id,
    month,
    prev_month,
    cr_month_orders,
    ROUND((cr_month_orders::numeric - prev_month::numeric) / prev_month::numeric * 100, 2) AS growth_ratio
FROM growth_ratio;
-- NOTE: added PARTITION BY restaurant_id to the LAG() above -- without it,
-- "previous month" would pull the previous row across ALL restaurants mixed
-- together, not this restaurant's own previous month. Worth testing both ways.


-- =====================================================================
-- Q16. Customer segmentation: Gold (above avg spend) vs Silver
-- =====================================================================
SELECT
    cx_category,
    SUM(total_orders) AS total_orders,
    SUM(total_spent)  AS total_revenue
FROM (
    SELECT
        customer_id,
        SUM(total_amount) AS total_spent,
        COUNT(order_id) AS total_orders,
        CASE WHEN SUM(total_amount) > (SELECT AVG(total_amount) FROM orders)
             THEN 'Gold' ELSE 'Silver' END AS cx_category
    FROM orders
    GROUP BY customer_id
) AS t1
GROUP BY cx_category;


-- =====================================================================
-- Q17. Rider monthly earnings, assuming 8% of every delivered order's total
-- FIX: original grouped by the raw earnings value instead of SUM()-ing
--      first, and didn't separate by year (would merge Jan 2025 / Jan 2026).
-- =====================================================================
SELECT
    d.rider_id,
    EXTRACT(YEAR FROM o.order_date)  AS rider_year,
    EXTRACT(MONTH FROM o.order_date) AS rider_month,
    SUM(o.total_amount) AS total_revenue,
    ROUND(SUM(o.total_amount::numeric) * 0.08, 2) AS rider_earning
FROM orders o
JOIN deliveries d ON o.order_id = d.order_id
GROUP BY d.rider_id, EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
ORDER BY d.rider_id, rider_year, rider_month;


-- =====================================================================
-- Q18. Busiest day of the week, per restaurant
-- FIX: original grouped by the raw order_date (a single calendar date)
--      instead of the day NAME, so each "group" was really just one date,
--      not an aggregate across every occurrence of that weekday.
-- =====================================================================
SELECT *
FROM (
    SELECT
        r.restaurant_name,
        TO_CHAR(o.order_date, 'Day') AS day,
        COUNT(o.order_id) AS total_orders,
        RANK() OVER (PARTITION BY r.restaurant_name ORDER BY COUNT(o.order_id) DESC) AS rnk
    FROM orders o
    JOIN restaurants r ON o.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_name, TO_CHAR(o.order_date, 'Day')
) AS t1
WHERE rnk = 1;


-- =====================================================================
-- Q19. Customer Lifetime Value (CLV): total spend per customer
-- =====================================================================
SELECT
    o.customer_id,
    c.customer_name,
    SUM(total_amount) AS clv
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY o.customer_id, c.customer_name;


-- =====================================================================
-- Q20. Monthly total sales, compared to the previous month
--      (Pattern 3: Period-over-Period Comparison, platform-wide)
-- =====================================================================
SELECT
    EXTRACT(YEAR FROM order_date)  AS year,
    EXTRACT(MONTH FROM order_date) AS month,
    SUM(total_amount) AS total_sale,
    LAG(SUM(total_amount), 1) OVER (
        ORDER BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
    ) AS previous_month_sale
FROM orders
GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
ORDER BY year, month;


-- =====================================================================
-- Q21. Fastest and slowest rider, by average delivery time
-- FIX: original CTE chain had a trailing comma before the final SELECT
--      (invalid -- a comma means "another CTE follows"). Also extended
--      the final SELECT to return rider_id, not just the bare min/max
--      numbers, since knowing WHICH rider is the actual point.
-- =====================================================================
WITH new_table AS (
    SELECT
        d.rider_id,
        ROUND(
            EXTRACT(EPOCH FROM (
                d.delivery_time - o.order_time
                + CASE WHEN d.delivery_time < o.order_time
                       THEN INTERVAL '1 day'
                       ELSE INTERVAL '0 day'
                  END
            )) / 60
        , 2) AS time_deliver
    FROM orders o
    JOIN deliveries d ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
),
riders_time AS (
    SELECT
        rider_id,
        AVG(time_deliver) AS avg_time
    FROM new_table
    GROUP BY rider_id
)
SELECT
    rider_id,
    avg_time
FROM riders_time
WHERE avg_time = (SELECT MIN(avg_time) FROM riders_time)
   OR avg_time = (SELECT MAX(avg_time) FROM riders_time)
ORDER BY avg_time;


-- =====================================================================
-- Q22. Order volume by season (Spring / Summer / Winter)
-- NOTE: double-check the season boundaries against the actual business
-- definition -- as written, everything NOT in Apr-Jun or Jul-Aug falls
-- into "Winter" by default (i.e. Jan-Mar and Sep-Dec are all "Winter").
-- =====================================================================
SELECT
    order_item,
    seasons,
    COUNT(order_id) AS total_orders
FROM (
    SELECT
        *,
        EXTRACT(MONTH FROM order_date) AS month,
        CASE
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Spring'
            WHEN EXTRACT(MONTH FROM order_date) > 6
             AND EXTRACT(MONTH FROM order_date) < 9 THEN 'Summer'
            ELSE 'Winter'
        END AS seasons
    FROM orders
) AS t1
GROUP BY order_item, seasons
ORDER BY order_item DESC;