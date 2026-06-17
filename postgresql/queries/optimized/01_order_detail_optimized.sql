-- ============================================================================
-- Optimized: 01_order_detail.sql
-- Optimization: Fix JOIN condition (customer_unique_id → customer_id)
--   Original: JOIN customer c ON o.customer_id = c.customer_unique_id
--   Problem: customer_unique_id does NOT match order.customer_id (0 rows)
--   Fix:     JOIN customer c ON o.customer_id = c.customer_id
--            96,096 matches exist with correct column
-- Technique: JOIN column correction (data quality fix)
-- ============================================================================

SET work_mem = '32MB';

SELECT
    o.order_id,
    c.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    oi.order_item_id,
    p.product_id,
    pc.name_english AS category,
    oi.price,
    oi.freight_value,
    pay.payment_type,
    pay.payment_installments,
    pay.payment_value
FROM "order" o
JOIN customer c ON o.customer_id = c.customer_id         -- FIXED: was c.customer_unique_id
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
JOIN product_category pc ON p.category_name = pc.category_name
JOIN payment pay ON o.order_id = pay.order_id
WHERE o.order_id = 'd3c8851a6651eeff2f73b0e011ac45d0';
