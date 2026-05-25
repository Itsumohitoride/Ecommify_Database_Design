-- =============================================
-- DDL Completo — Módulo Transaccional Ecommify
-- PostgreSQL 15+ · Esquema 3FN
-- =============================================

-- ENUM personalizados
CREATE TYPE order_status_enum AS ENUM (
    'created', 'approved', 'invoiced', 'processing',
    'shipped', 'delivered', 'canceled', 'unavailable'
);

CREATE TYPE payment_type_enum AS ENUM (
    'credit_card', 'debit_card', 'boleto', 'voucher', 'not_defined'
);

-- 1. GEOLOCATION (resuelve violación 1FN)
CREATE TABLE IF NOT EXISTS geolocation (
    zip_code_prefix  CHAR(5)       NOT NULL,
    latitude         NUMERIC(9,6)  NOT NULL,
    longitude        NUMERIC(9,6)  NOT NULL,
    city             VARCHAR(60)   NOT NULL,
    state            CHAR(2)       NOT NULL,
    CONSTRAINT pk_geolocation PRIMARY KEY (zip_code_prefix)
);

-- 2. PRODUCT_CATEGORY (resuelve dependencia transitiva 3FN)
CREATE TABLE IF NOT EXISTS product_category (
    category_name  VARCHAR(100)  NOT NULL,
    name_english   VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_product_category PRIMARY KEY (category_name)
);

