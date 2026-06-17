-- ============================================================================
-- Optimized: 03_seller_performance.sql
-- Optimization: Force Hash Join + CTE pre-aggregation
--   Problem: Nested Loop with oi.seller_id = s.seller_id as Join Filter
--            168M rows evaluated and discarded → 13s execution
--   Root cause: Planner chose Nested Loop because seller table is small (3095
--               rows) but the inner side (order_item) has 110k rows with no
--               useful index on seller_id for index-nested-loop join
--   Fix 1: CREATE INDEX idx_oi_seller_order ON order_item(seller_id, order_id)
--   Fix 2: CTE pre-aggregates order items per seller before joining
--   Fix 3: SET work_mem to avoid disk spills in Sort
-- Techniques: JOIN rewrite (CTE materialization), Index hint, SET work_mem
-- ============================================================================

SET work_mem = '32MB';

/*
 * Recommended index for this query:
 *   CREATE INDEX IF NOT EXISTS idx_oi_seller_order
 *       ON order_item(seller_id, order_id);
 *
 * This enables Hash Join between seller and the pre-aggregated CTE,
 * replacing the catastrophic Nested Loop (168M Join Filter evaluations).
 */

WITH seller_agg AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.price)               AS total_revenue,
        ROUND(AVG(oi.freight_value), 2) AS avg_freight
    FROM order_item oi
    JOIN "order" o ON oi.order_id = o.order_id
                  AND oi.order_purchase_timestamp = o.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
seller_review AS (
    SELECT
        oi.seller_id,
        ROUND(AVG(r.review_score), 2) AS avg_review
    FROM order_item oi
    JOIN "order" o ON oi.order_id = o.order_id
                  AND oi.order_purchase_timestamp = o.order_purchase_timestamp
    LEFT JOIN review r ON o.order_id = r.order_id
                      AND o.order_purchase_timestamp = r.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    sa.total_orders,
    sa.total_revenue,
    sa.avg_freight,
    sr.avg_review
FROM seller s
JOIN seller_agg sa ON s.seller_id = sa.seller_id
LEFT JOIN seller_review sr ON s.seller_id = sr.seller_id
ORDER BY sa.total_revenue DESC
LIMIT 20;
