# Extensiones_PostgreSQL_Ecommify.md
## Análisis de extensiones de PostgreSQL para el proyecto Ecommify

---

## 1. Estudio de extensiones relevantes

### PostGIS

PostGIS es una extensión geoespacial que agrega soporte para objetos geométricos y consultas especiales a PostgreSQL. Permite trabajar con coordenadas, mapas, rutas, distancias y análisis GIS directamente en el motor de base de datos, sin depender de servicios externos. Es ampliamente usada en sistemas de logística, agricultura de precisión, IoT y mapas interactivos.

GIS (Geographic Information System) es un conjunto de tecnologías para almacenar, analizar y visualizar datos relacionados con ubicaciones geográficas. PostGIS convierte PostgreSQL en una base de datos GIS completa.

```sql
CREATE EXTENSION postgis;

-- Buscar puntos cercanos a una ubicación
SELECT * FROM farms
WHERE ST_DWithin(
    location,
    ST_MakePoint(-75.56, 6.24)::geography,
    5000
);

-- Calcular distancia entre dos puntos GPS
SELECT ST_Distance(
    ST_MakePoint(-75.56, 6.24)::geography,
    ST_MakePoint(-74.08, 4.61)::geography
);
```

### pg_trgm

Extensión para búsquedas difusas basada en trigramas. Mejora búsquedas tolerantes a errores tipográficos y similitud textual, útil en motores de búsqueda, autocompletado y matching de nombres.

Un trigrama es una secuencia de 3 caracteres consecutivos usada para comparar similitud entre textos. `pg_trgm` divide palabras en grupos de 3 letras y mide cuántos coinciden entre dos cadenas (`"postgres"` → `"pos"`, `"ost"`, `"stg"`, `"tgr"`, etc.). Una búsqueda tolerante a errores puede encontrar resultados aunque el usuario escriba mal una palabra, omita letras o tenga diferencias menores — también conocida como *fuzzy search* (buscar `Jhon` y el sistema retorna `John`).

```sql
CREATE EXTENSION pg_trgm;

-- Encontrar nombres similares
SELECT name FROM users
WHERE similarity(name, 'Jhon') > 0.4;
```

### pgcrypto

Extensión criptográfica para cifrado, hashing y generación segura de identificadores. Es útil para seguridad, manejo de contraseñas y protección de datos sensibles directamente desde el motor de base de datos.

```sql
CREATE EXTENSION pgcrypto;

-- Almacenar contraseñas cifradas
INSERT INTO users(password)
VALUES (crypt('myPassword', gen_salt('bf')));
```

### hstore

Extensión de PostgreSQL para almacenar pares clave-valor simples. Es más ligero que JSONB cuando solo se necesitan atributos planos sin estructuras anidadas.

```sql
CREATE EXTENSION hstore;

CREATE TABLE products (id SERIAL, attributes hstore);

INSERT INTO products (attributes)
VALUES ('color => blue, size => M');
```

---

## 2. Análisis de aplicabilidad en Ecommify

### PostGIS — Optimización de costos de envío

La extensión PostGIS tiene relevancia directa en Ecommify debido a la presencia de más de un millón de registros geográficos en el dataset, así como a la distribución de clientes y vendedores en diferentes estados de Brasil. El principal caso de uso corresponde a la optimización de costos y tiempos de envío mediante el cálculo de distancias entre vendedores y clientes. De esta manera, el sistema podría identificar vendedores cercanos y estimar rutas logísticas de forma más eficiente.

```sql
-- Distancia real entre vendedor en SP y cliente en RJ
SELECT ST_Distance(
    ST_SetSRID(ST_MakePoint(-47.063, -22.898), 4326)::geography,
    ST_SetSRID(ST_MakePoint(-43.176, -22.910), 4326)::geography
) / 1000 AS distance_km;
-- Resultado con coordenadas reales del dataset: ≈ 357 km

-- Vendedores alternativos dentro de 50 km del cliente
SELECT s.seller_id, s.seller_city,
       ROUND(ST_Distance(sg.geom, cg.geom) / 1000, 1) AS dist_km
FROM seller s
JOIN geolocation sg ON s.zip_code_prefix = sg.zip_code_prefix
JOIN geolocation cg ON cg.zip_code_prefix = '01310'
WHERE ST_DWithin(sg.geom, cg.geom, 50000)
ORDER BY dist_km;
```

**Decisión: ✅ Adoptar.** El dataset ya tiene 19,015 coordenadas únicas de código postal. PostGIS permite pasar de un flete fijo por región a un modelo basado en distancia real.

---

### pg_trgm — Búsqueda de productos tolerante a errores

pg_trgm sirve como solución para mejorar las búsquedas de productos dentro de Ecommify mediante consultas tolerantes a errores tipográficos. En plataformas e-commerce esta funcionalidad resulta especialmente útil debido a la gran variedad de productos y términos de búsqueda utilizados por los usuarios. Su implementación permite mejorar significativamente la experiencia de navegación y recuperación de información dentro del catálogo de productos.

