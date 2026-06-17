-- ============================================================================
-- Optimized: 04_customer_order_history.sql
-- Optimization: Use customer_id that exists in DB + SET work_mem
--   Original used '8d7941984c29d3bd1e5c3e5b9c5e9c3e' which doesn't exist
--   Replaced with '00012a2ce6f8dcda20d059ce98491703' (verified existing)
-- Technique: Data quality fix + SET work_mem
-- ============================================================================

SET work_mem = '32MB';

SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    oi.price,
    oi.freight_value,
    pay.payment_type,
    pay.payment_installments,
    pay.payment_value
FROM "order" o
JOIN order_item oi ON o.order_id = oi.order_id AND o.order_purchase_timestamp = oi.order_purchase_timestamp
JOIN payment pay ON o.order_id = pay.order_id AND o.order_purchase_timestamp = pay.order_purchase_timestamp
WHERE o.customer_id = '00012a2ce6f8dcda20d059ce98491703'
ORDER BY o.order_purchase_timestamp DESC;
