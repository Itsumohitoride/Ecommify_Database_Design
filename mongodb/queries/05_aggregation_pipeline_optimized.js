// ============================================================================
// File: 05_aggregation_pipeline_optimized.js
// Purpose: 7-stage aggregation pipeline with BEFORE/AFTER optimization
// Collection: products_catalog
//
// Pipeline stages (AFTER — optimal order):
//   1. $match  — filter product_weight_g >= 20, specific product_category_name
//   2. $project  — shape documents (only needed fields)
//   3. $group  — group by product_category_name, compute avg weight
//   4. $lookup — join with event_logs for top 3 products per category
//   5. $addFields — add computed field (weight_kg)
//   6. $sort  — sort by avg_weight descending
//   7. $limit — top 5 categories
//
// Pipeline stages (BEFORE — suboptimal order):
//   1. $group  — group first (processes ALL documents)
//   2. $lookup — join event_logs
//   3. $project
//   4. $match  — filter AFTER group (more work)
//   5. $addFields
//   6. $sort
//   7. $limit
//
// Optimization principle: apply $match as early as possible to reduce
// document flow through downstream stages.
//
// Real Olist fields used:
//   product_category_name, product_weight_g, product_id,
//   product_height_cm, product_length_cm, product_width_cm
// ============================================================================

use('ecommify');

print("============================================");
print("Aggregation Pipeline Optimization");
print("============================================");
print();

// Ensure indexes exist for $match support
print("Ensuring supporting indexes exist...");
db.products_catalog.createIndex(
  { product_category_name: 1, product_weight_g: 1 },
  { name: "idx_temp_agg_category_weight", background: true }
);

// --------------------------------------------------------------------------
// Common parameters
// --------------------------------------------------------------------------
const categoryFilter = "utilidades_domesticas";
const minWeight = 20;

print(`Pipeline context:`);
print(`  Category filter: "${categoryFilter}"`);
print(`  Min weight: ${minWeight}g`);
print(`  Limit: top 5 categories`);
print();

// ============================================================================
// BEFORE: Suboptimal pipeline — $match placed after $group
// ============================================================================
print("--- BEFORE (suboptimal pipeline order) ---");
print("    $match is AFTER $group — processes ALL documents");
print();

