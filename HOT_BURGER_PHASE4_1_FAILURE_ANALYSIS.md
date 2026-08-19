# HOT BURGER — Phase 4.1 FAILURE INVESTIGATION (READ-ONLY)

**Author:** Manus AI
**Date:** 2026-08-19
**Mode:** ABSOLUTE FREEZE — INSPECT / TRACE / CLASSIFY / DOCUMENT only.
**Files Modified = 0, Database Modified = NO, Schema Modified = NO, Migrations Modified = NO, Tests Modified = NO, Production Logic Modified = NO, Commit = NO, Push = NO.**

---

# Executive Summary

Last CI run **32248864997** (commit `a6bbf58`, repository `thikryat57-oss/hot-burger-last`, branch `main`, workflow `build_apk.yml`) ended with **72 tests passed, 2 tests failed** (exit code 1). Both failures belong to the **new Phase 4.1 integration tests** (the two L-1 "legacy fallback" tests in `test/db_integration_test.dart`). No existing baseline test regressed: all 59 pre-Phase-4.1 tests passed, `flutter analyze` reported **0 errors**, and the Release APK job succeeded in the same pipeline.

The root cause of both failures is **a test-expectation problem (Category A — Test Bug)**, not production logic. The production code in `restoreInventoryFromSnapshots` implements the documented L-1 "legacy no-false-confidence" contract correctly: every legacy line leaves an explicit, provable audit trace, and legacy restoration restores from **current** recipe links. The two new tests were written with two wrong assumptions about that contract:

1. **Test #1 (NO links):** asserted the diagnostic audit row uses `action_type = 'ingredient_deleted'`, while the production code — deliberately and consistently — writes the audit row with the **same `action_type` as the return operation** (`'sale_returned'`), exactly as it does for `LEGACY_FALLBACK`, `HISTORICAL_SNAPSHOT`, and `SNAPSHOT_ONLY_INGREDIENT_DELETED` rows. The assertion filter therefore matched zero rows and the `audit.any(...)` check failed.
2. **Test #2 (WITH links):** asserted `bread` inventory level `100.0` after legacy return, while the fixture seeds the current recipe with `bread: 2.0` per unit (`seedRecipe(db, burger, {bread: 2.0, beef: 100.0})` at `test/db_integration_test.dart:50`). The documented legacy fallback restores **both** current links (beef 100 × 1 + bread 2 × 1), so bread correctly goes from 100 to **102**.

**Final verdict: SAFE TO FIX TEST.**

---

# Current Test Result

| Metric | Value |
|---|---|
| CI run | `32248864997` (workflow `build_apk.yml`, run on commit `a6bbf58`) |
| `flutter analyze` | 0 errors (pre-existing warnings in out-of-scope files only) |
| Tests | **72 passed, 2 failed** |
| Test file with failures | `test/db_integration_test.dart`, group "Phase 4.1 - destructive safety closure" |
| Release APK job | success (all later runs) |
| Exit code | 1 |

Source: `gh run view 32248864997 --log` (full log preserved at `/tmp/gh-fail1.log`).

# Previous Stable Result

| Metric | Value |
|---|---|
| CI run | `32230057100` at commit `c7777b9` |
| Tests | **59/59 passed**, 0 analyze errors, Release APK built |
| Composition | financial_calculator 29 + recipe_snapshot 18 + db_integration 11 + cost_snapshot (~1) |

# Failed Test 1

## Test Name

> Phase 4.1 - destructive safety closure legacy fallback with NO current recipe links logs an explicit diagnostic (L-1)

## Expected

`isTrue` — the audit query was expected to find at least one row whose `note` contains `LEGACY_FALLBACK_NO_RECIPE_LINKS`.

## Actual

`false` — the audit query returned rows, but **none** matched the filter, so `audit.any(...)` evaluated to `false`.

## Stack Trace (verbatim from CI log)

```
Expected: true
  Actual: <false>

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 480:18  expect
test/db_integration_test.dart 637:7                 main.<fn>.<fn>
```

## Failure Location

`test/db_integration_test.dart`, lines **634–638** (the query + assertion). The failing expression is the `expect(audit.any(...), isTrue)` at line 637.

## Classification

**A — Test Bug** (incorrect expectation written into a newly added test).

## Root Cause

The fixture deletes all current recipe links *after* the legacy sale (`await db.delete('product_ingredients')` at line 630), which correctly forces the `LEGACY_FALLBACK_NO_RECIPE_LINKS` branch in `restoreInventoryFromSnapshots` (production, `app_provider.dart`, ~line 985–1005). That branch writes the diagnostic audit row with:

```dart
'action_date': now, 'action_type': actionType, 'ingredient_id': null,
'ingredient_name': productName, ...
'note': 'LEGACY_FALLBACK_NO_RECIPE_LINKS',
```

