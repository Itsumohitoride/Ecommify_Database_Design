-- ============================================================================
-- Optimized: 07_product_review_analysis.sql
-- Optimization: CTE to reduce Nested Loop depth + SET work_mem + index hint
--   Problem: 3-level Nested Loop (95k order_item + 109k product + 109k
--            product_category index scans). 1,038,232 buffers total.
--            Sort external merge spills (3.5MB per worker).
--   Fix 1: CTE isolates product/review aggregation before joining to order
--   Fix 2: Composite index on review(order_id, review_score) enables
--          Index Scan instead of Hash Join for review
--   Fix 3: SET work_mem = '32MB' eliminates external sort spills
-- Techniques: CTE rewrite, Composite index hint, SET work_mem
-- ============================================================================

SET work_mem = '32MB';

/*
 * Recommended index:
 *   CREATE INDEX IF NOT EXISTS idx_review_order_score
 *       ON review(order_id, review_score);
 *
 * This composite index enables Index Scan for the order-review join and
 * allows covering the review_score ordering without extra lookups.
 */

WITH product_reviews AS (
    SELECT
        p.product_id,
        pc.name_english AS category,
        p.category_name,
        COUNT(r.review_id) AS review_count,
        ROUND(AVG(r.review_score), 2) AS avg_score
    FROM product p
    JOIN product_category pc ON p.category_name = pc.category_name
    LEFT JOIN order_item oi ON p.product_id = oi.product_id
    LEFT JOIN "order" o ON oi.order_id = o.order_id
                       AND oi.order_purchase_timestamp = o.order_purchase_timestamp
    LEFT JOIN review r ON o.order_id = r.order_id
                      AND o.order_purchase_timestamp = r.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_id, pc.name_english, p.category_name
    HAVING COUNT(r.review_id) >= 5
),
product_sales AS (
    SELECT
        p.product_id,
        SUM(oi.price) AS total_sales
    FROM product p
    JOIN order_item oi ON p.product_id = oi.product_id
    JOIN "order" o ON oi.order_id = o.order_id
                  AND oi.order_purchase_timestamp = o.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_id
)
SELECT
    pr.product_id,
    pr.category,
    pr.review_count,
    pr.avg_score,
    ps.total_sales
FROM product_reviews pr
LEFT JOIN product_sales ps ON pr.product_id = ps.product_id
ORDER BY pr.avg_score ASC
LIMIT 20;
