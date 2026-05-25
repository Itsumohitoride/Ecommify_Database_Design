// ============================================================
// Ecommify — MongoDB Seed Data
// Datos de ejemplo con variabilidad realista por categoría
// ============================================================
// Ejecutar después de 01_schemas_ecommify.js:
//   mongosh < 01_schemas_ecommify.js
//   mongosh < 01_seed_ecommify.js
// ============================================================

use('ecommify');

print('=== Insertando datos de ejemplo - Ecommify ===');

// ============================================================
// Products — Catálogo enriquecido
// Cada producto tiene specifications distintas según categoría
// ============================================================

db.products.insertMany([
  {
    product_id: 'ffe9c82b9f56afcf0dfe57d81de5f5a5',
    category_name: 'informatica_acessorios',
    category_name_english: 'computers_accessories',
    name: '[Anonimizado] Mouse Inalambrico',
    description: 'Mouse optico inalambrico con conectividad Bluetooth 5.0 y USB-A. Compatible con Windows, macOS y Linux. Bateria recargable con duracion de 30 dias.',
    photo_urls: [
      'https://cdn.ecommify.com/products/mouse1.jpg',
      'https://cdn.ecommify.com/products/mouse2.jpg',
      'https://cdn.ecommify.com/products/mouse3.jpg'
    ],
    specifications: {
      weight_g: 85,
      dimensions_cm: { length: 11.5, height: 3.8, width: 6.2 },
      connectivity: ['USB-A', 'Bluetooth 5.0'],
      compatibility: ['Windows', 'macOS', 'Linux'],
      warranty_months: 12,
      battery_type: 'Li-ion 500mAh',
      color: 'Preto'
    },
    tags: ['periferico', 'mouse', 'inalambrico', 'bluetooth'],
    avg_review_score: 4.3,
    total_reviews: NumberInt(128),
    schema_version: NumberInt(2),
    created_at: ISODate('2024-01-15T10:00:00Z'),
    updated_at: ISODate('2024-06-20T14:30:00Z')
  },
  {
    product_id: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
    category_name: 'cama_mesa_banho',
    category_name_english: 'bed_bath_table',
    name: '[Anonimizado] Toalha Luxo Algodao 70x130cm',
    description: 'Toalha de banho em algodao 100% egipcio. Gramatura 600g/m². Maciez e absorcao superiores. Disponivel em diversas cores.',
    photo_urls: [
      'https://cdn.ecommify.com/products/toalha1.jpg'
    ],
    specifications: {
      weight_g: 450,
      dimensions_cm: { length: 130, height: 0.5, width: 70 },
      material: 'Algodao 100% egipcio',
      gramature: '600g/m²',
      color: 'Branco',
      care_instructions: ['Lavar a 30°C', 'Nao usar alvejante', 'Secar a sombra']
    },
    tags: ['toalha', 'banho', 'algodao', 'luxo'],
    avg_review_score: 4.7,
    total_reviews: NumberInt(89),
    schema_version: NumberInt(1),
    created_at: ISODate('2024-02-10T08:00:00Z'),
    updated_at: ISODate('2024-05-15T12:00:00Z')
  },
  {
    product_id: 'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
    category_name: 'eletronicos',
    category_name_english: 'electronics',
    name: '[Anonimizado] Fone Bluetooth Cancelamento Ruido',
    description: 'Fone de ouvido over-ear com cancelamento ativo de ruido (ANC). Driver de 40mm. Autonomia de 40 horas. Carregamento USB-C rapido.',
    photo_urls: [
      'https://cdn.ecommify.com/products/fone1.jpg',
      'https://cdn.ecommify.com/products/fone2.jpg'
    ],
    specifications: {
      weight_g: 250,
      dimensions_cm: { length: 18.5, height: 8.0, width: 16.0 },
      connectivity: ['Bluetooth 5.2', 'USB-C', 'P2 3.5mm'],
      battery_hours: 40,
      charging_time_min: 120,
      driver_size_mm: 40,
      frequency_response: '20Hz - 20kHz',
      impedance_ohm: 32,
      anc_type: 'Feedforward + Feedback',
      warranty_months: 24,
      water_resistance: 'IPX4'
    },
    tags: ['fone', 'bluetooth', 'anc', 'musica', 'cancelamento ruido'],
    avg_review_score: 4.5,
    total_reviews: NumberInt(256),
    schema_version: NumberInt(2),
    created_at: ISODate('2024-03-01T09:00:00Z'),
    updated_at: ISODate('2024-07-01T16:00:00Z')
  },
  {
    product_id: 'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8',
    category_name: 'utilidades_domesticas',
    category_name_english: 'household_utilities',
    name: '[Anonimizado] Conjunto Tuppers 10 Pecas',
    description: 'Conjunto de 10 recipientes hermeticos para armazenamento de alimentos. Material plastico livre de BPA. Empilhaveis. Apto para micro-ondas e freezer.',
    photo_urls: [
      'https://cdn.ecommify.com/products/tupper1.jpg',
      'https://cdn.ecommify.com/products/tupper2.jpg',
      'https://cdn.ecommify.com/products/tupper3.jpg',
      'https://cdn.ecommify.com/products/tupper4.jpg'
    ],
    specifications: {
      weight_g: 650,
      dimensions_cm: { length: 32, height: 18, width: 24 },
      material: 'Polipropileno (BPA-free)',
      pieces: NumberInt(10),
      capacities_ml: [150, 250, 500, 750, 1000, 1500],
      microwave_safe: true,
      freezer_safe: true,
      dishwasher_safe: true,
      color: 'Transparente + Tampa Verde'
    },
    tags: ['tuppers', 'cozinha', 'armazenamento', 'hermetico'],
    avg_review_score: 4.1,
    total_reviews: NumberInt(67),
    schema_version: NumberInt(1),
    created_at: ISODate('2024-01-20T11:00:00Z'),
    updated_at: ISODate('2024-04-10T09:00:00Z')
  },
  {
    product_id: 'a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4',
    category_name: 'esporte_lazer',
    category_name_english: 'sports_leisure',
    name: '[Anonimizado] Camisa Academia Dry Fit M',
    description: 'Camisa manga curta dry fit para atividades esportivas. Tecnologia de secagem rapida. Costuras planas para evitar assaduras. Protecao UV50+.',
    photo_urls: [
      'https://cdn.ecommify.com/products/camisa1.jpg'
    ],
    specifications: {
      weight_g: 120,
      dimensions_cm: { length: 28, height: 1.0, width: 20 },
      size: 'M',
      gender: 'Unissex',
      material: 'Poliester 92%, Elastano 8%',
      technology: ['Dry Fit', 'UV50+', 'Anti-odor'],
      color: 'Azul Marinho',
      care_instructions: ['Lavar a 30°C', 'Nao usar amaciante', 'Nao secar em secadora']
    },
    tags: ['camisa', 'academia', 'dry fit', 'esporte'],
    avg_review_score: 3.9,
    total_reviews: NumberInt(42),
    schema_version: NumberInt(2),
    created_at: ISODate('2024-04-05T07:00:00Z'),
    updated_at: ISODate('2024-06-25T10:00:00Z')
  }
]);

