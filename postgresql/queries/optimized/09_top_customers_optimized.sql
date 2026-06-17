-- ============================================================================
-- Optimized: 09_top_customers_by_spend.sql
-- Optimization: Fix JOIN condition + SET work_mem
--   Original: JOIN "order" o ON c.customer_unique_id = o.customer_id
--   Problem: customer_unique_id does NOT match order.customer_id (0 rows)
--            Index Scan on customer executed 110,197 times → 237ms wasted
--   Fix:     c.customer_id = o.customer_id (96,096 matches exist)
-- Technique: JOIN column correction (data quality fix), SET work_mem
-- ============================================================================

SET work_mem = '32MB';

SELECT
    c.customer_id,
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_spent,
    MAX(o.order_purchase_timestamp) AS last_order
FROM customer c
JOIN "order" o ON c.customer_id = o.customer_id             -- FIXED: was c.customer_unique_id
JOIN order_item oi ON o.order_id = oi.order_id AND o.order_purchase_timestamp = oi.order_purchase_timestamp
WHERE o.order_status = 'delivered'
GROUP BY c.customer_id, c.customer_city, c.customer_state
ORDER BY total_spent DESC
LIMIT 20;
