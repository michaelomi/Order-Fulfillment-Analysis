# 📦 E-commerce Order Fulfillment Analysis Report

### 🚀 Executive Summary
This project analyzes the 2023 order fulfillment performance of an e-commerce store using SQL. By examining shipping times, delivery delays, return rates, and distribution center efficiency, I identified operational strengths and bottlenecks. Insights from JOINs, GROUP BY, CTEs, and window functions inform recommendations to optimize delivery, reduce returns, and enhance distribution efficiency, showcasing my data-driven approach to e-commerce operations.

## 1. 📬 Order Fulfillment Performance

### 1.1 🚚 Average Time to Ship and Deliver
- **Average Days to Ship**: 1 day
- **Average Days to Deliver**: 3 days
- **Insight**: Fast shipping (1 day) supports efficient order processing, but delivery time (3 days) suggests potential for improvement in logistics.
```sql
SELECT
    AVG(DATEDIFF(DAY,created_at,shipped_at)) AS avg_days_to_ship,
	AVG(DATEDIFF(DAY,created_at,delivered_at)) AS avg_days_to_deliv
FROM orders;
```

### 1.2 🔄 Return Rates by Product Category
- **Highest Return Rate**: Jumpsuits & Rompers (11.42%) 👗
- **Insight**: High return rates in specific categories indicate potential issues with product fit, quality, or customer expectations, requiring targeted improvements.
```sql
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
```

### 1.3 📉 Top 5 Products with Highest Return Rates by Distribution Center
- **Analysis**: Identified top 5 products with highest return rates per distribution center using CTEs and ROW_NUMBER().
- **Insight**: High return rates for specific products vary by distribution center, suggesting localized issues in inventory quality or customer preferences.
```sql
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
```

## 2. 🏭 Distribution Center Performance

### 2.1 ⏳ Percentage of Delayed Orders
- **Highest Delay Rate**: Chicago IL (51.51% of orders delayed beyond expected delivery) ⚠️
- **Insight**: Chicago IL’s high delay rate indicates logistical inefficiencies, potentially due to operational bottlenecks or carrier issues.
```sql
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
```

### 2.2 🏆 Best Performing Distribution Centers
- **Top Ranked**: Charleston SC and Chicago IL (3 days average delivery time) 🎯
- **Insight**: Despite Chicago IL’s high delay rate, it matches Charleston SC in average delivery time, suggesting inconsistent performance.
```sql
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
```

### 2.3 💰 Total and Average Revenue by Distribution Center
- **Top Performers**:
  - Houston TX: $1,579,721.83 total revenue, $69.52 avg revenue 🥇
  - Memphis TN: $1,418,119.34 total revenue, $58.75 avg revenue
  - Chicago IL: $1,332,911.20 total revenue, $55.65 avg revenue
- **Insight**: Houston TX leads in revenue generation, indicating strong sales volume or higher-value products.
```sql
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
```

## 3. 🔑 Key Insights
- **Fulfillment Efficiency**: Fast shipping (1 day) is a strength, but delivery time (3 days) and delays (e.g., Chicago IL: 51.51%) highlight logistical challenges 📉.
- **Returns**: Jumpsuits & Rompers (11.42%) have the highest return rates, suggesting quality or sizing issues 👗.
- **Distribution Performance**: Houston TX drives the most revenue, while Chicago IL shows mixed performance with fast delivery but high delays 🏭.
- **Data Analysis**: SQL queries using CTEs, JOINs, and window functions enabled precise identification of operational bottlenecks.

## 4. 🛠️ Recommendations
1. **Optimize Delivery Processes**:
   - Investigate Chicago IL’s high delay rate (51.51%) and optimize logistics or carrier partnerships 🚚.
   - Aim to reduce average delivery time below 3 days through streamlined operations.
2. **Reduce Return Rates**:
   - Address high returns for Jumpsuits & Rompers with improved sizing guides, quality checks, or customer feedback analysis 🎁.
   - Analyze product-specific return rates by distribution center to identify quality issues.
3. **Enhance Distribution Center Efficiency**:
   - Leverage Houston TX’s high revenue performance by allocating more high-demand products 🥇.
   - Standardize Chicago IL’s operations to match Charleston SC’s consistent delivery performance.
4. **Improve Data-Driven Operations**:
   - Implement real-time tracking for delivery delays and returns 📊.
   - Use predictive analytics to forecast demand and optimize inventory allocation 🔍.

## 5. 🎯 Conclusion
This analysis highlights the e-commerce store’s efficient shipping (1 day) but identifies opportunities to reduce delivery delays (Chicago IL: 51.51%) and high return rates (Jumpsuits & Rompers: 11.42%). By optimizing logistics, improving product quality, and leveraging high-performing distribution centers like Houston TX, the store can enhance customer satisfaction and profitability. This project demonstrates my expertise in SQL-based analysis and operational optimization for e-commerce.

*Analysis conducted using SQL queries on orders, products, and distribution datasets. View the full code in the [repository](https://github.com/michaelomi/Order-Fulfillment-Analysis/blob/main/Orders%20%26%20Fulfillment%20Analysis.sql).*
