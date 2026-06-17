-- Distribucion geografica de ventas por estado
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review,
    COUNT(DISTINCT s.seller_id) AS unique_sellers
FROM customer c
JOIN "order" o ON c.customer_unique_id = o.customer_id
JOIN order_item oi ON o.order_id = oi.order_id AND o.order_purchase_timestamp = oi.order_purchase_timestamp
LEFT JOIN review r ON o.order_id = r.order_id AND o.order_purchase_timestamp = r.order_purchase_timestamp
LEFT JOIN seller s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;
