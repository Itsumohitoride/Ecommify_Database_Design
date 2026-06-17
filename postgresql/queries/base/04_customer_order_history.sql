-- Historial de ordenes de un cliente especifico con pagos
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
WHERE o.customer_id = '8d7941984c29d3bd1e5c3e5b9c5e9c3e'
ORDER BY o.order_purchase_timestamp DESC;