print(`  [OK] ${db.products.countDocuments()} products insertados`);

// ============================================================
// Event Logs — Eventos operacionales de ejemplo
// ============================================================

db.event_logs.insertMany([
  {
    event_type: 'product_view',
    customer_unique_id: 'd6d5a20df8c820cbce39fd49b34bd9ac',
    session_id: 'sess_abc123',
    product_id: 'ffe9c82b9f56afcf0dfe57d81de5f5a5',
    category: 'informatica_acessorios',
    metadata: {
      source: 'search_results',
      position: 3,
      search_query: 'mouse inalambrico'
    },
    timestamp: ISODate('2024-06-20T14:32:10Z'),
    ttl_expire: ISODate('2024-09-20T14:32:10Z')
  },
  {
    event_type: 'product_view',
    customer_unique_id: 'd6d5a20df8c820cbce39fd49b34bd9ac',
    session_id: 'sess_abc123',
    product_id: 'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
    category: 'eletronicos',
    metadata: {
      source: 'search_results',
      position: 1,
      search_query: 'fone bluetooth'
    },
    timestamp: ISODate('2024-06-20T14:33:05Z'),
    ttl_expire: ISODate('2024-09-20T14:33:05Z')
  },
  {
    event_type: 'cart_add',
    customer_unique_id: 'd6d5a20df8c820cbce39fd49b34bd9ac',
    session_id: 'sess_abc123',
    product_id: 'ffe9c82b9f56afcf0dfe57d81de5f5a5',
    seller_id: 'cca3071a3a8b5b6a7c8d9e0f1a2b3c4d5',
    category: 'informatica_acessorios',
    metadata: {
      quantity: 1,
      unit_price: 89.90
    },
    timestamp: ISODate('2024-06-20T14:35:00Z'),
    ttl_expire: ISODate('2024-09-20T14:35:00Z')
  },
  {
    event_type: 'search',
    customer_unique_id: 'e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0',
    session_id: 'sess_def456',
    metadata: {
      search_query: 'toalha algodao',
      results_count: 23,
      filters: { category: 'cama_mesa_banho', min_price: 20, max_price: 100 }
    },
    timestamp: ISODate('2024-06-20T15:00:00Z'),
    ttl_expire: ISODate('2024-09-20T15:00:00Z')
  },
  {
    event_type: 'product_view',
    customer_unique_id: 'e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0',
    session_id: 'sess_def456',
    product_id: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
    category: 'cama_mesa_banho',
    metadata: { source: 'search_results', position: 2, search_query: 'toalha algodao' },
    timestamp: ISODate('2024-06-20T15:01:30Z'),
    ttl_expire: ISODate('2024-09-20T15:01:30Z')
  },
  {
    event_type: 'cart_abandon',
    customer_unique_id: 'f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1',
    session_id: 'sess_ghi789',
    metadata: {
      cart_value: 245.80,
      items_count: 3,
      time_spent_min: 12
    },
    timestamp: ISODate('2024-06-19T22:15:00Z'),
    ttl_expire: ISODate('2024-09-19T22:15:00Z')
  },
  {
    event_type: 'checkout_start',
    customer_unique_id: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
    session_id: 'sess_jkl012',
    metadata: {
      cart_value: 178.50,
      items_count: 2,
      payment_method: 'credit_card'
    },
    timestamp: ISODate('2024-06-20T16:00:00Z'),
    ttl_expire: ISODate('2024-09-20T16:00:00Z')
  }
]);

