-- ORDER FULFILLMENT
-- Average time to ship and deliver orders
SELECT
    AVG(DATEDIFF(DAY,created_at,shipped_at)) AS avg_days_to_ship,
	AVG(DATEDIFF(DAY,created_at,delivered_at)) AS avg_days_to_deliv
FROM orders;
-- avg_days_to_ship = 1,	avg_days_to_deliv = 3


-- Percentage of orders returned by product category.
SELECT A.category,
       COUNT(DISTINCT B.order_id) AS total_orders,
       COUNT(DISTINCT C.order_id) AS returned_orders,
       ROUND((CAST(COUNT(DISTINCT C.order_id) AS FLOAT) /
	          COUNT(DISTINCT B.order_id)) * 100, 2) AS return_percentage
FROM products A
JOIN order_items B 
  ON A.id = B.product_id
LEFT JOIN order_items C 
  ON B.order_id = C.order_id AND C.status = 'Returned'
GROUP BY A.category
ORDER BY return_percentage DESC;
-- Jumpsuits & Rompers had the highest return percentage at 11.42%


-- For each distribution center, top 5 products with the highest return rates.
WITH pct_data AS (
    SELECT 
        D.id AS distribution_id, 
        P.id AS products_id, 
        CAST(COUNT(RR.order_id) * 100.0 / COUNT(O.order_id) AS DECIMAL(10, 2)) AS pct_returned
    FROM distribution_centers D
    JOIN products P ON D.id = P.distribution_center_id
    JOIN order_items O ON P.id = O.product_id
    LEFT JOIN order_items RR ON O.order_id = RR.order_id AND RR.status = 'returned'
    GROUP BY D.id, P.id
),
ranked_data AS (
    SELECT 
        distribution_id, 
        products_id, 
        pct_returned,
        ROW_NUMBER() OVER (PARTITION BY distribution_id ORDER BY pct_returned DESC) AS row_num
    FROM pct_data
)
SELECT 
    distribution_id, 
    products_id, 
    pct_returned
FROM ranked_data
WHERE row_num <= 5;


-- Percentage of orders delayed beyond the expected delivery date by distribution center
WITH avg_delivery_time AS (
    SELECT AVG(DATEDIFF(DAY, shipped_at, delivered_at)) AS avg_delivery_time
    FROM order_items
    WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL
),
late_delivery_counts AS (
    SELECT inventory.product_distribution_center_id, COUNT(*) AS late_order_count
    FROM order_items
    JOIN inventory_items AS inventory ON order_items.inventory_item_id = inventory.id
    CROSS JOIN avg_delivery_time
    WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL
      AND DATEDIFF(DAY, shipped_at, delivered_at) > avg_delivery_time.avg_delivery_time
    GROUP BY inventory.product_distribution_center_id
),
total_order_counts AS (
    SELECT inventory.product_distribution_center_id, COUNT(*) AS total_order_count
    FROM order_items
    JOIN inventory_items AS inventory ON order_items.inventory_item_id = inventory.id
    WHERE delivered_at IS NOT NULL
    GROUP BY inventory.product_distribution_center_id
)
SELECT late_counts.product_distribution_center_id,
       CAST(late_counts.late_order_count * 100.0 / NULLIF(total_counts.total_order_count, 0) AS DECIMAL(10, 2)) AS percentage_of_late_orders
FROM late_delivery_counts AS late_counts
JOIN total_order_counts AS total_counts
    ON late_counts.product_distribution_center_id = total_counts.product_distribution_center_id
ORDER BY percentage_of_late_orders DESC;
-- Distribution center Chicago IL has the highest percentage of late orders at 51.51%


-- Best Performing Distribution Center:
-- Rank distribution centers based on their average time to deliver products.
SELECT name, avg_days_to_deliver,
  DENSE_RANK() OVER(ORDER BY avg_days_to_deliver DESC) AS rank
FROM (
SELECT A.name, 
  AVG(DATEDIFF(DAY,C.created_at,C.delivered_at)) avg_days_to_deliver
FROM distribution_centers A
JOIN inventory_items B
  ON A.id = B.product_distribution_center_id
JOIN order_items C
  ON B.id = C.inventory_item_id
WHERE C.delivered_at IS NOT NULL
GROUP BY A.name) Z;
-- Charleston SC and Chicago IL are ranked first with 3 days average to deliver


-- Total and Average Revenue by Distribution Centre.
SELECT A.name, 
       ROUND(SUM(C.sale_price), 2) AS total_revenue,
	   ROUND(AVG(C.sale_price), 2) AS avg_revenue
FROM distribution_centers A
JOIN products B
     ON A.id = B.distribution_center_id
JOIN order_items C
     ON B.id = C.product_id
GROUP BY A.name
ORDER BY total_revenue DESC;