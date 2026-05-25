-- Análisis de ventas por categoría (último trimestre 2017)
SELECT
    pc.name_english AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS gross_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_score
FROM "order" o
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
JOIN product_category pc ON p.category_name = pc.category_name
LEFT JOIN review r ON o.order_id = r.order_id
WHERE o.order_purchase_timestamp >= '2017-10-01'
  AND o.order_purchase_timestamp <  '2018-01-01'
  AND o.order_status = 'delivered'
GROUP BY pc.name_english
ORDER BY gross_revenue DESC;
