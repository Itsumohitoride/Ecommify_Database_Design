-- Productos con peores reviews (min 5 reviews)
SELECT
    p.product_id,
    pc.name_english AS category,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS avg_score,
    SUM(oi.price) AS total_sales
FROM product p
JOIN product_category pc ON p.category_name = pc.category_name
JOIN order_item oi ON p.product_id = oi.product_id
JOIN "order" o ON oi.order_id = o.order_id AND oi.order_purchase_timestamp = o.order_purchase_timestamp
JOIN review r ON o.order_id = r.order_id AND o.order_purchase_timestamp = r.order_purchase_timestamp
WHERE o.order_status = 'delivered'
GROUP BY p.product_id, pc.name_english
HAVING COUNT(r.review_id) >= 5
ORDER BY avg_score ASC
LIMIT 20;
