-- ============================================================================
-- 02_indexes_ecommify.sql
-- Indexes especializados para optimización de consultas Ecommify
-- Basado en análisis de Etapa 1.1 (EXPLAIN ANALYZE) y Etapa 1.2 (Indexación)
-- Fecha: 2026-06-07
-- ============================================================================

-- 1. Compuesto: idx_oi_seller_order sobre order_item(seller_id, order_id)
--    Propósito: Crítico para Q3 (seller_performance). Permite Hash Join
--               entre seller y order_item en lugar del Nested Loop catastrófico
--               que evaluaba 168M filas en Join Filter (13s de ejecución).
--    Técnica: B-tree compuesto (seller_id, order_id)
--    Consultas beneficiadas: Q3, Q5, Q10
CREATE INDEX IF NOT EXISTS idx_oi_seller_order
    ON order_item(seller_id, order_id);

-- 2. Compuesto: idx_review_order_score sobre review(order_id, review_score)
--    Propósito: Beneficia Q7 (product_review_analysis) al permitir Index Scan
--               en review en lugar de Seq Scan dentro del Hash Join.
--               Reduce el Nested Loop profundo de 3 niveles y elimina
--               ~1M de buffers de lectura.
--    Técnica: B-tree compuesto (order_id, review_score)
--    Consultas beneficiadas: Q2, Q3, Q7, Q10
CREATE INDEX IF NOT EXISTS idx_review_order_score
    ON review(order_id, review_score);

-- 3. Simple: idx_oi_order_id sobre order_item(order_id)
--    Propósito: Elimina Seq Scan de 56k filas en order_item. Permite
--               Index Nested Loop en lugar de Parallel Hash Join en
--               consultas que filtran por order_id.
--    Técnica: B-tree simple
--    Consultas beneficiadas: Q2, Q5, Q6, Q7, Q8, Q9, Q10
CREATE INDEX IF NOT EXISTS idx_oi_order_id
    ON order_item(order_id);

-- 4. Simple: idx_review_order_id sobre review(order_id)
--    Propósito: Elimina Seq Scan de 49k filas en review para LEFT JOINs.
--    Técnica: B-tree simple
--    Consultas beneficiadas: Q2, Q3, Q7, Q10
CREATE INDEX IF NOT EXISTS idx_review_order_id
    ON review(order_id);

-- 5. Simple: idx_customer_id sobre customer(customer_id)
--    Propósito: Habilita JOIN eficiente entre customer y order usando
--               customer_id. Las consultas Q1, Q9, Q10 usaban customer_unique_id
--               lo cual retornaba 0 filas. Con este índice, el JOIN por
--               customer_id se vuelve Index Scan.
--    Técnica: B-tree simple (UNIQUE)
--    Consultas beneficiadas: Q1, Q9, Q10
CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_id
    ON customer(customer_id);

-- 6. Parcial: idx_order_late sobre order(order_delivered_customer_date)
--    Condición: WHERE order_delivered_customer_date > order_estimated_delivery_date
--    Propósito: Optimiza Q5 (late_deliveries) al crear un índice pequeño
--               que solo contiene entregas tardías. Permite Index Scan
--               en lugar de Seq Scan en order_2017/2018.
--    Técnica: B-tree parcial
--    Consultas beneficiadas: Q5
CREATE INDEX IF NOT EXISTS idx_order_late
    ON "order"(order_delivered_customer_date)
    WHERE order_delivered_customer_date > order_estimated_delivery_date;

-- 7. Parcial: idx_payment_type_partial sobre payment(payment_type)
--    Condición: WHERE payment_type IN ('boleto', 'voucher')
--    Propósito: Optimiza consultas que filtran por métodos de pago
--               específicos (Q6 y análisis de payment_type).
--               El índice parcial es más pequeño que un índice completo.
--    Técnica: B-tree parcial
--    Consultas beneficiadas: Q6
CREATE INDEX IF NOT EXISTS idx_payment_type_partial
    ON payment(payment_type)
    WHERE payment_type IN ('boleto', 'voucher');

-- 8. Compuesto: idx_order_status_ts sobre order(order_status, order_purchase_timestamp)
--    Propósito: Cubre el patrón más común de filtrado en las consultas:
--               WHERE order_status = 'delivered' AND order_purchase_timestamp BETWEEN ...
--               Beneficia a Q2, Q3, Q5, Q6, Q7, Q8, Q9, Q10
--    Nota: Ya existe como idx_order_status_ts en 01_ddl_ecommify.sql.
--          Mantenemos aquí la definición por completitud documental.
-- SELECT 1 FROM pg_indexes WHERE indexname = 'idx_order_status_ts';
-- CREATE INDEX IF NOT EXISTS idx_order_status_ts
--     ON "order"(order_status, order_purchase_timestamp);