```sql
CREATE EXTENSION pg_trgm;

CREATE INDEX idx_category_trgm ON product_category
    USING GIN (name_english gin_trgm_ops);

-- 'helth beauty' → 'health_beauty': similitud ~0.67
SELECT name_english, SIMILARITY(name_english, 'helth beauty') AS sim
FROM product_category
WHERE name_english % 'helth beauty'
ORDER BY sim DESC LIMIT 5;
```

**Decisión: ✅ Adoptar.** Evita depender de un servicio externo como Elasticsearch para el caso base de búsqueda con tolerancia a errores.

---

### hstore — Atributos variables de productos

hstore permite almacenar pares clave-valor dentro de una sola columna en PostgreSQL. En el contexto de Ecommify podría utilizarse para almacenar características variables de productos como especificaciones técnicas, colores, tamaños o atributos particulares que no están presentes en todos los artículos del catálogo. Esto resulta especialmente útil considerando que el dataset presenta información opcional y atributos con valores nulos en productos como dimensiones, pesos y descripciones.

Sin embargo, aunque hstore aporta flexibilidad, su uso ha sido parcialmente reemplazado en muchos escenarios modernos por JSONB, el cual ofrece mayor capacidad estructural y mejores funcionalidades de consulta. En Ecommify, JSONB ya cubre el caso de `product.specifications`, por lo que hstore queda limitado a configuraciones simples del vendedor.

```sql
CREATE EXTENSION hstore;

ALTER TABLE seller ADD COLUMN config hstore DEFAULT ''::hstore;

UPDATE seller SET config =
    'shipping_days => 3, accepts_returns => true, min_order_brl => 50'::hstore
WHERE seller_id = 'abc123';
```

**Decisión: ⚠️ Adoptar con alcance limitado** — solo para configuraciones simples de vendedor donde JSONB sería sobredimensionado.

---

### pgcrypto — Protección de datos sensibles

pgcrypto proporciona funciones criptográficas de cifrado, hashing y generación segura de identificadores. En Ecommify podría utilizarse para el cifrado de datos relacionados con pagos, generar hashes seguros para contraseñas de usuarios o anonimizar información confidencial. Su incorporación resulta relevante dado que el dataset contiene información relacionada con transacciones y pagos, donde la seguridad de los datos representa un aspecto crítico. Además, pgcrypto permite implementar buenas prácticas de seguridad directamente desde PostgreSQL, cumpliendo con la LGPD (Lei Geral de Proteção de Dados, equivalente brasileño del GDPR).

```sql
CREATE EXTENSION pgcrypto;

ALTER TABLE customer
    ADD COLUMN email_encrypted BYTEA,
    ADD COLUMN phone_encrypted BYTEA;

-- Encriptar al insertar
INSERT INTO customer (customer_id, email_encrypted) VALUES (
    gen_random_uuid()::text,
    pgp_sym_encrypt('cliente@email.com',
        current_setting('app.encryption_key'))
);

-- Desencriptar solo al mostrar al usuario
SELECT pgp_sym_decrypt(email_encrypted,
    current_setting('app.encryption_key')) AS email
FROM customer WHERE customer_id = 'abc123';
```

**Decisión: ✅ Adoptar** para campos PII (email, teléfono, CPF/CNPJ). Requerimiento legal bajo LGPD.

---

## 3. Tabla de decisión final

| Extensión | Decisión | Caso de uso en Ecommify | Prioridad |
|---|---|---|---|
| **PostGIS** | ✅ Adoptar | Cálculo de distancia vendedor–cliente para optimizar costos de flete | Alta |
| **pg_trgm** | ✅ Adoptar | Búsqueda fuzzy de productos tolerante a errores tipográficos | Alta |
| **pgcrypto** | ✅ Adoptar | Cifrado de PII (email, teléfono, CPF/CNPJ). Cumplimiento LGPD | Alta |
| **hstore** | ⚠️ Limitado | Configuración simple de vendedores. JSONB cubre los casos más complejos | Media |
| **uuid-ossp** | ✅ Adoptar | Generación de UUIDs v4 para entidades nuevas (IDs del dataset son MD5) | Media |
| **pg_stat_statements** | ✅ Adoptar | Monitoreo de queries lentas en producción | Alta |

---

## Referencias

- PostgreSQL Global Development Group. (2025). *Server programming: Extending SQL*. PostgreSQL 16 Documentation. https://www.postgresql.org/docs/16/extend.html
- PostGIS Development Group. (2025). *PostGIS documentation*. https://postgis.net/documentation/
- Olist. (2018). *Brazilian E-Commerce Public Dataset by Olist*. Kaggle. https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
