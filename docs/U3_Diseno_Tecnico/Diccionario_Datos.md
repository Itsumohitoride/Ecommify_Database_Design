# Diccionario de Datos — Ecommify

## CUSTOMER

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| customer_id | CHAR(32) | PK | Identificador de sesión de compra (hash MD5) |
| customer_unique_id | CHAR(32) | UNIQUE NOT NULL | Identidad real del comprador |
| zip_code_prefix | CHAR(5) | FK → GEOLOCATION | Prefijo postal de 5 dígitos |
| customer_city | VARCHAR(60) | — | Ciudad del cliente |
| customer_state | CHAR(2) | — | Unidad Federativa (SP, MG, RJ...) |

## ORDER

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| order_id | CHAR(32) | PK | Identificador único del pedido |
| customer_id | CHAR(32) | FK → CUSTOMER NOT NULL | Asocia el pedido con la cuenta de compra |
| order_status | order_status_enum | NOT NULL, CHECK (8 valores) | Estado del ciclo de vida |
| order_purchase_timestamp | TIMESTAMPTZ | NOT NULL | Momento de la compra |
| order_approved_at | TIMESTAMPTZ | NULLABLE | Aprobación del pago |
| order_delivered_carrier_date | TIMESTAMPTZ | NULLABLE | Entrega al transportista |
| order_delivered_customer_date | TIMESTAMPTZ | NULLABLE | Entrega efectiva al cliente |
| order_estimated_delivery_date | TIMESTAMPTZ | NOT NULL | Fecha de entrega prometida |

## ORDER_ITEM

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| order_id | CHAR(32) | PK (parte 1), FK → ORDER | Referencia a la orden |
| order_item_id | SMALLINT | PK (parte 2) | Número de secuencia del ítem |
| product_id | CHAR(32) | FK → PRODUCT NOT NULL | Producto incluido |
| seller_id | CHAR(32) | FK → SELLER NOT NULL | Vendedor que despacha |
| shipping_limit_date | TIMESTAMPTZ | NOT NULL | Límite de envío |
| price | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Precio en BRL |
| freight_value | NUMERIC(10,2) | NOT NULL, CHECK >= 0 | Flete en BRL |

## PAYMENT

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| order_id | CHAR(32) | PK (parte 1), FK → ORDER | Orden asociada |
| payment_sequential | SMALLINT | PK (parte 2) | Número de secuencia del pago |
| payment_type | payment_type_enum | NOT NULL, CHECK (5 valores) | Método de pago |
| payment_installments | SMALLINT | NOT NULL, CHECK >= 1 | Número de cuotas |
| payment_value | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Monto en BRL |

## REVIEW

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| review_id | CHAR(32) | PK | Identificador único de la reseña |
| order_id | CHAR(32) | FK → ORDER NOT NULL | Orden evaluada |
| review_score | SMALLINT | NOT NULL, CHECK 1-5 | Puntuación Likert |
| review_comment_title | VARCHAR(50) | NULLABLE | Título del comentario |
| review_comment_message | VARCHAR(300) | NULLABLE | Cuerpo del comentario |
| review_creation_date | TIMESTAMPTZ | NOT NULL | Fecha de solicitud de reseña |
| review_answer_timestamp | TIMESTAMPTZ | NULLABLE | Fecha de respuesta del cliente |

## PRODUCT

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| product_id | CHAR(32) | PK | Identificador único del producto |
| category_name | VARCHAR(100) | FK → PRODUCT_CATEGORY | Categoría en portugués |
| product_name_lenght | SMALLINT | CHECK >= 0 | Longitud del nombre |
| product_description_lenght | SMALLINT | CHECK >= 0 | Longitud de la descripción |
| product_photos_qty | SMALLINT | CHECK >= 0 | Cantidad de fotos |
| product_weight_g | NUMERIC(8,2) | CHECK > 0 | Peso en gramos |
| product_length_cm | NUMERIC(6,2) | CHECK > 0 | Longitud en cm |
| product_height_cm | NUMERIC(6,2) | CHECK > 0 | Alto en cm |
| product_width_cm | NUMERIC(6,2) | CHECK > 0 | Ancho en cm |

## PRODUCT_CATEGORY

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| category_name | VARCHAR(100) | PK (clave natural) | Nombre en portugués brasileño |
| name_english | VARCHAR(100) | NOT NULL | Traducción al inglés |

## SELLER

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| seller_id | CHAR(32) | PK | Identificador único del vendedor |
| zip_code_prefix | CHAR(5) | FK → GEOLOCATION | Código postal |
| seller_city | VARCHAR(60) | NOT NULL | Ciudad del vendedor |
| seller_state | CHAR(2) | NOT NULL | Estado (UF) |

## GEOLOCATION

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| zip_code_prefix | CHAR(5) | PK (tras agregación) | Prefijo postal único |
| latitude | NUMERIC(9,6) | NOT NULL | Latitud representativa |
| longitude | NUMERIC(9,6) | NOT NULL | Longitud representativa |
| city | VARCHAR(60) | NOT NULL | Ciudad asociada |
| state | CHAR(2) | NOT NULL | Estado (UF) |
