# Ecommify Database Design

Diseño de base de datos híbrida para un e-commerce, combinando PostgreSQL como motor transaccional (OLTP) normalizado en 3FN y MongoDB para datos analíticos y semiestructurados (OLAP). Incluye esquemas DDL, datos de seed y consultas de ejemplo para ambos motores.

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

## Estructura del proyecto

```
├── docs/                    # Documentación técnica (DD, extensiones PostgreSQL)
├── postgresql/
│   ├── schema/              # DDL del modelo transaccional (3FN, particionado)
│   ├── seed_data/           # Datos de prueba para PostgreSQL
│   └── queries/             # Consultas SQL analíticas
├── mongodb/
│   ├── schema/              # Schemas con validación JSON Schema
│   ├── seed_data/           # Datos de prueba para MongoDB
│   └── queries/             # Consultas (find, aggregate, findOne)
└── notebooks/               # Jupyter notebook de análisis exploratorio
```
