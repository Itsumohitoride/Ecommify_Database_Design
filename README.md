# Ecommify — Hybrid Polyglot Architecture

**Proyecto Académico | Maestría en Arquitectura de Software | Universidad de La Sabana**
Unidad 5 — Implementación Técnica Optimizada: PostgreSQL + MongoDB

Diseño de base de datos híbrida para un e-commerce, combinando PostgreSQL como motor transaccional (OLTP) normalizado en 3FN y MongoDB para datos analíticos y semiestructurados (OLAP). Incluye esquemas DDL, datos de seed y consultas de ejemplo para ambos motores.

---

## Descripción

Ecommify es una plataforma de e-commerce brasileño que implementa una **arquitectura híbrida poliglota** sobre el dataset Olist (Kaggle, ~1.45 M registros). El sistema combina:

- **PostgreSQL 17.6 (Supabase)** — Módulo transaccional (ACID, CAP-CP): órdenes, pagos, clientes, productos, sellers, reviews
- **MongoDB Atlas M10** — Módulo analítico y de catálogo (BASE, CAP-AP): catálogo de productos enriquecido, event logs, user sessions

---

## PostgreSQL — Módulo Transaccional

9 tablas normalizadas con particionamiento por rango de fechas, integridad referencial e índices estratégicos:

| Tabla | Descripción |
|---|---|
| `geolocation` | Códigos postales con coordenadas, ciudad y estado |
| `product_category` | Catálogo de categorías con traducción al inglés |
| `customer` | Clientes con vínculo a geolocalización |
| `seller` | Vendedores vinculados a código postal |
| `product` | Productos con dimensiones, peso y categoría |
| `order` | Órdenes particionadas por año (2016–2019+) con estado y timestamps |
| `order_item` | Ítems por orden (entidad débil, resuelve 2FN) |
| `payment` | Pagos por orden con tipo, cuotas y valor |
| `review` | Reseñas con puntuación (1–5) y comentarios |

## MongoDB — Módulo Analítico

3 colecciones con esquemas flexibles, validación JSON Schema e índices TTL para expiración automática:

| Colección | Descripción |
|---|---|
| `products` | Catálogo enriquecido con especificaciones variables por categoría, búsqueda full-text y campo `schema_version` para migraciones graduales |
| `user_sessions` | Sesiones activas con carrito de compras temporal. TTL de 24 horas con expiración automática |
| `event_logs` | Logs de eventos operacionales (vistas, clics, búsquedas, carritos abandonados). TTL de 90 días |

---

## Estructura del Repositorio

