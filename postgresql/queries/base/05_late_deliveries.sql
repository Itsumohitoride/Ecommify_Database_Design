-- Ordenes entregadas despues de la fecha estimada
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
ORDER BY days_late DESC
LIMIT 50;