where `actionType` is passed from `returnInvoice` as **`'sale_returned'`** (`app_provider.dart:779`). The test, however, filtered with:

```dart
where: "reference_type = 'invoice' AND reference_id = ? AND action_type = ?",
whereArgs: [invId, 'ingredient_deleted']   // WRONG: production never writes this here
```

The constant `'ingredient_deleted'` belongs to the *ingredient deletion* audit rows — not to return-path diagnostic rows. The note content (which is what the L-1 contract actually requires) was correct and present in the database; only the test's `action_type` filter rejected it.

## Evidence

CI log of the failing job shows the assertion failing at line 637 with `Expected: true / Actual: <false>`. Reading the production code (`app_provider.dart` lines 985–1005 and `returnInvoice` at line 779) confirms the diagnostic row is written with `action_type = 'sale_returned'` and `note = 'LEGACY_FALLBACK_NO_RECIPE_LINKS'`, inside the same transaction as the return. The `LEGACY_FALLBACK` sibling branch (line ~1011) also uses `action_type = actionType`, proving consistency: the whole return path shares one `action_type` and is distinguished by `note` markers, never by a synthetic `action_type`.

# Failed Test 2

## Test Name

> Phase 4.1 - destructive safety closure legacy fallback WITH current links verifies link count in diagnostics (L-1)

## Expected

`inventoryLevel(db, env.bread)` == **100.0** (bread untouched).

## Actual

**102.0** — bread was restored by +2 during the legacy return.

## Stack Trace (verbatim from CI log)

```
Expected: <100.0>
  Actual: <102.0>

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 480:18  expect
test/db_integration_test.dart 682:7                 main.<fn>.<fn>
```

## Failure Location

`test/db_integration_test.dart`, line **682**: `expect(await inventoryLevel(db, env.bread), 100.0);`.

## Classification