const beforePipeline = [
  // Stage 1: $group on ALL documents (no prior filter)
  {
    $group: {
      _id: "$product_category_name",
      avg_weight_g: { $avg: "$product_weight_g" },
      total_products: { $sum: 1 },
      products: { $push: { product_id: "$product_id", weight_g: "$product_weight_g" } }
    }
  },
  // Stage 2: $lookup — join with event_logs collection
  {
    $lookup: {
      from: "event_logs",
      let: { category: "$_id" },
      pipeline: [
        { $match: { $expr: { $eq: ["$category", "$$category"] } } },
        { $group: { _id: "$event_type", count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 3 }
      ],
      as: "event_stats"
    }
  },
  // Stage 3: $project — shape output
  {
    $project: {
      _id: 0,
      category_name: "$_id",
      avg_weight_g: 1,
      total_products: 1,
      event_stats: 1,
      sample_products: { $slice: ["$products", 3] }
    }
  },
  // Stage 4: $match — filter AFTER grouping (SUBPOPTIMAL)
  {
    $match: {
      category_name: categoryFilter,
      avg_weight_g: { $gte: minWeight }
    }
  },
  // Stage 5: $addFields — computed weight in kg
  {
    $addFields: {
      avg_weight_kg: { $divide: ["$avg_weight_g", 1000] }
    }
  },
  // Stage 6: $sort
  {
    $sort: { avg_weight_g: -1 }
  },
  // Stage 7: $limit
  { $limit: 5 }
];

print("BEFORE pipeline stages:");
beforePipeline.forEach((stage, i) => {
  const key = Object.keys(stage)[0];
  print(`  ${i + 1}. \$${key}${key === "match" ? " ← AFTER group (suboptimal!)" : ""}`);
});

const beforeStart = Date.now();
const beforeResults = db.products_catalog.aggregate(beforePipeline, { allowDiskUse: true }).toArray();
const beforeTime = Date.now() - beforeStart;

print(`\n  Execution time: ${beforeTime} ms`);
print(`  Documents in pipeline (from $group input): reads ALL documents in collection`);

// Count total documents for comparison
const totalDocs = db.products_catalog.countDocuments();
print(`  Total collection documents: ${totalDocs}`);
print();

// ============================================================================
// AFTER: Optimal pipeline — $match before $group
// ============================================================================
print("--- AFTER (optimal pipeline order) ---");
print("    $match is BEFORE $group — filters first, reduces downstream work");
print();

const afterPipeline = [
  // Stage 1: $match — filter EARLY (reduces documents flowing through pipeline)
  {
    $match: {
      product_category_name: categoryFilter,
      product_weight_g: { $gte: minWeight }
    }
  },
  // Stage 2: $project — only keep fields needed by later stages
  {
    $project: {
      product_category_name: 1,
      product_weight_g: 1,
      product_id: 1,
      product_height_cm: 1,
      product_length_cm: 1,
      product_width_cm: 1
    }
  },
  // Stage 3: $group — now processes a SUBSET of documents
  {
    $group: {
      _id: "$product_category_name",
      avg_weight_g: { $avg: "$product_weight_g" },
      total_products: { $sum: 1 },
      avg_height_cm: { $avg: "$product_height_cm" },
      sample_products: {
        $push: {
          product_id: "$product_id",
          weight_g: "$product_weight_g"
        }
      }
    }
  },
  // Stage 4: $lookup — top 3 event types per category from event_logs
  {
    $lookup: {
      from: "event_logs",
      let: { category: "$_id" },
      pipeline: [
        { $match: { $expr: { $eq: ["$category", "$$category"] } } },
        { $group: { _id: "$event_type", count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 3 }
      ],
      as: "event_stats"
    }
  },
  // Stage 5: $addFields — computed field (weight in kg)
  {
    $addFields: {
      avg_weight_kg: { $divide: ["$avg_weight_g", 1000] },
      sample_count: { $size: "$sample_products" }
    }
  },
  // Stage 6: $sort — by average weight descending
  {
    $sort: { avg_weight_g: -1 }
  },
  // Stage 7: $limit — top 5 categories
  { $limit: 5 }
];

print("AFTER pipeline stages:");
afterPipeline.forEach((stage, i) => {
  const key = Object.keys(stage)[0];
  print(`  ${i + 1}. \$${key}${key === "match" ? " ← BEFORE group (optimal!)" : ""}`);
});

const afterStart = Date.now();
const afterResults = db.products_catalog.aggregate(afterPipeline, { allowDiskUse: true }).toArray();
const afterTime = Date.now() - afterStart;

print(`\n  Execution time: ${afterTime} ms`);

// Show results
print("\nAFTER pipeline results:");
afterResults.forEach(r => printjson(r));

// ============================================================================
// Comparison summary
// ============================================================================
print("\n============================================");
print("COMPARISON SUMMARY");
print("============================================");
print(`Aspect                  | BEFORE (suboptimal) | AFTER (optimal)`);
print(`------------------------|---------------------|-----------------`);
print(`$match position         | After $group        | Before $group`);
print(`$group input            | ALL ${String(totalDocs).padStart(6)} documents     | Filtered subset`);
print(`Pipeline stages         | 7                   | 7`);
print(`allowDiskUse            | true                | true`);
print(`Execution time          | ${String(beforeTime).padStart(18)} ms   | ${String(afterTime).padStart(14)} ms`);
print(`============================================");
print();
print("CONCLUSION: Moving $match before $group is the single most impactful");
print("aggregation optimization. In the BEFORE pipeline, $group reads every");
print("document in the collection, creates large arrays via $push for the");
print("sample_products field, then filters AFTER. In the AFTER pipeline, $match");
print("reduces the document count first — subsequent stages process fewer");
print("documents, require less memory, and the $push arrays are smaller.");
print();
print("The $lookup pipeline uses a sub-pipeline with $group and $limit to");
print("return only the top 3 event types per category, rather than joining");
print("every event. Combined with early $match, this keeps the entire");
print("pipeline efficient.");