```
├── README.md
│
├── docs/
│   ├── U3_Diseno_Tecnico/
│   │   ├── Diccionario_Datos.md
│   │   ├── Documento_Tecnico_Diseno.pdf
│   │   ├── Extensiones_PostgreSQL_Ecommify.md
│   │   └── Presentacion_Ejecutiva.pdf
│   └── U5_Optimizacion/
│       ├── U5_Etapa2_Implementacion_Tecnica.pdf
│       └── evidencias/
│           ├── fig1_row_counts.png
│           ├── fig2_before_after_v2.png
│           ├── fig3_partitions.png
│           ├── fig4_index_inventory.png
│           └── fig5_all_queries.png
│
├── postgresql/
│   ├── schema/
│   │   ├── 01_ddl_ecommify.sql             ← DDL completo (9 tablas, ENUMs, tipos avanzados)
│   │   ├── 02_indexes_ecommify.sql         ← Índices B-tree, GIN, GiST, BRIN
│   │   └── 03_partition_optimization.sql   ← RANGE partitioning por timestamp
│   ├── queries/
│   │   ├── base/                           ← Consultas originales (sin optimizar)
│   │   │   ├── 01_order_detail.sql
│   │   │   ├── 02_sales_by_category.sql
│   │   │   ├── 03_seller_performance.sql
│   │   │   ├── 04_customer_order_history.sql
│   │   │   ├── 05_late_deliveries.sql
│   │   │   ├── 06_payment_method_analysis.sql
│   │   │   ├── 07_product_review_analysis.sql
│   │   │   ├── 08_monthly_sales_trend.sql
│   │   │   ├── 09_top_customers_by_spend.sql
│   │   │   └── 10_geographic_distribution.sql
│   │   └── optimized/                      ← Versiones optimizadas con EXPLAIN ANALYZE
│   │       ├── 01_order_detail_optimized.sql
│   │       ├── 03_seller_performance_optimized.sql
│   │       ├── 04_customer_order_history_optimized.sql
│   │       ├── 05_late_deliveries_optimized.sql
│   │       ├── 06_payment_method_analysis_optimized.sql
│   │       ├── 07_product_review_analysis_optimized.sql
│   │       ├── 08_monthly_sales_trend_optimized.sql
│   │       ├── 09_top_customers_optimized.sql
│   │       └── 10_geographic_distribution_optimized.sql
│   └── seed_data/
│       ├── 01_seed_ecommify.sql
│       └── 01_load_seed_data.sql
│
├── mongodb/
│   ├── schema/
│   │   ├── products_catalog_schema.json    ← JSON Schema + validación Atlas
│   │   ├── products_schema.json
│   │   ├── event_logs_schema.json
│   │   ├── user_sessions_schema.json
│   │   └── geolocation_schema.json
│   ├── queries/
│   │   ├── 01_create_indexes.js
│   │   ├── 02_esr_queries_optimized.js
│   │   ├── 03_text_search_optimized.js
│   │   ├── 04_partial_indexes_optimized.js
│   │   ├── 05_aggregation_pipeline_optimized.js
│   │   ├── 06_explain_comparisons.js
│   │   ├── aggregate/
│   │   │   └── aggregate_queries.json
│   │   ├── find/
│   │   │   └── find_queries.json
│   │   └── findOne/
│   │       └── findOne_queries.json
│   └── seed_data/
│       ├── 01_seed_ecommify.js
│       └── 02_load_from_csv.py
│
└── notebooks/
    ├── Data_Exploration_Analysis.ipynb     ← Análisis exploratorio del dataset Olist
    ├── U5_MongoDB_Optimizacion.ipynb       ← Colab: optimización MongoDB (Etapa 1)
    └── U5_PostgreSQL_Optimizacion.ipynb    ← Colab: optimización PostgreSQL (Etapa 2)
```

---

## Requisitos Previos

| Herramienta | Versión mínima | Propósito |
|---|---|---|
| Python | 3.9+ | Carga de datos y notebooks |
| Google Colab | — | Ejecución de notebooks |
| Cuenta Supabase | Free tier | PostgreSQL en la nube |
| Cuenta MongoDB Atlas | Free tier (M0) | MongoDB en la nube |
| psycopg2 | 2.9+ | Conexión PostgreSQL desde Python |
| pymongo | 4.0+ | Conexión MongoDB desde Python |
| pandas | 2.0+ | Procesamiento del dataset CSV |

---

## Setup — PostgreSQL (Supabase)