**A — Test Bug** (expectation contradicts the fixture's own recipe seeding and the documented legacy-fallback semantics).

## Root Cause

The test fixture `_seed` (line 50) seeds the burger recipe as `{bread: 2.0, beef: 100.0}`. The hand-seeded legacy invoice in this test deducts **only beef** (legacy audit row: `ingredient_id = env.beef, quantity_change = -100`) and updates `inventory` so that beef = 900 while bread remains 100 — mirroring a real legacy device where no per-ingredient deduction rows existed for bread (or bread was seeded with full stock).

The legacy fallback path in `restoreInventoryFromSnapshots` (~line 1006–1020) restores **every current recipe link**: for each link, `restore = link.quantity × soldQty = 2.0 × 1 = 2` for bread and `100.0 × 1 = 100` for beef. Hence bread: 100 → **102**, beef: 900 → **1000**. The test's expectation of 100 for bread contradicts its own fixture and the documented behavior. Notably, the same test correctly asserts `hasLength(2)` LEGACY_FALLBACK audit rows (bread + beef) and beef = 1000 — only the bread quantity assertion was wrong.

This is also exactly the "no false confidence" behavior the contract requires: the legacy line is restored from the recipe that exists **today**, and every restored unit is individually audited. Restoring nothing for bread would itself be a silent partial restoration.

## Evidence

Production code at `app_provider.dart:1006–1020` (per-link restore loop) and fixture at `test/db_integration_test.dart:50` (`{bread: 2.0, beef: 100.0}`) and lines 616–627 (legacy sale touches beef only). The arithmetic 100 + (2.0 × 1) = 102 is deterministic and matches the `Actual: <102.0>` observed in CI.

# Git Diff Analysis

Comparison of **before Phase 4.1** (`8ca0dda` — Phase 2.3.1 report commit) and **after Phase 4.1** (`989de70`):

| File | Change | Category |
|---|---|---|
| `lib/core/database/database_helper.dart` | +338 lines | **Production** — SafeDeleteBlockedException, `getIngredientImpact`, `deleteIngredientSafe`, `deleteProductSafe`, `deleteSupplierSafe`, `deleteProductIngredientSafe`, `deleteExpenseSafe`; `_createVersion4Tables` hardening |
| `lib/providers/app_provider.dart` | +87 / −27 lines | **Production** — safe-delete wrappers, L-1 diagnostic audit in `restoreInventoryFromSnapshots` |
| `lib/screens/inventory/inventory_screen.dart` | +66 lines | **UI** — impact preview dialog with explicit override |
| `test/db_integration_test.dart` | +342 lines | **Test** — 15 new Phase 4.1 integration tests |

## Production Changes

All three production files changed are **additive**: new safe helpers, new wrappers, new UI dialog. No existing function signature was broken; existing delete semantics were replaced by safe-by-default transactional equivalents.

## Test Changes

One file changed: `test/db_integration_test.dart` — the two failing expectations (lines 634–638 and 682) were **added** in Phase 4.1 along with the other 13 new tests. No pre-existing test was modified.

## Database / Migration / Schema Changes

**NONE.** `git diff 8ca0dda 989de70 -- lib/core/database/database_helper.dart | grep -E "CREATE TABLE|ALTER TABLE|user_version|dbVersion"` returns empty; `dbVersion` remains **16**; no `_onCreate`/`_onUpgrade` logic was altered; no migrations were added or changed.

## CI Changes

**NONE.** `.github/workflows/build_apk.yml` unchanged.

# Transaction Analysis

The return path runs inside `_db!.transaction(...)` in `returnInvoice` (`app_provider.dart:767`). Within that transaction, `restoreInventoryFromSnapshots` performs, per legacy line: a read of `product_ingredients`/`inventory`/`products`, then (per link) one `update inventory` + one `insert inventory_audit_log`, or (no links) one `insert inventory_audit_log` diagnostic row. Audit rows are written **before** the transaction commits; if any step throws, sqflite rolls back the whole transaction atomically — no partial audit row and no partial inventory change can persist. The same transactional discipline applies to the five safe-delete helpers in `database_helper.dart` (audit insert precedes the delete inside the same transaction, verified by the passing test "deleteIngredientSafe is atomic: audit row written inside the same transaction as the delete"). **The transaction/rollback model is correct; the two failures expose no transaction bug, no foreign-key bug, and no state corruption.**

# Regression Analysis

| Question | Answer |
|---|---|
| Did all 59 pre-Phase-4.1 tests still pass? | **YES** — exactly 59 non-Phase-4.1 tests show ✅ in the log (financial_calculator 29, recipe_snapshot 18, db_integration Groups A–J 11, cost_snapshot 1) |
| How many new tests were added? | **15** (74 total − 59 baseline) |
| How many new tests passed? | **13 / 15** |
| Are the failures confined to Phase 4.1 tests? | **YES** — both failing tests are in the "Phase 4.1 - destructive safety closure" group |
| Existing legacy restoration test (Group D) | ✅ PASS — "legacy invoice (NULL snapshot) falls back to the current recipe with a warning row" |

# Production Safety Assessment

**Production Bug Confirmed: NO.** Both deviations are expectation errors in newly written tests, verified by tracing each test through Fixture → Database setup → Provider → Repository/DatabaseHelper → Transaction → Production operation:

- **Test #1:** fixture and provider and transaction all behave as designed; the production diagnostic row (`note = 'LEGACY_FALLBACK_NO_RECIPE_LINKS'`, `action_type = 'sale_returned'`) is genuinely written and queryable. The test's `action_type = 'ingredient_deleted'` filter is the sole point of divergence.
- **Test #2:** fixture seeds `bread: 2.0` links; production restores them as documented; `Actual: 102.0` is the correct deterministic outcome. The expected value `100.0` is the divergent point.

No real data corruption exists, and no rollback/transaction anomaly is involved. The safety model verified as implemented: **safe-by-default** deletes (blocks with `SafeDeleteBlockedException` and impact detail), **explicit override** required for linked ingredient deletion, **transactional audit** rows written inside the same transaction as every mutation, **rollback** semantics inherited from sqflite transactions, and **legacy no-false-confidence** (every legacy line now always leaves a provable audit row, never silent).

# Recommended Fix (analysis only — not applied, freeze active)

The minimal, scope-correct correction is to align the two new test expectations with the documented production contract, without touching production code:

1. **Test #1:** change the `action_type` filter from `'ingredient_deleted'` to `'sale_returned'` (the action type the return path actually uses for all its audit rows). The `note`-content check remains the authoritative L-1 assertion.
2. **Test #2:** change the bread expectation from `100.0` to `102.0` (fixture recipe `bread: 2.0` × soldQty 1), or alternatively re-seed the legacy fixture to also deduct bread — the current fix targets the expectation because the fixture's bread = 100 intentionally models a device with full bread stock.

## Fix Scope

`test/db_integration_test.dart` only (2 lines). Zero production, schema, migration, fixture-infrastructure, or CI changes. This is a **SAFE TO FIX TEST** scope by the classification rubric provided.

# Final Verdict

**SAFE TO FIX TEST**

Files Modified = 0 · Database Modified = NO · Schema Modified = NO · Migrations Modified = NO · Tests Modified = NO · Production Logic Modified = NO · Commit = NO · Push = NO.

---

*Note (for the record, frozen observation): a subsequent CI run on commit `989de70` — triggered before this freeze — has already been reported by the pipeline as **conclusion: success, 74 tests passed, 0 analyze errors**, confirming that the test-expectation classification is correct. No action was taken in this investigation; that run is documented for completeness only.*
