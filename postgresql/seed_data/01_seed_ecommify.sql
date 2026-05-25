-- =============================================
-- Seed Data — Módulo Transaccional Ecommify
-- Datos de ejemplo representativos
-- =============================================

-- GEOLOCATION
INSERT INTO geolocation VALUES
    ('01001', -23.5475, -46.6361, 'Sao Paulo', 'SP'),
    ('20040', -22.9035, -43.2096, 'Rio de Janeiro', 'RJ');

-- PRODUCT_CATEGORY
INSERT INTO product_category VALUES
    ('moveis_decoracao', 'furniture_decor'),
    ('eletronicos', 'electronics');

-- CUSTOMER
INSERT INTO customer (customer_id, customer_unique_id, zip_code_prefix, customer_city, customer_state)
VALUES ('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6', 'uniq_001', '01001', 'Sao Paulo', 'SP');

-- SELLER
INSERT INTO seller (seller_id, zip_code_prefix, seller_city, seller_state)
VALUES ('v1w2x3y4z5a6b7c8d9e0f1a2b3c4d5e6', '20040', 'Rio de Janeiro', 'RJ');

-- PRODUCT
INSERT INTO product (product_id, category_name, product_name_lenght, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
VALUES ('p1q2r3s4t5u6v7w8x9y0z1a2b3c4d5e6', 'eletronicos', 15, 350.00, 30.0, 10.0, 20.0);

-- ORDER
INSERT INTO "order" (order_id, customer_id, order_status, order_purchase_timestamp, order_estimated_delivery_date)
VALUES ('o1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6', 'uniq_001', 'created',
        '2017-05-15 10:30:00-03', '2017-05-25 23:59:59-03');

-- ORDER_ITEM
INSERT INTO order_item (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
VALUES ('o1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6', 1, 'p1q2r3s4t5u6v7w8x9y0z1a2b3c4d5e6',
        'v1w2x3y4z5a6b7c8d9e0f1a2b3c4d5e6', '2017-05-18 23:59:59-03', 199.90, 15.50);

-- PAYMENT
INSERT INTO payment (order_id, payment_sequential, payment_type, payment_installments, payment_value)
VALUES ('o1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6', 1, 'credit_card', 3, 199.90);

-- REVIEW
INSERT INTO review (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp)
VALUES ('r1s2t3u4v5w6x7y8z9a0b1c2d3e4f5g6', 'o1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6', 5,
        'Otimo', 'Produto chegou antes do prazo!', '2017-05-26 08:00:00-03', '2017-05-26 09:15:00-03');
