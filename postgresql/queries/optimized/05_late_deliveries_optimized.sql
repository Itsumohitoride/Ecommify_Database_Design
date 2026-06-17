-- ============================================================================
-- Optimized: 05_late_deliveries.sql
-- Optimization: Add SET work_mem + index hint for partial index
--   Problem: Seq Scan on order_2017/2018 with filter on
--            delivered_customer_date > estimated_delivery_date
--            (49,067 rows filtered out in order_2018 alone)
--   Fix 1: SET work_mem = '32MB' to avoid Sort disk spills
--   Fix 2: CREATE INDEX idx_order_late ON "order"(delivered_customer_date)
--          WHERE delivered_customer_date > estimated_delivery_date
--   Fix 3: Add explicit order_purchase_timestamp range to enable partition pruning
-- Techniques: Partial index hint, SET work_mem, Partition pruning hint
-- ============================================================================

SET work_mem = '32MB';

/*
 * Recommended index for this query:
 *   CREATE INDEX IF NOT EXISTS idx_order_late
 *       ON "order"(order_delivered_customer_date)
 *       WHERE order_delivered_customer_date > order_estimated_delivery_date;
 *
 * This partial index only contains late deliveries, making it much smaller
 * than a full-table index and enabling Index Scan instead of Seq Scan.
 */

SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,
    (o.order_delivered_customer_date - o.order_estimated_delivery_date) AS days_late,
    s.seller_city,
    s.seller_state
FROM "order" o
JOIN order_item oi ON o.order_id = oi.order_id AND o.order_purchase_timestamp = oi.order_purchase_timestamp
JOIN seller s ON oi.seller_id = s.seller_id
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
  AND o.order_status = 'delivered'
  -- Add date range hint to enable partition pruning:
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2019-01-01'
ORDER BY days_late DESC
LIMIT 50;
