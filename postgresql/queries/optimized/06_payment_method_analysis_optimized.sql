-- ============================================================================
-- Optimized: 06_payment_method_analysis.sql
-- Optimization: SET work_mem + partial index hint + CTE rewrite
--   Problem: Sort external merge (5.5MB spill) on 100,756 payment rows
--            Seq Scan on payment (103,886 rows) without useful index
--   Fix 1: SET work_mem = '32MB' — eliminates external sort spill
--   Fix 2: Partial index on payment_type for boleto/voucher (Q6 filters by
--          o.order_status = 'delivered' only, not by payment_type directly,
--          but index on payment(order_id) helps the Hash Join)
--   Fix 3: Rewrite with CTE to pre-filter orders by status first
-- Techniques: SET work_mem, CTE rewrite, Partial index hint
-- ============================================================================

SET work_mem = '32MB';

/*
 * Recommended index:
 *   CREATE INDEX IF NOT EXISTS idx_pay_order_id ON payment(order_id);
 *
 * Also consider:
 *   CREATE INDEX IF NOT EXISTS idx_payment_type_partial
 *       ON payment(payment_type)
 *       WHERE payment_type IN ('boleto', 'voucher');
 *
 * Note: The partial index on specific payment types would help if there are
 * queries filtering by payment_type. For the current query, the main bottleneck
 * is the Sort spill, fixed by SET work_mem.
 */

WITH delivered_orders AS (
    SELECT order_id, order_purchase_timestamp
    FROM "order"
    WHERE order_status = 'delivered'
)
SELECT
    pay.payment_type,
    COUNT(DISTINCT pay.order_id) AS total_orders,
    COUNT(*) AS total_payments,
    SUM(pay.payment_value) AS total_value,
    ROUND(AVG(pay.payment_value), 2) AS avg_payment,
    ROUND(AVG(pay.payment_installments), 1) AS avg_installments
FROM payment pay
JOIN delivered_orders o
    ON pay.order_id = o.order_id
   AND pay.order_purchase_timestamp = o.order_purchase_timestamp
GROUP BY pay.payment_type
ORDER BY total_value DESC;
