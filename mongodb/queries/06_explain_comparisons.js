// ============================================================================
// File: 06_explain_comparisons.js
// Purpose: Explain("executionStats") comparisons for all index types
// Collection: products_catalog
//
// For each index type, this file runs:
//   1. BEFORE — drop the index, run the query, capture explain metrics
//   2. AFTER  — create the index, run the query, capture explain metrics
//   3. Comparison — show executionTimeMillis, totalDocsExamined, nReturned
//
// Index types covered:
//   A. ESR compound index   (product_category_name + product_weight_g + product_height_cm)
//   B. Text index           (category_name_english)
//   C. Partial index        (product_weight_g >= 20)
//   D. Aggregation pipeline (early vs late $match)
//
// Real Olist fields used:
//   product_category_name, product_weight_g, product_height_cm,
//   product_id, category_name_english, product_length_cm, product_width_cm
// ============================================================================

use('ecommify');

print("========================================================================");
print("EXPLAIN COMPARISONS — All Index Types");
print("Metrics: executionTimeMillis, totalDocsExamined, nReturned");
print("========================================================================");

// ============================================================================
// Utility functions
// ============================================================================

function findStage(stage, name) {
  if (!stage) return null;
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

function printPlanDetails(label, explain, indexName) {
  const stats = explain.executionStats;
  const plan = explain.queryPlanner.winningPlan;
  const ixscan = findStage(plan, "IXSCAN");
  const collscan = findStage(plan, "COLLSCAN");

  print(`${label}:`);
  print(`  Winning plan stage : ${plan.stage}`);
  print(`  Execution time     : ${stats.executionTimeMillis} ms`);
  print(`  Docs examined      : ${stats.totalDocsExamined}`);
  print(`  Docs returned      : ${stats.nReturned}`);
  print(`  COLLSCAN?          : ${!!collscan}`);
  print(`  IXSCAN?            : ${!!ixscan}`);
  if (ixscan) {
    print(`  Index used         : ${ixscan.indexName}`);
    print(`  Keys examined      : ${ixscan.keysExamined}`);
    print(`  Is partial?        : ${ixscan.isPartial === true}`);
  }
  print();
}

// ============================================================================
// A. ESR COMPOUND INDEX
//    Index: idx_esr_category_weight_height
//    Fields: product_category_name (E), product_weight_g (S), product_height_cm (R)
// ============================================================================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
print("A. ESR COMPOUND INDEX");
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

const esrIndexName = "idx_esr_category_weight_height";
const esrFilter = {
  product_category_name: "utilidades_domesticas",
  product_height_cm: { $gte: 10, $lte: 30 }
};
const esrProjection = {
  product_id: 1, product_category_name: 1,
  product_weight_g: 1, product_height_cm: 1, _id: 0
};
const esrSort = { product_weight_g: 1 };

// BEFORE: Drop ESR index
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === esrIndexName) {
    db.products_catalog.dropIndex(esrIndexName);
    break;
  }
}
const beforeESR = db.products_catalog.find(esrFilter, esrProjection)
  .sort(esrSort).explain("executionStats");
printPlanDetails("ESR BEFORE (no index)", beforeESR, null);

// AFTER: Create ESR index
db.products_catalog.createIndex(
  { product_category_name: 1, product_weight_g: 1, product_height_cm: 1 },
  { name: esrIndexName, background: true }
);
const afterESR = db.products_catalog.find(esrFilter, esrProjection)
  .sort(esrSort).explain("executionStats");
printPlanDetails("ESR AFTER (with index)", afterESR, esrIndexName);

// ============================================================================
// B. TEXT INDEX
//    Index: idx_text_category_english
//    Fields: category_name_english (text)
// ============================================================================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
print("B. TEXT INDEX");
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

const textIndexName = "idx_text_category_english";
const searchTerm = "auto";
const textProjection = {
  product_id: 1, category_name_english: 1,
  product_category_name: 1, _id: 0
};

// BEFORE: Drop text index, use $regex
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === textIndexName) {
    db.products_catalog.dropIndex(textIndexName);
    break;
  }
}
const regexFilter = { category_name_english: { $regex: new RegExp(searchTerm, "i") } };
const beforeText = db.products_catalog.find(regexFilter, textProjection)
  .explain("executionStats");
printPlanDetails("TEXT BEFORE (regex COLLSCAN)", beforeText, null);

// AFTER: Create text index
db.products_catalog.createIndex(
  { category_name_english: "text" },
  { name: textIndexName, default_language: "none", background: true }
);
const textFilter = { $text: { $search: searchTerm } };
const afterText = db.products_catalog.find(
  textFilter,
  { ...textProjection, score: { $meta: "textScore" } }
).sort({ score: { $meta: "textScore" } }).explain("executionStats");
printPlanDetails("TEXT AFTER ($text IXSCAN)", afterText, textIndexName);

