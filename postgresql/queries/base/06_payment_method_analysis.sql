-- Distribucion de métodos de pago y valores
SELECT
    pay.payment_type,
    COUNT(DISTINCT pay.order_id) AS total_orders,
    COUNT(*) AS total_payments,
    SUM(pay.payment_value) AS total_value,
    ROUND(AVG(pay.payment_value), 2) AS avg_payment,
    ROUND(AVG(pay.payment_installments), 1) AS avg_installments
FROM payment pay
JOIN "order" o ON pay.order_id = o.order_id AND pay.order_purchase_timestamp = o.order_purchase_timestamp
WHERE o.order_status = 'delivered'
GROUP BY pay.payment_type
ORDER BY total_value DESC;