-- 3. CUSTOMER
CREATE TABLE IF NOT EXISTS customer (
    customer_id         CHAR(32)    NOT NULL,
    customer_unique_id  CHAR(32)    NOT NULL,
    zip_code_prefix     CHAR(5),
    customer_city       VARCHAR(60),
    customer_state      CHAR(2),
    CONSTRAINT pk_customer          PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_unique   UNIQUE (customer_unique_id),
    CONSTRAINT fk_customer_geo      FOREIGN KEY (zip_code_prefix)
        REFERENCES geolocation (zip_code_prefix)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 4. SELLER
CREATE TABLE IF NOT EXISTS seller (
    seller_id        CHAR(32)   NOT NULL,
    zip_code_prefix  CHAR(5),
    seller_city      VARCHAR(60) NOT NULL,
    seller_state     CHAR(2)    NOT NULL,
    CONSTRAINT pk_seller         PRIMARY KEY (seller_id),
    CONSTRAINT fk_seller_geo     FOREIGN KEY (zip_code_prefix)
        REFERENCES geolocation (zip_code_prefix)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 5. PRODUCT
CREATE TABLE IF NOT EXISTS product (
    product_id                  CHAR(32)        NOT NULL,
    category_name               VARCHAR(100),
    product_name_lenght         SMALLINT        CHECK (product_name_lenght >= 0),
    product_description_lenght  SMALLINT        CHECK (product_description_lenght >= 0),
    product_photos_qty          SMALLINT        CHECK (product_photos_qty >= 0),
    product_weight_g            NUMERIC(8,2)    CHECK (product_weight_g > 0),
    product_length_cm           NUMERIC(6,2)    CHECK (product_length_cm > 0),
    product_height_cm           NUMERIC(6,2)    CHECK (product_height_cm > 0),
    product_width_cm            NUMERIC(6,2)    CHECK (product_width_cm > 0),
    CONSTRAINT pk_product           PRIMARY KEY (product_id),
    CONSTRAINT fk_product_cat       FOREIGN KEY (category_name)
        REFERENCES product_category (category_name)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 6. ORDER (particionada por fecha)
CREATE TABLE IF NOT EXISTS "order" (
    order_id                        CHAR(32)           NOT NULL,
    customer_id                     CHAR(32)           NOT NULL,
    order_status                    order_status_enum  NOT NULL,
    order_purchase_timestamp        TIMESTAMPTZ        NOT NULL,
    order_approved_at               TIMESTAMPTZ,
    order_delivered_carrier_date    TIMESTAMPTZ,
    order_delivered_customer_date   TIMESTAMPTZ,
    order_estimated_delivery_date   TIMESTAMPTZ        NOT NULL,
    CONSTRAINT pk_order              PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer     FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) PARTITION BY RANGE (order_purchase_timestamp);

CREATE TABLE order_2016 PARTITION OF "order"
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE order_2017 PARTITION OF "order"
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE order_2018 PARTITION OF "order"
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE order_future PARTITION OF "order"
    FOR VALUES FROM ('2019-01-01') TO (MAXVALUE);

-- 7. ORDER_ITEM (entidad débil, resuelve 2FN)
CREATE TABLE IF NOT EXISTS order_item (
    order_id            CHAR(32)        NOT NULL,
    order_item_id       SMALLINT        NOT NULL,
    product_id          CHAR(32)        NOT NULL,
    seller_id           CHAR(32)        NOT NULL,
    shipping_limit_date TIMESTAMPTZ     NOT NULL,
    price               NUMERIC(10,2)   NOT NULL,
    freight_value       NUMERIC(10,2)   NOT NULL,
    CONSTRAINT pk_order_item   PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_oi_order     FOREIGN KEY (order_id)
        REFERENCES "order" (order_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_oi_product   FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_oi_seller    FOREIGN KEY (seller_id)
        REFERENCES seller (seller_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_oi_price     CHECK (price > 0),
    CONSTRAINT ck_oi_freight   CHECK (freight_value >= 0)
);

-- 8. PAYMENT
CREATE TABLE IF NOT EXISTS payment (
    order_id              CHAR(32)          NOT NULL,
    payment_sequential    SMALLINT          NOT NULL,
    payment_type          payment_type_enum NOT NULL,
    payment_installments  SMALLINT          NOT NULL,
    payment_value         NUMERIC(10,2)     NOT NULL,
    CONSTRAINT pk_payment           PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payment_order     FOREIGN KEY (order_id)
        REFERENCES "order" (order_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_pay_install       CHECK (payment_installments >= 1),
    CONSTRAINT ck_pay_value         CHECK (payment_value > 0)
);

-- 9. REVIEW
CREATE TABLE IF NOT EXISTS review (
    review_id               CHAR(32)       NOT NULL,
    order_id                CHAR(32)       NOT NULL,
    review_score            SMALLINT       NOT NULL,
    review_comment_title    VARCHAR(50),
    review_comment_message  VARCHAR(300),
    review_creation_date    TIMESTAMPTZ    NOT NULL,
    review_answer_timestamp TIMESTAMPTZ,
    CONSTRAINT pk_review           PRIMARY KEY (review_id),
    CONSTRAINT fk_review_order     FOREIGN KEY (order_id)
        REFERENCES "order" (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_review_score     CHECK (review_score BETWEEN 1 AND 5)
);

-- =============================================
-- ÍNDICES EXPLÍCITOS
-- =============================================
CREATE UNIQUE INDEX idx_customer_unique_id ON customer (customer_unique_id);
CREATE INDEX idx_customer_zip              ON customer (zip_code_prefix);
CREATE INDEX idx_order_customer            ON "order"  (customer_id);
CREATE INDEX idx_order_status              ON "order"  (order_status);
CREATE INDEX idx_order_purchase_ts         ON "order"  (order_purchase_timestamp);
CREATE INDEX idx_order_status_ts           ON "order"  (order_status, order_purchase_timestamp);
CREATE INDEX idx_oi_product                ON order_item (product_id);
CREATE INDEX idx_oi_seller                 ON order_item (seller_id);
CREATE INDEX idx_pay_order                 ON payment (order_id);
CREATE INDEX idx_pay_type                  ON payment (payment_type);
CREATE INDEX idx_rev_score                 ON review  (review_score);
CREATE INDEX idx_prod_category             ON product (category_name);