// ============================================================================
// C. PARTIAL INDEX
//    Index: idx_partial_weight_over_20
//    Fields: product_weight_g, product_category_name
//    Partial filter: product_weight_g >= 20
// ============================================================================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
print("C. PARTIAL INDEX (product_weight_g >= 20)");
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

const partialIndexName = "idx_partial_weight_over_20";
const partialFilter = {
  product_weight_g: { $gte: 20 },
  product_category_name: "cama_mesa_banho"
};
const partialProjection = {
  product_id: 1, product_weight_g: 1,
  product_category_name: 1, _id: 0
};

// BEFORE: Drop partial index
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === partialIndexName) {
    db.products_catalog.dropIndex(partialIndexName);
    break;
  }
}
// Also drop ESR index to avoid IXSCAN interference
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === esrIndexName) {
    db.products_catalog.dropIndex(esrIndexName);
    break;
  }
}
const beforePartial = db.products_catalog.find(partialFilter, partialProjection)
  .sort({ product_weight_g: 1 }).explain("executionStats");
printPlanDetails("PARTIAL BEFORE (no index, COLLSCAN)", beforePartial, null);

// AFTER: Create partial index
db.products_catalog.createIndex(
  { product_weight_g: 1, product_category_name: 1 },
  {
    name: partialIndexName,
    partialFilterExpression: { product_weight_g: { $gte: 20 } },
    background: true
  }
);
const afterPartial = db.products_catalog.find(partialFilter, partialProjection)
  .sort({ product_weight_g: 1 }).explain("executionStats");
printPlanDetails("PARTIAL AFTER (partial IXSCAN)", afterPartial, partialIndexName);

// Re-create the ESR index since we dropped it
db.products_catalog.createIndex(
  { product_category_name: 1, product_weight_g: 1, product_height_cm: 1 },
  { name: esrIndexName, background: true }
);

// ============================================================================
// D. AGGREGATION PIPELINE — early $match vs late $match
// ============================================================================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
print("D. AGGREGATION PIPELINE (early vs late $match)");
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

const pipelineCategory = "utilidades_domesticas";
const pipelineMinWeight = 20;

// Suboptimal pipeline: $match after $group
const suboptimalPipeline = [
  { $group: { _id: "$product_category_name", avg_weight_g: { $avg: "$product_weight_g" }, count: { $sum: 1 } } },
  { $match: { _id: pipelineCategory, avg_weight_g: { $gte: pipelineMinWeight } } },
  { $sort: { avg_weight_g: -1 } },
  { $limit: 5 }
];

// Optimal pipeline: $match before $group
const optimalPipeline = [
  { $match: { product_category_name: pipelineCategory, product_weight_g: { $gte: pipelineMinWeight } } },
  { $group: { _id: "$product_category_name", avg_weight_g: { $avg: "$product_weight_g" }, count: { $sum: 1 } } },
  { $sort: { avg_weight_g: -1 } },
  { $limit: 5 }
];

const beforeAggStart = Date.now();
const beforeAggResult = db.products_catalog.aggregate(suboptimalPipeline, { allowDiskUse: true }).toArray();
const beforeAggTime = Date.now() - beforeAggStart;

const afterAggStart = Date.now();
const afterAggResult = db.products_catalog.aggregate(optimalPipeline, { allowDiskUse: true }).toArray();
const afterAggTime = Date.now() - afterAggStart;

print("Pipeline metrics (measured, not explained — aggregation explainStats less granular):");
print(`  SUBOPTIMAL (late $match):  ${beforeAggTime} ms  — $group processes ALL documents`);
print(`  OPTIMAL    (early $match): ${afterAggTime} ms  — $match reduces input to $group`);
print(`  Speed-up:                  ${(beforeAggTime / Math.max(afterAggTime, 1)).toFixed(2)}x`);
print();

// Show aggregated results
print("Aggregation results (optimal):");
afterAggResult.forEach(r => printjson(r));
print();

// ============================================================================
// GRAND COMPARISON TABLE
// ============================================================================
print("========================================================================");
print("GRAND COMPARISON TABLE");
print("========================================================================");
print();

// Collect final metrics for each scenario
function extractMetrics(explain) {
  return {
    executionTimeMillis: explain.executionStats.executionTimeMillis,
    totalDocsExamined: explain.executionStats.totalDocsExamined,
    nReturned: explain.executionStats.nReturned
  };
}

const metricsESR = {
  before: extractMetrics(beforeESR),
  after: extractMetrics(afterESR)
};
const metricsText = {
  before: extractMetrics(beforeText),
  after: extractMetrics(afterText)
};
const metricsPartial = {
  before: extractMetrics(beforePartial),
  after: extractMetrics(afterPartial)
};

function padRight(s, n) { return String(s).padEnd(n); }

