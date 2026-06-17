-- =============================================
-- Partition Optimization — Ecommify order table
-- Etapa 2.3: Implementacion de particionamiento
-- =============================================
-- Basado en recomendaciones de Etapa 1.3 (Feature 4)
--
-- Problema identificado:
--   order_future cubre FROM ('2019-01-01') TO (MAXVALUE)
--   Sin limite superior → desbalance a largo plazo
--
-- Solucion:
--   1. DETACH order_future → tabla independiente (datos historicos)
--   2. Crear particiones anuales especificas 2019-2026
--   3. Funcion PL/pgSQL para auto-creacion anual
--   4. Schema archive + funcion de archivado
--   5. Politica de retencion documentada
-- =============================================

BEGIN;

-- =============================================
-- 1. Separar order_future del esquema de particion
-- =============================================
-- NOTA: order_future contiene datos existentes desde 2019.
-- Al DETACH, la tabla conserva sus datos como tabla independiente.
-- Las nuevas particiones anuales recibiran datos nuevos (2019+).
-- Para migrar datos historicos: INSERT INTO ... SELECT FROM order_future_old
-- y luego DROP TABLE order_future_old.
-- =============================================

ALTER TABLE IF EXISTS "order" DETACH PARTITION order_future;

-- Renombrar para indicar que es datos historicos
ALTER TABLE IF EXISTS order_future RENAME TO order_future_old;

-- =============================================
-- 2. Crear particiones anuales especificas
-- =============================================
-- Cubren 2019-2026 (8 anos)
-- Cada particion creada con IF NOT EXISTS por idempotencia

CREATE TABLE IF NOT EXISTS order_2019 PARTITION OF "order"
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');

CREATE TABLE IF NOT EXISTS order_2020 PARTITION OF "order"
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');

CREATE TABLE IF NOT EXISTS order_2021 PARTITION OF "order"
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');

CREATE TABLE IF NOT EXISTS order_2022 PARTITION OF "order"
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

CREATE TABLE IF NOT EXISTS order_2023 PARTITION OF "order"
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS order_2024 PARTITION OF "order"
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS order_2025 PARTITION OF "order"
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS order_2026 PARTITION OF "order"
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Actualizar estadisticas para el optimizador
ANALYZE "order";

-- =============================================
-- 3. Auto-creation de particiones futuras
-- =============================================
-- Funcion PL/pgSQL para crear particion del proximo ano.
-- Ejecutar anualmente via pg_cron o scheduler externo.
--
-- Uso: SELECT create_next_order_partition();
-- =============================================

CREATE OR REPLACE FUNCTION create_next_order_partition()
RETURNS text AS $$
DECLARE
    next_year       text;
    next_start      date;
    next_end        date;
    partition_name  text;
BEGIN
    next_year      := to_char(CURRENT_DATE + interval '1 year', 'YYYY');
    next_start     := date(next_year || '-01-01');
    next_end       := date(next_year || '-01-01') + interval '1 year';
    partition_name := 'order_' || next_year;

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF "order"
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, next_start, next_end
    );

    RETURN format(
        'Partition %s created for range %s to %s',
        partition_name, next_start, next_end
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. Schema archive y funcion de archivado
-- =============================================
-- Las particiones con datos antiguos (>5 anos) deben archivarse
-- para mejorar rendimiento de la tabla principal.
--
-- Proceso:
--   1. DETACH particion de la tabla principal
--   2. Mover al schema archive
--   3. Opcional: comprimir con pg_compress o tablespace lento
--
-- Uso: SELECT archive_order_partition('order_2016');
-- =============================================

CREATE SCHEMA IF NOT EXISTS archive;

CREATE OR REPLACE FUNCTION archive_order_partition(p_partition_name text)
RETURNS text AS $$
DECLARE
    archive_name text;
BEGIN
    -- Verificar que la particion existe
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = p_partition_name
    ) THEN
        RETURN format('Partition %s does not exist', p_partition_name);
    END IF;

    -- DETACH de la tabla principal
    EXECUTE format(
        'ALTER TABLE "order" DETACH PARTITION %I',
        p_partition_name
    );

    -- Mover al schema archive
    EXECUTE format(
        'ALTER TABLE %I SET SCHEMA archive',
        p_partition_name
    );

    -- Renombrar con prefijo arch_
    archive_name := 'arch_' || p_partition_name;
    EXECUTE format(
        'ALTER TABLE archive.%I RENAME TO %I',
        p_partition_name, archive_name
    );

    RETURN format(
        'Partition %s archived as archive.%s',
        p_partition_name, archive_name
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 5. Politica de retencion
-- =============================================
-- Horizonte de datos en la tabla order particionada:
--
-- | Periodo       | Accion                            | Detalle                          |
-- |---------------|-----------------------------------|----------------------------------|
-- | 0-5 anos      | Activo (particion principal)      | Datos en tabla order_AAAA        |
-- | 5-10 anos     | Archivado (schema archive)        | DETACH + mover a schema archive  |
-- | >10 anos      | Eliminacion segura                | DROP TABLE si hay backup         |
--
-- Ejecucion recomendada (anual):
--   1. SELECT create_next_order_partition();         -- crear prox ano
--   2. SELECT archive_order_partition('order_2016'); -- archivar >5 anos
--   3. SELECT archive_order_partition('order_2017'); -- archivar >5 anos
--
-- NOTA: Ajustar segun politica de retencion de datos de la empresa.
-- =============================================

-- =============================================
-- 6. Migracion de datos historicos (opcional)
-- =============================================
-- Si se desea migrar los datos de order_future_old a las particiones
-- correctas, ejecutar:
--
-- INSERT INTO "order"
-- SELECT * FROM order_future_old
-- WHERE order_purchase_timestamp >= '2019-01-01'
--   AND order_purchase_timestamp <  '2020-01-01';
--
-- INSERT INTO "order"
-- SELECT * FROM order_future_old
-- WHERE order_purchase_timestamp >= '2020-01-01'
--   AND order_purchase_timestamp <  '2021-01-01';
-- ... (repetir para cada ano)
--
-- Luego: DROP TABLE IF EXISTS order_future_old;
-- =============================================

COMMIT;

-- =============================================
-- VERIFICACION POST-EJECUCION
-- =============================================
-- Ejecutar para listar particiones:
--
-- SELECT
--     parent.relname AS parent_table,
--     child.relname AS partition_name,
--     pg_get_expr(child.relpartbound, child.oid) AS partition_range,
--     pg_size_pretty(pg_total_relation_size(child.oid)) AS size
-- FROM pg_inherits
-- JOIN pg_class parent ON parent.oid = inhparent
-- JOIN pg_class child  ON child.oid  = inhrelid
-- WHERE parent.relname = 'order'
-- ORDER BY child.relname;
-- =============================================
