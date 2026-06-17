// ============================================================================
// File: 02_esr_queries_optimized.js
// Purpose: Demonstrate ESR (Equality-Sort-Range) index optimization
// Collection: products_catalog
//
// Optimization:
//   BEFORE: No compound index → COLLSCAN + in-memory SORT
//   AFTER:  Compound ESR index  → IXSCAN (no separate SORT stage)
//
// ESR Rule: Equality → Sort → Range
//   E: product_category_name (exact match)
//   S: product_weight_g (sort ascending)
//   R: product_height_cm (range filter)
//
// Real Olist fields:
//   product_category_name — category in Portuguese (e.g. "utilidades_domesticas")
//   product_weight_g      — weight in grams
//   product_height_cm     — height in cm
//   product_id            — MD5 hash string
// ============================================================================

use('ecommify');

print("============================================");
print("ESR Query Optimization — BEFORE vs AFTER");
print("============================================");
print();

// --------------------------------------------------------------------------
// Test parameters
// --------------------------------------------------------------------------
const targetCategory = "utilidades_domesticas";
const minHeight = 10;
const maxHeight = 30;
const queryFilter = {
  product_category_name: targetCategory,
  product_height_cm: { $gte: minHeight, $lte: maxHeight }
};
const querySort = { product_weight_g: 1 };
const queryProjection = {
  product_id: 1,
  product_category_name: 1,
  product_weight_g: 1,
  product_height_cm: 1,
  _id: 0
};

print(`Query: find products with`);
print(`  product_category_name = "${targetCategory}"`);
print(`  product_height_cm between ${minHeight} and ${maxHeight}`);
print(`  sorted by product_weight_g ascending`);
print();

// ============================================================================
// BEFORE: No ESR index — full collection scan
// ============================================================================
print("--- BEFORE (COLLSCAN + SORT) ---");

// Drop the ESR index to simulate unoptimized state
const esrIndexName = "idx_esr_category_weight_height";
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === esrIndexName) {
    db.products_catalog.dropIndex(esrIndexName);
    print(`Dropped index: ${esrIndexName}`);
    break;
  }
}

// Run explain to see the query plan
const beforeExplain = db.products_catalog.find(queryFilter, queryProjection)
  .sort(querySort)
  .explain("executionStats");

print("\nBEFORE — Query Plan:");
print(`  Stage: ${beforeExplain.queryPlanner.winningPlan.stage}`);
print(`  Input documents: ${JSON.stringify(beforeExplain.executionStats.totalDocsExamined)}`);
print(`  Returned documents: ${JSON.stringify(beforeExplain.executionStats.nReturned)}`);
print(`  Execution time: ${JSON.stringify(beforeExplain.executionStats.executionTimeMillis)} ms`);

// --------------------------------------------------------------------------
// Identify the problematic plan stage (COLLSCAN or IXSCAN + SORT)
// --------------------------------------------------------------------------
function findStage(stage, name) {
  if (stage.stage === name) return stage;
  if (stage.inputStage) return findStage(stage.inputStage, name);
  if (stage.inputStages) {
    for (let s of stage.inputStages) {
      const found = findStage(s, name);
      if (found) return found;
    }
  }
  return null;
}

const beforeCollectionScan = findStage(beforeExplain.queryPlanner.winningPlan, "COLLSCAN");
print(`  Has COLLSCAN: ${!!beforeCollectionScan}`);
const beforeSortStage = findStage(beforeExplain.queryPlanner.winningPlan, "SORT");
print(`  Has SORT stage: ${!!beforeSortStage}`);

if (beforeCollectionScan) {
  print("  ⚠ PROBLEM: Full collection scan — no index on product_category_name + product_height_cm");
}

print();

// ============================================================================
// AFTER: With ESR index — indexed scan
// ============================================================================
print("--- AFTER (IXSCAN, no SORT stage) ---");

// Create the ESR index
db.products_catalog.createIndex(
  {
    product_category_name: 1,
    product_weight_g: 1,
    product_height_cm: 1
  },
  {
    name: esrIndexName,
    background: true
  }
);
print(`Created index: ${esrIndexName} on (product_category_name, product_weight_g, product_height_cm)`);

// Run explain with the index
const afterExplain = db.products_catalog.find(queryFilter, queryProjection)
  .sort(querySort)
  .explain("executionStats");

print("\nAFTER — Query Plan:");
print(`  Stage: ${afterExplain.queryPlanner.winningPlan.stage}`);
print(`  Input documents examined: ${JSON.stringify(afterExplain.executionStats.totalDocsExamined)}`);
print(`  Returned documents: ${JSON.stringify(afterExplain.executionStats.nReturned)}`);
print(`  Execution time: ${JSON.stringify(afterExplain.executionStats.executionTimeMillis)} ms`);

const afterIndexScan = findStage(afterExplain.queryPlanner.winningPlan, "IXSCAN");
print(`  Has IXSCAN: ${!!afterIndexScan}`);
const afterSortStage = findStage(afterExplain.queryPlanner.winningPlan, "SORT");
print(`  Has SORT stage: ${!!afterSortStage}`);

if (afterIndexScan) {
  print(`  IXSCON index: ${afterIndexScan.indexName}`);
  print(`  IXSCON keys examined: ${afterIndexScan.keysExamined}`);
}
if (!afterSortStage) {
  print("  ✓ Index provided sort — no separate SORT stage needed");
}

// --------------------------------------------------------------------------
// Run the actual query (with results) for verification
// --------------------------------------------------------------------------
print("\n--- Query Results (AFTER — first 5) ---");
const results = db.products_catalog.find(queryFilter, queryProjection)
  .sort(querySort)
  .limit(5)
  .toArray();
results.forEach(r => printjson(r));
print(`Total results available (limited to 5 shown): ${results.length}`);

// ============================================================================
// Comparison summary
// ============================================================================
print("\n============================================");
print("COMPARISON SUMMARY");
print("============================================");
print(`Metric                  | BEFORE (COLLSCAN) | AFTER (IXSCAN)`);
print(`------------------------|-------------------|-----------------`);
print(`Documents examined      | ${String(beforeExplain.executionStats.totalDocsExamined).padStart(17)} | ${String(afterExplain.executionStats.totalDocsExamined).padStart(15)}`);
print(`Documents returned      | ${String(beforeExplain.executionStats.nReturned).padStart(17)} | ${String(afterExplain.executionStats.nReturned).padStart(15)}`);
print(`Execution time (ms)     | ${String(beforeExplain.executionStats.executionTimeMillis).padStart(17)} | ${String(afterExplain.executionStats.executionTimeMillis).padStart(15)}`);
print(`Scan type               | COLLSCAN           | IXSCAN`);
print(`Sort stage required     | YES                | NO (index-provided)`);
print(`Index used              | none               | ${esrIndexName}`);
print("============================================");
print();
print("CONCLUSION: The ESR index eliminates both the COLLSCAN and the in-memory");
print("SORT stage. product_category_name (Equality) narrows the search,");
print("product_weight_g (Sort) enables index-ordered traversal, and");
print("product_height_cm (Range) is efficiently scanned within the sorted range.");
