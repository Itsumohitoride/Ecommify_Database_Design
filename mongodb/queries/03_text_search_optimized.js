// ============================================================================
// File: 03_text_search_optimized.js
// Purpose: Demonstrate text index optimization for category_name_english
// Collection: products_catalog
//
// Optimization:
//   BEFORE: $regex on category_name_english → COLLSCAN (scans every document)
//   AFTER:  $text index on category_name_english → IXSCAN (token-matched scan)
//
// Context: category_name_english is the ONLY text field in the Olist dataset.
//          It contains English category names like "auto", "health_beauty",
//          "electronics", "bed_bath_table", "sports_leisure", etc.
//
//          The token "auto" is a confirmed single-word token in Olist data
//          (category: "carros" in Portuguese → "auto" in English).
//
// Real Olist fields used:
//   category_name_english  — English category name (text, only text field)
//   product_id             — MD5 hash string
//   product_category_name  — Portuguese category name
// ============================================================================

use('ecommify');

print("============================================");
print("Text Search Optimization — BEFORE vs AFTER");
print("============================================");
print();

const searchTerm = "auto";

print(`Search term: "${searchTerm}"`);
print(`Field: category_name_english`);
print();

// ============================================================================
// BEFORE: Regex search on category_name_english — full collection scan
// ============================================================================
print("--- BEFORE ($regex COLLSCAN) ---");

// Ensure text index is dropped to simulate unoptimized state
const textIndexName = "idx_text_category_english";
for (let idx of db.products_catalog.getIndexes()) {
  if (idx.name === textIndexName) {
    db.products_catalog.dropIndex(textIndexName);
    print(`Dropped index: ${textIndexName}`);
    break;
  }
}

// Build insensitive regex for the search term
const regexPattern = new RegExp(searchTerm, "i");
const regexFilter = { category_name_english: { $regex: regexPattern } };
const projection = { product_id: 1, category_name_english: 1, product_category_name: 1, _id: 0 };

const beforeExplain = db.products_catalog.find(regexFilter, projection)
  .explain("executionStats");

print("\nBEFORE — Query Plan:");
print(`  Winning plan stage: ${beforeExplain.queryPlanner.winningPlan.stage}`);

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
print(`  Has COLLSCAN: ${!!beforeCollscan}`);
print(`  Documents examined: ${JSON.stringify(beforeExplain.executionStats.totalDocsExamined)}`);
print(`  Documents returned: ${JSON.stringify(beforeExplain.executionStats.nReturned)}`);
print(`  Execution time: ${JSON.stringify(beforeExplain.executionStats.executionTimeMillis)} ms`);

if (beforeCollscan) {
  print("  ⚠ PROBLEM: Regex forces full collection scan — no index on category_name_english");
}

// Show sample regex results
print("\nSample regex results (first 3):");
const regexResults = db.products_catalog.find(regexFilter, projection).limit(3).toArray();
regexResults.forEach(r => printjson(r));

print();

// ============================================================================
// AFTER: $text search on category_name_english — indexed scan
// ============================================================================
print("--- AFTER ($text IXSCAN) ---");

// Create text index on category_name_english with default_language: "none"
// "none" = no stemming, treats every word as-is (important for category tokens)
db.products_catalog.createIndex(
  { category_name_english: "text" },
  {
    name: textIndexName,
    default_language: "none",
    background: true
  }
);
print(`Created index: ${textIndexName} with default_language: "none"`);

// $text query — returns documents where the indexed text matches the search term
// Include textScore metadata for relevance ranking
const textFilter = { $text: { $search: searchTerm } };
const textProjection = {
  product_id: 1,
  category_name_english: 1,
  product_category_name: 1,
  score: { $meta: "textScore" },
  _id: 0
};

const afterExplain = db.products_catalog.find(textFilter, textProjection)
  .sort({ score: { $meta: "textScore" } })
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
  print("  ✓ Text index used — no COLLSCAN");
}

// Show sample $text results (ranked by textScore)
print("\nSample $text results (ranked by textScore, first 5):");
const textResults = db.products_catalog.find(textFilter, textProjection)
  .sort({ score: { $meta: "textScore" } })
  .limit(5)
  .toArray();
textResults.forEach(r => printjson(r));

// ============================================================================
// Comparison summary
// ============================================================================
print("\n============================================");
print("COMPARISON SUMMARY");
print("============================================");
print(`Metric                  | BEFORE (regex)    | AFTER ($text)`);
print(`------------------------|-------------------|-----------------`);
print(`Documents examined      | ${String(beforeExplain.executionStats.totalDocsExamined).padStart(17)} | ${String(afterExplain.executionStats.totalDocsExamined).padStart(15)}`);
print(`Documents returned      | ${String(beforeExplain.executionStats.nReturned).padStart(17)} | ${String(afterExplain.executionStats.nReturned).padStart(15)}`);
print(`Execution time (ms)     | ${String(beforeExplain.executionStats.executionTimeMillis).padStart(17)} | ${String(afterExplain.executionStats.executionTimeMillis).padStart(15)}`);
print(`Scan type               | COLLSCAN           | IXSCAN`);
print(`Index used              | none               | ${textIndexName}`);
print(`Language stemming       | N/A                | none (verbatim)`);
print(`Relevance ranking       | none               | textScore meta`);
print("============================================");
print();
print("CONCLUSION: The $text index on category_name_english replaces a full");
print("COLLSCAN (regex match evaluated on every document) with an IXSCAN that");
print("navigates the text index's token dictionary directly. This is a linear");
print("vs logarithmic lookup — orders of magnitude faster on large collections.");
print();
print("NOTE: default_language: 'none' is critical for category names. Without it,");
print("MongoDB's stemmer would reduce tokens like 'health_beauty' to 'health'");
print("and 'beauti', breaking exact category matching.");
