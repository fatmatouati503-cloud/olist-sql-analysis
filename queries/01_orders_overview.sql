-- olist-sql-analysis
-- Advanced SQL queries and data analysis exploring the Olist Brazilian e-commerce database to extract actionable business intelligence and metrics.
USE olist;
SHOW Tables;
 -- Query 1 Database scope
 SELECT
COUNT(*) AS total_orders,
MIN(order_purchase_timestamp) AS first_purchase,
MAX(order_purchase_timestamp) AS last_purchase
FROM orders;

-- 2 Electronics activity
WITH electronics_items AS (
SELECT oi.order_id, oi.seller_id, oi.price
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
'audio', 'pcs', 'informatica_acessorios',
'consoles_games', 'eletronicos', 'telefonia_fixa',
'tablets_impressao_imagem', 'telefonia'
)
)
SELECT
COUNT(*) AS item_lines,
COUNT(DISTINCT order_id) AS orders,
COUNT(DISTINCT seller_id) AS sellers,
ROUND(SUM(price), 2) AS item_revenue,
ROUND(AVG(price), 2) AS average_item_price
FROM electronics_items;

-- 3 Delivery performance
WITH electronics_orders AS (
SELECT DISTINCT oi.order_id
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
'audio', 'pcs', 'informatica_acessorios',
'consoles_games', 'eletronicos', 'telefonia_fixa',
'tablets_impressao_imagem', 'telefonia'
)
)
SELECT
COUNT(*) AS total_orders,
SUM(o.order_status = 'delivered') AS delivered_orders,
ROUND(100 * AVG(o.order_status = 'delivered'), 1) AS delivered_pct,
ROUND(100 * AVG(
CASE
WHEN o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
AND o.order_estimated_delivery_date IS NOT NULL
THEN o.order_delivered_customer_date
> o.order_estimated_delivery_date
END
), 1) AS late_delivery_pct
FROM orders AS o
JOIN electronics_orders AS e ON e.order_id = o.order_id;
 -- 4 Electronics reviews
 WITH electronics_orders AS (
SELECT DISTINCT oi.order_id
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
'audio', 'pcs', 'informatica_acessorios',
'consoles_games', 'eletronicos', 'telefonia_fixa',
'tablets_impressao_imagem', 'telefonia'
)
)
SELECT
COUNT(*) AS reviews,
ROUND(AVG(r.review_score), 2) AS average_rating,
ROUND(100 * AVG(r.review_score >= 4), 1) AS positive_review_pct,
ROUND(100 * AVG(r.review_score <= 2), 1) AS negative_review_pct
FROM order_reviews AS r
JOIN electronics_orders AS e ON e.order_id = r.order_id;
-- 5 Higher value electronics
WITH high_value_orders AS (
SELECT DISTINCT oi.order_id
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
'audio', 'pcs', 'informatica_acessorios',
'consoles_games', 'eletronicos', 'telefonia_fixa',
'tablets_impressao_imagem', 'telefonia'
)
AND oi.price >= 500
)
SELECT
COUNT(DISTINCT h.order_id) AS orders,
ROUND(AVG(r.review_score), 2) AS average_rating,
ROUND(100 * AVG(r.review_score <= 2), 1) AS negative_review_pct,
ROUND(100 * AVG(
CASE
WHEN o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
AND o.order_estimated_delivery_date IS NOT NULL
THEN o.order_delivered_customer_date
> o.order_estimated_delivery_date
END
), 1) AS late_delivery_pct
FROM high_value_orders AS h
JOIN orders AS o ON o.order_id = h.order_id
LEFT JOIN order_reviews AS r ON r.order_id = h.order_id;
-- 6 Payment mix 
WITH electronics_orders AS (
SELECT DISTINCT oi.order_id
FROM order_items AS oi
JOIN products AS p ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
'audio', 'pcs', 'informatica_acessorios',
'consoles_games', 'eletronicos', 'telefonia_fixa',
'tablets_impressao_imagem', 'telefonia'
)
)
SELECT
op.payment_type,
COUNT(*) AS payment_records,
ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
ROUND(AVG(op.payment_installments), 2) AS average_installments,
ROUND(SUM(op.payment_value), 2) AS payment_value
FROM order_payments AS op
JOIN electronics_orders AS e ON e.order_id = op.order_id
GROUP BY op.payment_type
ORDER BY payment_value DESC; 

-- 13. Delay severity vs customer satisfaction (Lumetta categories, delivered orders)
-- Goal: find out how many days of delay it takes before reviews collapse,
-- to test the "late rate under ~8%" guardrail used in the report.
-- Step 1 (order_level): collapse the view to ONE row per order, so orders with
--   several items are not counted several times. Orders without delivery date
--   or without a review are excluded.
-- Step 2: bucket delay_days (delivered date minus estimated date, in days):
--   <= 0 on time, 1-3 slightly late, 4-7 late, > 7 very late.
WITH order_level AS (
  SELECT
    order_id,
    MAX(delay_days)   AS delay_days,     -- same value for every item of the order
    AVG(review_score) AS review_score
  FROM v_order_item_base
  WHERE order_status = 'delivered'
    AND delay_days   IS NOT NULL
    AND review_score IS NOT NULL
    AND category_en IN ('computers','computers_accessories','telephony',
                        'electronics','tablets_printing_image')
  GROUP BY order_id
)
SELECT
  CASE
    WHEN delay_days <= 0 THEN '1. On time (<= 0 days)'
    WHEN delay_days <= 3 THEN '2. Late 1-3 days'
    WHEN delay_days <= 7 THEN '3. Late 4-7 days'
    ELSE                      '4. Late > 7 days'
  END AS delay_bucket,
  COUNT(*)                                          AS orders,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS share_pct,       -- share of all orders
  ROUND(AVG(review_score), 2)                       AS avg_review,
  ROUND(100 * AVG(review_score <= 2), 1)            AS negative_review_pct  -- reviews of 1 or 2 stars
