// ============================================================================
// File: 04_partial_indexes_optimized.js
// Purpose: Demonstrate partial index optimization for product_weight_g >= 20
// Collection: products_catalog
//
// Optimization:
//   BEFORE: No index on product_weight_g → COLLSCAN with full filter
//           Scans every document even though most queries filter weight >= 20
//   AFTER:  Partial index { product_weight_g: { $gte: 20 } } → IXSCAN
//           Only indexes documents matching the partial filter
//
// Benefits of partial index:
//   - Smaller index size (only documents with weight >= 20)
//   - Less write overhead on inserts/updates
//   - Faster index scans for filtered queries
//   - MongoDB automatically uses it when query matches the partial expression
//
// Real Olist fields used:
//   product_weight_g         — weight in grams
//   product_category_name   — Portuguese category name
//   product_id              — MD5 hash string
// ============================================================================

use('ecommify');

print("============================================");
print("Partial Index Optimization — BEFORE vs AFTER");
print("============================================");
print();

// --------------------------------------------------------------------------
// Test query: find non-trivial weight products in a category
// --------------------------------------------------------------------------
const queryFilter = {
  product_weight_g: { $gte: 20 },
  product_category_name: "cama_mesa_banho"
};
const queryProjection = {
  product_id: 1,
  product_weight_g: 1,
  product_category_name: 1,
  _id: 0
};

print(`Query: find products with`);
print(`  product_weight_g >= 20`);
print(`  product_category_name = "cama_mesa_banho"`);
print();

// ============================================================================
// BEFORE: No partial index — full collection scan
// ============================================================================
print("--- BEFORE (COLLSCAN — full filter on every document) ---");

// Drop the partial index if it exists
const partialIndexName = "idx_partial_weight_over_20";
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === partialIndexName) {
    db.products_catalog.dropIndex(partialIndexName);
    print(`Dropped index: ${partialIndexName}`);
    break;
  }
}

// Also drop the ESR index to avoid it being picked up
const esrIndexName = "idx_esr_category_weight_height";
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === esrIndexName) {
    db.products_catalog.dropIndex(esrIndexName);
    print(`Dropped index: ${esrIndexName} (to isolate partial index impact)`);
    break;
  }
}

const beforeExplain = db.products_catalog.find(queryFilter, queryProjection)
  .sort({ product_weight_g: 1 })
  .explain("executionStats");

print("\nBEFORE — Query Plan:");

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

const beforeCollscan = findStage(beforeExplain.queryPlanner.winningPlan, "COLLSCAN");
print(`  Winning plan stage: ${beforeExplain.queryPlanner.winningPlan.stage}`);
print(`  Has COLLSCAN: ${!!beforeCollscan}`);
print(`  Documents examined: ${JSON.stringify(beforeExplain.executionStats.totalDocsExamined)}`);
print(`  Documents returned: ${JSON.stringify(beforeExplain.executionStats.nReturned)}`);
print(`  Execution time: ${JSON.stringify(beforeExplain.executionStats.executionTimeMillis)} ms`);

if (beforeCollscan) {
  print("  ⚠ PROBLEM: Full collection scan — examining ALL documents");
  print("              even though we only need product_weight_g >= 20");
}

// Show the collection size for context
const totalDocs = db.products_catalog.countDocuments();
print(`  Total documents in collection: ${totalDocs}`);

print();

// ============================================================================
// AFTER: Partial index (product_weight_g >= 20) — index scan
// ============================================================================
print("--- AFTER (IXSCAN via partial index) ---");

// Create partial index: only indexes documents where product_weight_g >= 20
db.products_catalog.createIndex(
  {
    product_weight_g: 1,
    product_category_name: 1
  },
  {
    name: partialIndexName,
    partialFilterExpression: {
      product_weight_g: { $gte: 20 }
    },
    background: true
  }
);
print(`Created index: ${partialIndexName}`);
print(`  Partial filter: product_weight_g >= 20`);
print(`  Fields: (product_weight_g, product_category_name)`);

const afterExplain = db.products_catalog.find(queryFilter, queryProjection)
  .sort({ product_weight_g: 1 })
  .explain("executionStats");

print("\nAFTER — Query Plan:");
print(`  Winning plan stage: ${afterExplain.queryPlanner.winningPlan.stage}`);

const afterIxscan = findStage(afterExplain.queryPlanner.winningPlan, "IXSCAN");
print(`  Has IXSCAN: ${!!afterIxscan}`);
print(`  Documents examined: ${JSON.stringify(afterExplain.executionStats.totalDocsExamined)}`);
print(`  Documents returned: ${JSON.stringify(afterExplain.executionStats.nReturned)}`);
print(`  Execution time: ${JSON.stringify(afterExplain.executionStats.executionTimeMillis)} ms`);

if (afterIxscan) {
  print(`  IXSCAN index: ${afterIxscan.indexName}`);
  print(`  IXSCAN keys examined: ${afterIxscan.keysExamined}`);
  print(`  IXSCAN isPartial: ${afterIxscan.isPartial}`);
  if (afterIxscan.isPartial) {
    print("  ✓ Partial index used — only scanned documents matching the filter");
  }
}

// Show sample results
print("\nSample results (first 3):");
const results = db.products_catalog.find(queryFilter, queryProjection)
  .sort({ product_weight_g: 1 })
  .limit(3)
  .toArray();
results.forEach(r => printjson(r));

// ============================================================================
// Comparison summary
// ============================================================================
print("\n============================================");
print("COMPARISON SUMMARY");
print("============================================");
print(`Metric                  | BEFORE (COLLSCAN) | AFTER (partial IXSCAN)`);
print(`------------------------|-------------------|------------------------`);
print(`Documents examined      | ${String(beforeExplain.executionStats.totalDocsExamined).padStart(17)} | ${String(afterExplain.executionStats.totalDocsExamined).padStart(22)}`);
print(`Documents returned      | ${String(beforeExplain.executionStats.nReturned).padStart(17)} | ${String(afterExplain.executionStats.nReturned).padStart(22)}`);
print(`Execution time (ms)     | ${String(beforeExplain.executionStats.executionTimeMillis).padStart(17)} | ${String(afterExplain.executionStats.executionTimeMillis).padStart(22)}`);
print(`Scan type               | COLLSCAN           | IXSCAN (partial)`);
print(`Index used              | none               | ${partialIndexName}`);
print(`Index size (est.)       | N/A                | Smaller (filtered subset)`);
print(`Write overhead          | N/A                | Lower (skip thin products)`);
print("============================================");
print();
print("CONCLUSION: The partial index idx_partial_weight_over_20 only stores");
print("entries for products with product_weight_g >= 20. This means:");
print("  1. Fewer index entries → smaller index on disk");
print("  2. Less maintenance on writes (thin products skip the index)");
print("  3. MongoDB automatically uses it when the query filter subsumes");
print("     the partialFilterExpression");
print();
print("KEY INSIGHT: The query filter { product_weight_g: { $gte: 20 } }");
print("is a superset of the partial filter { $gte: 20 }. MongoDB detects");
print("this and uses the partial index. If the query had $gte: 5, the");
print("partial index would NOT be used.");