print(`  [OK] ${db.event_logs.countDocuments()} event_logs insertados`);

// ============================================================
// User Sessions — Sesiones activas con carritos
// ============================================================

db.user_sessions.insertMany([
  {
    _id: 'sess_abc123',
    customer_unique_id: 'd6d5a20df8c820cbce39fd49b34bd9ac',
    cart: [
      {
        product_id: 'ffe9c82b9f56afcf0dfe57d81de5f5a5',
        quantity: NumberInt(1),
        unit_price: 89.90,
        seller_id: 'cca3071a3a8b5b6a7c8d9e0f1a2b3c4d5'
      },
      {
        product_id: 'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
        quantity: NumberInt(1),
        unit_price: 199.90,
        seller_id: 'd4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9'
      }
    ],
    created_at: ISODate('2024-06-20T14:30:00Z'),
    expires_at: ISODate('2024-06-21T14:30:00Z')
  },
  {
    _id: 'sess_def456',
    customer_unique_id: 'e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0',
    cart: [
      {
        product_id: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        quantity: NumberInt(2),
        unit_price: 49.90,
        seller_id: 'b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5'
      }
    ],
    created_at: ISODate('2024-06-20T15:00:00Z'),
    expires_at: ISODate('2024-06-21T15:00:00Z')
  },
  {
    _id: 'sess_ghi789',
    customer_unique_id: 'f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1',
    cart: [],
    created_at: ISODate('2024-06-19T22:00:00Z'),
    expires_at: ISODate('2024-06-20T22:00:00Z')
  }
]);

print(`  [OK] ${db.user_sessions.countDocuments()} user_sessions insertados`);
print('');
print('=== Seed data insertado exitosamente ===');
