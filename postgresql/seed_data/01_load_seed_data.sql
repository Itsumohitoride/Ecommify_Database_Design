-- Seed Data Loader -- Ecommify (Olist dataset)
SET session_replication_role = replica;

-- 1. GEOLOCATION
CREATE TEMP TABLE tmp_geo (zip TEXT, lat TEXT, lng TEXT, city TEXT, state TEXT);
\copy tmp_geo FROM '/src/data/olist_geolocation_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO geolocation (zip_code_prefix, latitude, longitude, city, state)
SELECT DISTINCT ON (zip) zip, lat::numeric(9,6), lng::numeric(9,6), city, state
FROM tmp_geo ON CONFLICT (zip_code_prefix) DO NOTHING;
DROP TABLE tmp_geo;
SELECT '01 geolocation: ' || count(*)::text FROM geolocation;

-- 2. PRODUCT_CATEGORY
CREATE TEMP TABLE tmp_cat (name TEXT, name_en TEXT);
\copy tmp_cat FROM '/src/data/product_category_name_translation.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO product_category (category_name, name_english) SELECT name, name_en FROM tmp_cat
ON CONFLICT (category_name) DO NOTHING;
DROP TABLE tmp_cat;
SELECT '02 product_category: ' || count(*)::text FROM product_category;

-- 3. CUSTOMER
CREATE TEMP TABLE tmp_cust (id TEXT, uid TEXT, zip TEXT, city TEXT, state TEXT);
\copy tmp_cust FROM '/src/data/olist_customers_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO customer (customer_id, customer_unique_id, zip_code_prefix, customer_city, customer_state)
SELECT id, uid, zip, city, state FROM tmp_cust
ON CONFLICT (customer_unique_id) DO NOTHING;
DROP TABLE tmp_cust;
SELECT '03 customer: ' || count(*)::text FROM customer;

-- 4. SELLER
CREATE TEMP TABLE tmp_sell (id TEXT, zip TEXT, city TEXT, state TEXT);
\copy tmp_sell FROM '/src/data/olist_sellers_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO seller (seller_id, zip_code_prefix, seller_city, seller_state)
SELECT id, zip, city, state FROM tmp_sell
ON CONFLICT (seller_id) DO NOTHING;
DROP TABLE tmp_sell;
SELECT '04 seller: ' || count(*)::text FROM seller;

-- 5. PRODUCT
CREATE TEMP TABLE tmp_prod (id TEXT, cat TEXT, nl TEXT, dl TEXT, pq TEXT, wg TEXT, lc TEXT, hc TEXT, wc TEXT);
\copy tmp_prod FROM '/src/data/olist_products_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO product (product_id, category_name, product_name_lenght, product_description_lenght,
    product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT id, cat,
    nullif(nl,'')::smallint, nullif(dl,'')::smallint, nullif(pq,'')::smallint,
    CASE WHEN wg IS NULL OR wg = '' OR wg::numeric(8,2) <= 0 THEN NULL ELSE wg::numeric(8,2) END,
    nullif(lc,'')::numeric(6,2), nullif(hc,'')::numeric(6,2), nullif(wc,'')::numeric(6,2)
FROM tmp_prod ON CONFLICT (product_id) DO NOTHING;
DROP TABLE tmp_prod;
SELECT '05 product: ' || count(*)::text FROM product;

-- 6. ORDER (partitioned)
CREATE TEMP TABLE tmp_ord (
    id TEXT, cid TEXT, status TEXT, ts TIMESTAMPTZ, aa TEXT, dcc TEXT, dcu TEXT, edd TEXT
);
\copy tmp_ord (id, cid, status, ts, aa, dcc, dcu, edd) FROM '/src/data/olist_orders_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO "order" (order_id, customer_id, order_status, order_purchase_timestamp,
    order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date)
SELECT id, cid, status::order_status_enum, ts,
    nullif(aa,'')::timestamptz, nullif(dcc,'')::timestamptz, nullif(dcu,'')::timestamptz, edd::timestamptz
FROM tmp_ord ON CONFLICT (order_id, order_purchase_timestamp) DO NOTHING;
DROP TABLE tmp_ord;
SELECT '06 order: ' || count(*)::text FROM "order";

-- 7. ORDER_ITEM
CREATE TEMP TABLE tmp_oi (oid TEXT, iid TEXT, pid TEXT, sid TEXT, sld TEXT, pr TEXT, fv TEXT);
\copy tmp_oi FROM '/src/data/olist_order_items_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO order_item (order_id, order_item_id, order_purchase_timestamp,
    product_id, seller_id, shipping_limit_date, price, freight_value)
SELECT oi.oid, oi.iid::smallint, o.order_purchase_timestamp,
    oi.pid, oi.sid, oi.sld::timestamptz, oi.pr::numeric(10,2), oi.fv::numeric(10,2)
FROM tmp_oi oi JOIN "order" o ON o.order_id = oi.oid
ON CONFLICT (order_id, order_item_id) DO NOTHING;
DROP TABLE tmp_oi;
SELECT '07 order_item: ' || count(*)::text FROM order_item;

-- 8. PAYMENT
CREATE TEMP TABLE tmp_pay (oid TEXT, seq TEXT, type TEXT, inst TEXT, val TEXT);
\copy tmp_pay FROM '/src/data/olist_order_payments_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO payment (order_id, payment_sequential, order_purchase_timestamp,
    payment_type, payment_installments, payment_value)
SELECT p.oid, p.seq::smallint, o.order_purchase_timestamp,
    p.type::payment_type_enum, p.inst::smallint, p.val::numeric(10,2)
FROM tmp_pay p JOIN "order" o ON o.order_id = p.oid
ON CONFLICT (order_id, payment_sequential) DO NOTHING;
DROP TABLE tmp_pay;
SELECT '08 payment: ' || count(*)::text FROM payment;

-- 9. REVIEW
CREATE TEMP TABLE tmp_rev (rid TEXT, oid TEXT, sc TEXT, ct TEXT, msg TEXT, cd TEXT, at TEXT);
\copy tmp_rev FROM '/src/data/olist_order_reviews_dataset.csv' WITH (FORMAT CSV, HEADER);
INSERT INTO review (review_id, order_id, order_purchase_timestamp, review_score,
    review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp)
SELECT r.rid, r.oid, o.order_purchase_timestamp, r.sc::smallint,
    nullif(r.ct,''), nullif(r.msg,''), r.cd::timestamptz, nullif(r.at,'')::timestamptz
FROM tmp_rev r JOIN "order" o ON o.order_id = r.oid
ON CONFLICT (review_id) DO NOTHING;
DROP TABLE tmp_rev;
SELECT '09 review: ' || count(*)::text FROM review;

SET session_replication_role = origin;

SELECT 'FINAL COUNTS' AS info;
SELECT 'geolocation' AS t, count(*) FROM geolocation
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'customer', count(*) FROM customer
UNION ALL SELECT 'seller', count(*) FROM seller
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'order_item', count(*) FROM order_item
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'review', count(*) FROM review
ORDER BY t;