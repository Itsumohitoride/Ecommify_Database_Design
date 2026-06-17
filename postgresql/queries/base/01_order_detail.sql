-- Detalle completo de una orden con sus ítems y pagos
SELECT
    o.order_id,
    c.customer_unique_id,
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
JOIN customer c ON o.customer_id = c.customer_unique_id
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
JOIN product_category pc ON p.category_name = pc.category_name
JOIN payment pay ON o.order_id = pay.order_id
WHERE o.order_id = 'o1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6';