### 1. Crear proyecto en Supabase
1. Ir a [supabase.com](https://supabase.com) → New Project
2. Anotar: **Host**, **Database**, **User**, **Password**, **Port** (5432)
3. En el SQL Editor de Supabase, habilitar extensiones:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
```

### 2. Ejecutar DDL

En el SQL Editor de Supabase, ejecutar **en orden**:

```sql
-- Paso 1: Esquema base (tablas, constraints, ENUMs, tipos avanzados)
postgresql/schema/01_ddl_ecommify.sql

-- Paso 2: Índices especializados (B-tree, GIN, GiST)
postgresql/schema/02_indexes_ecommify.sql

-- Paso 3: Particionamiento RANGE por timestamp
postgresql/schema/03_partition_optimization.sql
```

### 3. Cargar el dataset Olist

1. Descargar el dataset desde [Kaggle — Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Descomprimir los 9 CSVs en una carpeta local
3. Abrir `notebooks/U5_PostgreSQL_Optimizacion.ipynb` en **Google Colab**
4. En la celda de configuración, ingresar las credenciales de Supabase:

```python
DB_CONFIG = {
    'host':     'tu-host.supabase.co',
    'database': 'postgres',
    'user':     'postgres',
    'password': 'tu-password',
    'port':     5432
}
```

5. Subir los 9 CSVs del dataset a Colab (o apuntar a la ruta local)
6. Ejecutar **Run All** — el notebook detecta automáticamente si los datos ya fueron cargados (`DATA_ALREADY_LOADED` guard) y salta la carga si la tabla `customer` ya tiene registros

> **Nota:** El notebook carga ~1.45 M registros usando `COPY FROM` (psycopg2), lo que toma aprox. 3–5 minutos en conexión estándar.

### 4. Ejecutar queries optimizadas

Las queries base están en `postgresql/queries/base/` y las versiones optimizadas en `postgresql/queries/optimized/`. Para reproducir los EXPLAIN ANALYZE del documento, ejecutar directamente en Colab via el notebook, o en Supabase SQL Editor.

---

## Setup — MongoDB Atlas

### 1. Crear cluster en MongoDB Atlas
1. Ir a [cloud.mongodb.com](https://cloud.mongodb.com) → New Cluster (M0 free tier)
2. Crear base de datos: `ecommify`
3. Anotar la **Connection String** (formato `mongodb+srv://...`)

### 2. Aplicar JSON Schema validation

Para cada colección, en MongoDB Compass o Atlas Shell, ejecutar el comando de validación del archivo correspondiente en `mongodb/schema/`. Ejemplo para `products_catalog`:

```javascript
db.runCommand({
  collMod: "products_catalog",
  validator: <contenido de products_catalog_schema.json>.schema_validation,
  validationLevel: "error"
})
```

### 3. Crear índices

Ejecutar en MongoDB Shell o Compass:

```javascript
// Cargar todos los índices ESR, parciales y de texto
load("mongodb/queries/01_create_indexes.js")
```

### 4. Cargar datos desde CSV

```bash
pip install pymongo pandas

python mongodb/seed_data/02_load_from_csv.py \
  --connection-string "mongodb+srv://user:pass@cluster.mongodb.net" \
  --csv-path /ruta/al/dataset/olist
```

### 5. Ejecutar aggregation pipeline optimizado

```javascript
load("mongodb/queries/05_aggregation_pipeline_optimized.js")
```

---

## Reproducir el Análisis de Rendimiento

| Notebook | Ruta | Contenido |
|---|---|---|
| MongoDB Optimización | `notebooks/U5_MongoDB_Optimizacion.ipynb` | Índices ESR, partial, text, aggregation pipeline |
| PostgreSQL Optimización | `notebooks/U5_PostgreSQL_Optimizacion.ipynb` | 11 queries BEFORE/AFTER con EXPLAIN ANALYZE |

Ambos notebooks son autocontenidos, ejecutables en **Google Colab** sin instalación local.

---

## Resultados Destacados

### PostgreSQL (11 queries optimizadas)
| Query | Mejora | Técnica |
|---|---|---|
| Q2 — Sales by Category | **−89.8%** (2.425 ms → 247 ms) | BRIN + Partition Pruning |
| Q1 — Monthly Revenue | −31.1% | BRIN + B-tree |
| Q6 — Payment Analysis | −25.5% | CTE pre-filter + work_mem |
| Q3 — Seller Performance | Regresión (free tier) | Documentado como limitación |

### MongoDB (índices ESR + pipeline)
| Métrica | Antes | Después |
|---|---|---|
| Index Hit Ratio | 45% | **97%** |
| Docs examinados/query | ~33.000 | **~50** (−99.8%) |
| Aggregation pipeline (executionTimeMillis) | 32 ms | **3.6 ms** (−88.8%) |

---

## Limitaciones Conocidas (Free Tier)

- **PostGIS** no disponible en Supabase free tier → coordenadas como `NUMERIC(9,6)`, tipo `POINT` construido en consulta
- **pg_cron** no disponible → particionamiento futuro vía función PL/pgSQL manual
- **MongoDB M0** sin Performance Advisor ni `$indexStats` completos → métricas via `explain('executionStats')`
- **Regresión Q3**: planner de PostgreSQL eligió plan subóptimo tras creación de índice en free tier (documentado en sección 3.1.3 del documento técnico)

---

## Dataset

- **Fuente**: [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)
- **Registros totales**: ~1.45 M (9 tablas CSV)
- **Tabla mayor**: `geolocation` (1.000.163 filas)

---

## Autores

Equipo de Base de Datos — Ecommify
Maestría en Arquitectura de Software, Universidad de La Sabana
Junio 2026
