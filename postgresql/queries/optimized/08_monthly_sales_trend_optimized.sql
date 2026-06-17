-- ============================================================================
-- Optimized: 08_monthly_sales_trend.sql
-- Optimization: SET work_mem to avoid Sort disk spill
--   Problem: Sort external merge of 6.9MB on 109,880 rows
--            (DATE_TRUNC grouping requires full sort)
--   Fix 1: SET work_mem = '32MB' — Sort fits in memory, no disk spill
--   Fix 2: Add explicit partition range hint to enable pruning
--   Fix 3: Pre-filter order_purchase_timestamp using the same range as
--          partition boundaries to help the planner prune partitions
-- Techniques: SET work_mem, Partition pruning optimization
-- ============================================================================

SET work_mem = '32MB';

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS gross_revenue,
    SUM(oi.freight_value) AS total_freight,
    ROUND(SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS avg_order_value
FROM "order" o
JOIN order_item oi ON o.order_id = oi.order_id AND o.order_purchase_timestamp = oi.order_purchase_timestamp
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2019-01-01'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;
