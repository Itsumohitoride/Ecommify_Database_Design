// ============================================================================
// File: 01_create_indexes.js
// Purpose: Create all optimized indexes for products_catalog collection
// Collection: products_catalog
// Context: Olist Brazilian E-commerce public dataset
//
// Index summary:
//   1. idx_esr_category_weight_height — ESR for category + weight + height
//   2. idx_text_category_english      — Text index on category_name_english
//   3. idx_partial_weight_over_20     — Partial index: product_weight_g >= 20
// ============================================================================

// Switch to target database
use('ecommify');

// --------------------------------------------------------------------------
// Index 1: ESR — Equality + implicit Sort + Range
//   Fields: product_category_name (E), product_weight_g (S implicit), product_id (R)
//   ESR rule: Equality first, then Sort, then Range
//   Equality: product_category_name — exact match on category
//     Sort: product_weight_g — MongoDB can sort without separate SORT stage
//     Range: product_height_cm — range scan after sort boundary
//   Query: db.products_catalog.find({
//            product_category_name: "utilidades_domesticas",
//            product_height_cm: { $gte: 10, $lte: 30 }
//          }).sort({ product_weight_g: 1 })
// --------------------------------------------------------------------------
db.products_catalog.createIndex(
  {
    product_category_name: 1,
    product_weight_g: 1,
    product_height_cm: 1
  },
  {
    name: "idx_esr_category_weight_height",
    background: true,
    comment: "ESR: E=product_category_name (equality), S=product_weight_g (sort), R=product_height_cm (range). Optimizes category + weight sort + height range queries."
  }
);

// --------------------------------------------------------------------------
// Index 2: Text index on category_name_english
//   Fields: category_name_english (text)
//   Options: default_language: "none" — treats every word as a separate token
//            without stemming, important for English category names
//            (e.g. "auto", "health_beauty", "electronics")
//   Query: db.products_catalog.find(
//            { $text: { $search: "auto" } },
//            { score: { $meta: "textScore" } }
//          ).sort({ score: { $meta: "textScore" } })
//
//   BENEFIT: Replaces regex COLLSCAN with indexed IXSCAN.
// --------------------------------------------------------------------------
db.products_catalog.createIndex(
  {
    category_name_english: "text"
  },
  {
    name: "idx_text_category_english",
    default_language: "none",
    background: true,
    comment: "Text index on category_name_english with no stemming. Enables $text search instead of $regex COLLSCAN."
  }
);

// --------------------------------------------------------------------------
// Index 3: Partial index — product_weight_g >= 20
//   Fields: product_weight_g, product_category_name
//   Options: partialFilterExpression: { product_weight_g: { $gte: 20 } }
//   Use case: Queries that filter for non-trivial product weights only
//             Smaller index size vs full-table index.
//   Query: db.products_catalog.find({
//            product_weight_g: { $gte: 20 },
//            product_category_name: "cama_mesa_banho"
//          })
// --------------------------------------------------------------------------
db.products_catalog.createIndex(
  {
    product_weight_g: 1,
    product_category_name: 1
  },
  {
    name: "idx_partial_weight_over_20",
    partialFilterExpression: {
      product_weight_g: { $gte: 20 }
    },
    background: true,
    comment: "Partial index: only indexes products with product_weight_g >= 20. Smaller maintenance, faster scans for weight queries."
  }
);

// --------------------------------------------------------------------------
// Delete Index: idx_esr_category_score_id (uses avg_review_score — not in Olist)
// --------------------------------------------------------------------------
const idxToRemove = "idx_esr_category_score_id";
const existingIndexes = db.products_catalog.getIndexes();
for (let idx of existingIndexes) {
  if (idx.name === idxToRemove) {
    print(`Dropping index: ${idxToRemove} — uses avg_review_score not present in Olist data`);
    db.products_catalog.dropIndex(idxToRemove);
  }
}

// --------------------------------------------------------------------------
// Remove generic indexes on fields not in Olist
// --------------------------------------------------------------------------
["avg_review_score", "tags"].forEach(field => {
  for (let idx of db.products_catalog.getIndexes()) {
    if (idx.name !== "_id_" && idx.key && idx.key[field] !== undefined) {
      print(`Dropping index on ${field}: ${idx.name}`);
      db.products_catalog.dropIndex(idx.name);
    }
  }
});

// --------------------------------------------------------------------------
// Summary
// --------------------------------------------------------------------------
print("\n=== Final indexes on products_catalog ===");
db.products_catalog.getIndexes().forEach(idx => {
  printjson({ name: idx.name, key: idx.key, partialFilterExpression: idx.partialFilterExpression || null });
});