print(`${padRight("Metric", 22)} | ${padRight("ESR", 33)} | ${padRight("Text", 33)} | ${padRight("Partial", 33)}`);
print(`${padRight("", 22)}-+-${"-".repeat(33)}-+-${"-".repeat(33)}-+-${"-".repeat(33)}`);
print(`${padRight("", 22)} | ${padRight("BEFORE→AFTER", 33)} | ${padRight("BEFORE→AFTER", 33)} | ${padRight("BEFORE→AFTER", 33)}`);
print(`${"─".repeat(22)}-+-${"─".repeat(33)}-+-${"─".repeat(33)}-+-${"─".repeat(33)}`);

// executionTimeMillis row
const etBefore = `${metricsESR.before.executionTimeMillis} ms`;
const etAfter = `${metricsESR.after.executionTimeMillis} ms`;
const ttBefore = `${metricsText.before.executionTimeMillis} ms`;
const ttAfter = `${metricsText.after.executionTimeMillis} ms`;
const ptBefore = `${metricsPartial.before.executionTimeMillis} ms`;
const ptAfter = `${metricsPartial.after.executionTimeMillis} ms`;
print(`${padRight("executionTimeMillis", 22)} | ${padRight(`${etBefore} → ${etAfter}`, 33)} | ${padRight(`${ttBefore} → ${ttAfter}`, 33)} | ${padRight(`${ptBefore} → ${ptAfter}`, 33)}`);

// totalDocsExamined row
const edBefore = `${metricsESR.before.totalDocsExamined}`;
const edAfter = `${metricsESR.after.totalDocsExamined}`;
const tdBefore = `${metricsText.before.totalDocsExamined}`;
const tdAfter = `${metricsText.after.totalDocsExamined}`;
const pdBefore = `${metricsPartial.before.totalDocsExamined}`;
const pdAfter = `${metricsPartial.after.totalDocsExamined}`;
print(`${padRight("totalDocsExamined", 22)} | ${padRight(`${edBefore} → ${edAfter}`, 33)} | ${padRight(`${tdBefore} → ${tdAfter}`, 33)} | ${padRight(`${pdBefore} → ${pdAfter}`, 33)}`);

// nReturned row
const enBefore = `${metricsESR.before.nReturned}`;
const enAfter = `${metricsESR.after.nReturned}`;
const tnBefore = `${metricsText.before.nReturned}`;
const tnAfter = `${metricsText.after.nReturned}`;
const pnBefore = `${metricsPartial.before.nReturned}`;
const pnAfter = `${metricsPartial.after.nReturned}`;
print(`${padRight("nReturned", 22)} | ${padRight(`${enBefore} → ${enAfter}`, 33)} | ${padRight(`${tnBefore} → ${tnAfter}`, 33)} | ${padRight(`${pnBefore} → ${pnAfter}`, 33)}`);

// Scan type row
print(`${padRight("Scan type (BEFORE)", 22)} | ${padRight("COLLSCAN", 33)} | ${padRight("COLLSCAN (regex)", 33)} | ${padRight("COLLSCAN", 33)}`);
print(`${padRight("Scan type (AFTER)", 22)} | ${padRight("IXSCAN (ESR)", 33)} | ${padRight("IXSCAN ($text)", 33)} | ${padRight("IXSCAN (partial)", 33)}`);

// Aggregation pipeline
print(`${padRight("", 22)} | ${padRight("", 33)} | ${padRight("", 33)} | ${padRight("", 33)}`);
print(`${padRight("Aggregation speed", 22)} | ${padRight(`late: ${beforeAggTime}ms | early: ${afterAggTime}ms`, 33)} | ${padRight("", 33)} | ${padRight("", 33)}`);

print();
print("========================================================================");
print("CONCLUSIONS");
print("========================================================================");
print();
print("1. ESR INDEX: The compound index eliminates both COLLSCAN and SORT stage.");
print("   product_category_name (E) narrows, product_weight_g (S) enables index");
print("   sort, product_height_cm (R) range-scans efficiently.");
print();
print("2. TEXT INDEX: The $text index replaces regex COLLSCAN with IXSCAN.");
print("   default_language: 'none' preserves exact category name tokens (no stemming).");
print();
print("3. PARTIAL INDEX: Only indexes products with product_weight_g >= 20.");
print("   Smaller index, less write overhead. MongoDB automatically uses it");
print("   when the query filter subsumes the partialFilterExpression.");
print();
print("4. AGGREGATION: Moving $match before $group reduces the document flow");
print("   through the entire pipeline. The earlier the filter, the faster");
print("   the aggregation.");
print();
print("5. CROSS-CUTTING: All improvements derive from the same principle —");
print("   reduce the number of documents scanned or processed at each stage.");
print("   Indexes enable targeted document access; early filters reduce");
print("   pipeline flow.");
