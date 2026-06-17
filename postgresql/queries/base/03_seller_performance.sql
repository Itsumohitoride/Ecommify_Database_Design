-- Desempeño de sellers: ordenes, ingresos, freight promedio, review score
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM seller s
JOIN order_item oi ON s.seller_id = oi.seller_id
JOIN "order" o ON oi.order_id = o.order_id AND oi.order_purchase_timestamp = o.order_purchase_timestamp
LEFT JOIN review r ON o.order_id = r.order_id AND o.order_purchase_timestamp = r.order_purchase_timestamp
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 20;
