-- =============================================
-- DDL Completo ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â MÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³dulo Transaccional Ecommify
-- PostgreSQL 15+ ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Esquema 3FN
-- =============================================

-- ENUM personalizados
CREATE TYPE order_status_enum AS ENUM (
    'created', 'approved', 'invoiced', 'processing',
    'shipped', 'delivered', 'canceled', 'unavailable'
);

CREATE TYPE payment_type_enum AS ENUM (
    'credit_card', 'debit_card', 'boleto', 'voucher', 'not_defined'
);

-- 1. GEOLOCATION (resuelve violaciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n 1FN)
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
    CONSTRAINT pk_customer          PRIMARY KEY (customer_unique_id),
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
    specifications               JSONB,
    photo_urls                   TEXT[],
    CONSTRAINT pk_product           PRIMARY KEY (product_id),
    CONSTRAINT fk_product_cat       FOREIGN KEY (category_name)
        REFERENCES product_category (category_name)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Migracion para DB existentes: columnas avanzadas en product
ALTER TABLE product ADD COLUMN IF NOT EXISTS specifications JSONB;
ALTER TABLE product ADD COLUMN IF NOT EXISTS photo_urls TEXT[];

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
    promotion_period                TSTZRANGE,
    CONSTRAINT pk_order              PRIMARY KEY (order_id, order_purchase_timestamp),
    CONSTRAINT fk_order_customer     FOREIGN KEY (customer_id)
        REFERENCES customer (customer_unique_id)
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

-- Migracion para DB existentes: columna promotion_period en order
ALTER TABLE "order" ADD COLUMN IF NOT EXISTS promotion_period TSTZRANGE;

-- 7. ORDER_ITEM (entidad dÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©bil, resuelve 2FN)
CREATE TABLE IF NOT EXISTS order_item (
    order_id            CHAR(32)        NOT NULL,
    order_item_id       SMALLINT        NOT NULL,
    order_purchase_timestamp TIMESTAMPTZ     NOT NULL,
    product_id          CHAR(32)        NOT NULL,
    seller_id           CHAR(32)        NOT NULL,
    shipping_limit_date TIMESTAMPTZ     NOT NULL,
    price               NUMERIC(10,2)   NOT NULL,
    freight_value       NUMERIC(10,2)   NOT NULL,
    CONSTRAINT pk_order_item   PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_oi_order     FOREIGN KEY (order_id, order_purchase_timestamp) REFERENCES "order" (order_id, order_purchase_timestamp)
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
    order_purchase_timestamp TIMESTAMPTZ     NOT NULL,
    payment_type          payment_type_enum NOT NULL,
    payment_installments  SMALLINT          NOT NULL,
    payment_value         NUMERIC(10,2)     NOT NULL,
    CONSTRAINT pk_payment           PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payment_order     FOREIGN KEY (order_id, order_purchase_timestamp) REFERENCES "order" (order_id, order_purchase_timestamp)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_pay_install CHECK (payment_installments >= 0),
    CONSTRAINT ck_pay_value CHECK (payment_value >= 0)
);

-- 9. REVIEW
CREATE TABLE IF NOT EXISTS review (
    review_id               CHAR(32)       NOT NULL,
    order_id                CHAR(32)       NOT NULL,
    order_purchase_timestamp TIMESTAMPTZ     NOT NULL,
    review_score            SMALLINT       NOT NULL,
    review_comment_title    VARCHAR(50),
    review_comment_message  VARCHAR(300),
    review_creation_date    TIMESTAMPTZ    NOT NULL,
    review_answer_timestamp TIMESTAMPTZ,
    CONSTRAINT pk_review           PRIMARY KEY (review_id),
    CONSTRAINT fk_review_order     FOREIGN KEY (order_id, order_purchase_timestamp) REFERENCES "order" (order_id, order_purchase_timestamp)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_review_score     CHECK (review_score BETWEEN 1 AND 5)
);

-- =============================================
-- ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂNDICES EXPLÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂCITOS
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

-- Indices avanzados (tipos especializados)
CREATE INDEX IF NOT EXISTS idx_product_specifications ON product USING GIN (specifications);
CREATE INDEX IF NOT EXISTS idx_product_photo_urls     ON product USING GIN (photo_urls);
CREATE INDEX IF NOT EXISTS idx_order_promotion_period ON "order" USING GIST (promotion_period);

-- =============================================
-- VISTAS GEOGRÃƒÆ’ï¿½FICAS (tipo POINT para operador <->)
-- =============================================

CREATE OR REPLACE VIEW customer_geo AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.zip_code_prefix,
    c.customer_city,
    c.customer_state,
    POINT(g.longitude, g.latitude) AS location
FROM customer c
LEFT JOIN geolocation g ON g.zip_code_prefix = c.zip_code_prefix;

CREATE OR REPLACE VIEW seller_geo AS
SELECT
    s.seller_id,
    s.zip_code_prefix,
    s.seller_city,
    s.seller_state,
    POINT(g.longitude, g.latitude) AS location
FROM seller s
LEFT JOIN geolocation g ON g.zip_code_prefix = s.zip_code_prefix;