FROM order_level
GROUP BY delay_bucket
ORDER BY delay_bucket;

-- 14. Same delay buckets, split by category.
-- Warning: tablets_printing_image and computers have very few late orders,
-- so their late buckets are fragile. Always read the "orders" column.
WITH order_level AS (
  SELECT
    order_id, category_en,
    MAX(delay_days)   AS delay_days,
    AVG(review_score) AS review_score
  FROM v_order_item_base
  WHERE order_status = 'delivered'
    AND delay_days   IS NOT NULL
    AND review_score IS NOT NULL
    AND category_en IN ('computers','computers_accessories','telephony',
                        'electronics','tablets_printing_image')
  GROUP BY order_id, category_en
)
SELECT
  category_en,
  CASE
    WHEN delay_days <= 0 THEN '1. On time'
    WHEN delay_days <= 3 THEN '2. Late 1-3 days'
    WHEN delay_days <= 7 THEN '3. Late 4-7 days'
    ELSE                      '4. Late > 7 days'
  END AS delay_bucket,
  COUNT(*)                    AS orders,
  ROUND(AVG(review_score), 2) AS avg_review
FROM order_level
GROUP BY category_en, delay_bucket
ORDER BY category_en, delay_bucket;

-- revenue across all product categories.
SELECT
    pct.product_category_name_english AS category,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN products p 
    ON p.product_id = oi.product_id
JOIN product_category_translation pct 
    ON pct.product_category_name = p.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

-- Monthly orders as bars, a different colour for every month:
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(*) AS num_orders
FROM orders
GROUP BY order_month
ORDER BY order_month; 

SELECT 
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 'Late' 
        ELSE 'On time' 
    END AS status,
    ROUND(AVG(r.review_score), 2) AS avg_score,
    COUNT(*) AS num_orders
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY status;

-- Window function for seller concentration 
 
 SHOW FULL TABLES FROM olist;
 USE olist;

WITH base AS (
  SELECT
    TRIM(REPLACE(t.product_category_name_english, CHAR(13), '')) AS category_en,
    oi.seller_id,
    oi.price
  FROM order_items oi
  JOIN orders o   ON o.order_id = oi.order_id
  JOIN products p ON p.product_id = oi.product_id
  JOIN product_category_translation t
       ON t.product_category_name = p.product_category_name
  WHERE o.order_status = 'delivered'
),
seller_category_revenue AS (
  SELECT category_en, seller_id, SUM(price) AS revenue
  FROM base
  WHERE category_en IN ('computers','computers_accessories','telephony',
                        'electronics','tablets_printing_image')
  GROUP BY category_en, seller_id
),
ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY category_en ORDER BY revenue DESC) AS seller_rank,
    SUM(revenue)  OVER (PARTITION BY category_en) AS category_revenue
  FROM seller_category_revenue
)
SELECT
  category_en,
  COUNT(*) AS sellers,
  ROUND(SUM(CASE WHEN seller_rank <= 5 THEN revenue ELSE 0 END)
        / MAX(category_revenue) * 100, 1) AS top5_share_pct
FROM ranked
GROUP BY category_en
ORDER BY top5_share_pct DESC;

-- -- Normalized base view: one row per order item, joining orders, order_items,
-- products, category translation, customers and reviews. Cleans the category
-- label (trailing CHAR(13)) and computes delay_days = delivered date minus
-- estimated date (> 0 means late). Reused by all analysis queries below.
USE olist;

CREATE OR REPLACE VIEW v_order_item_base AS
SELECT
  o.order_id,
  o.order_status,
  oi.seller_id,
  oi.price,
  TRIM(REPLACE(t.product_category_name_english, CHAR(13), '')) AS category_en,
  c.customer_state,
  r.review_score,
  DATEDIFF(o.order_delivered_customer_date,
           o.order_estimated_delivery_date) AS delay_days
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN product_category_translation t
     ON t.product_category_name = p.product_category_name
JOIN customers c    ON c.customer_id = o.customer_id
LEFT JOIN order_reviews r ON r.order_id = o.order_id;

-- Four-plus-table analytical join through normalized view
WITH order_scope AS ( 
SELECT order_id, category_en, customer_state, SUM(price) AS revenue, 
AVG(review_score) AS review_score, 
MAX(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END) AS late 
FROM v_order_item_base 
WHERE order_status='delivered' 
AND category_en IN ('computers','computers_accessories','telephony','electronics','tablets_printing_image') 
GROUP BY order_id, category_en, customer_state 
), payment_scope AS ( 
SELECT order_id, SUM(payment_value) AS payment_value, MAX(payment_installments) AS installments 
FROM order_payments 
GROUP BY order_id 
) 
SELECT os.category_en, os.customer_state, COUNT(*) AS orders, SUM(os.revenue) AS revenue, 
AVG(ps.payment_value) AS avg_payment, AVG(ps.installments) AS avg_installments, 
AVG(os.late) AS late_rate, AVG(os.review_score) AS avg_review 
FROM order_scope os 
JOIN payment_scope ps ON ps.order_id = os.order_id 
GROUP BY os.category_en, os.customer_state; 
