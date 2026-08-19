# HOT BURGER — Phase 4.2.1 Failure Investigation

**Report Type:** READ-ONLY Failure Investigation (NO FIX)
**Date:** 2026-08-19 (GMT+2)
**Investigated CI Run:** `32252411608` (commit `adc2a4c`, repository `thikryat57-oss/hot-burger-last`, branch `main`)
**Baseline Commit (pre-Phase-4.2.1):** `95ab4b2`
**Author:** Manus AI

---

# Executive Summary

Four tests failed in CI run `32252411608` with the summary `84 tests passed, 4 failed` and `exit code 1`. All four failures belong to the **new** test group `Phase 4.2.1 - shift financial disclosure`, which was added during Phase 4.2.1 itself. No pre-existing test failed: the other 84 tests (including the entire 74-test baseline from before Phase 4.2.1) all passed, and every test outside the new group in that run shows a green result in the run log.

The failures are not caused by any defect in the production financial logic. The four failing tests passed fixture data that the production layer **rightly rejects before reaching any financial arithmetic**: two of them requested more beef than exists in the seeded inventory (4,000 and 2,000 units required against 1,000 stocked), and the other two supplied a discount that exceeds the invoice subtotal (999.0 and 50.0 against a 25.0 subtotal), which `createInvoice` validates and rejects as invalid. The failure is therefore a mismatch between the **test fixtures/expectations** and the **documented, intentional validation semantics** of production — a classic fixture-level test bug, not a production bug, not a regression, and not a financial integrity failure.

It is also worth recording, for the history of this investigation, that the very first Phase 4.2.1 CI run (`32251730732` on `7abe9fb`) contained **15 `flutter analyze` errors** arising because the new tests called `createInvoice` with a single argument while the production signature requires two (`Invoice`, `List<CartItem>`). That was fixed in `adc2a4c`; the four failures documented here are the only remaining failures on the subsequent run.

| Criterion | Result |
|---|---|
| Tests added in Phase 4.2.1 | 14 (all four failures come from this group) |
| Pre-existing baseline tests failing | **0 of 74** |
| New tests passing | 10 of 14 (TEST 1, 3, 4, 5, 6, 7, 10, 11, 12, 13) |
| Production files changed outside `getShiftSummary` extension | None of consequence |
| `financial_calculator.dart` changed | **No** |
| Real financial failure in the Shift | **No** |
| Classification of each failure | **C (Fixture/Seed Bug) — a subclass of Test Bug** |

---

# Exact Four Failures

All four failures were recorded in the `Run unit tests` step of run `32252411608` (2026-08-19 12:24 UTC). Their exact names in the run log are:

| # | Exact test name (from CI log) | Group | Result |
|---|---|---|---|
| 1 | `Phase 4.2.1 - shift financial disclosure TEST 2 — invoice with discount uses the centralized calculator semantics` | Phase 4.2.1 (new) | failed |
| 2 | `Phase 4.2.1 - shift financial disclosure TEST 8 — repeated productId in one invoice keeps discount allocation correct` | Phase 4.2.1 (new) | failed |
| 3 | `Phase 4.2.1 - shift financial disclosure TEST 9 — discount greater than gross cannot make net revenue negative` | Phase 4.2.1 (new) | failed |
| 4 | `Phase 4.2.1 - shift financial disclosure TEST 14 — shift consumes the centralized calculator (no duplicate engine)` | Phase 4.2.1 (new) | failed |

Every other test of the new group passed, and no test from any previous group failed: `TEST 1`, `TEST 3`, `TEST 4`, `TEST 5`, `TEST 6`, `TEST 7`, `TEST 10`, `TEST 11`, `TEST 12`, and `TEST 13` are all marked with the run's success marker (✅), as is every pre-existing test (84 passed in total).

---

# Full Error Evidence

The exact error output recorded by the runner for each failure is quoted below, verbatim from the run log.

**TEST 2:**

```
Exception: المادة الخام "beef" غير كافية لإتمام الطلب (متوفر: 1000.0، مطلوب: 4000.0)
package:hot_burger_last/providers/app_provider.dart 620:36  AppProvider.createInvoice
```

**TEST 8:**

```
Exception: المادة الخام "beef" غير كافية لإتمام الطلب (متوفر: 1000.0، مطلوب: 2000.0)
package:hot_burger_last/providers/app_provider.dart 620:36  AppProvider.createInvoice
```

**TEST 9:**

```
Exception: قيمة الخصم غير صالحة
package:hot_burger_last/providers/app_provider.dart 561:7  AppProvider.createInvoice
```

**TEST 14:**

```
Exception: قيمة الخصم غير صالحة
package:hot_burger_last/providers/app_provider.dart 561:7  AppProvider.createInvoice
```

---

# Stack Traces

The run log records the first useful stack frame for each failure. Because the exceptions are thrown synchronously inside `createInvoice`'s own validation loop, the one-line stack trace identifies the failure site completely.

| Failure | First useful stack trace (verbatim from log) | Meaning |
|---|---|---|
| TEST 2 | `package:hot_burger_last/providers/app_provider.dart 620:36  AppProvider.createInvoice` | Inventory sufficiency check rejected 4,000 beef units required against 1,000 stocked. |
| TEST 8 | `package:hot_burger_last/providers/app_provider.dart 620:36  AppProvider.createInvoice` | Inventory sufficiency check rejected 2,000 beef units required against 1,000 stocked. |
| TEST 9 | `package:hot_burger_last/providers/app_provider.dart 561:7  AppProvider.createInvoice` | Discount validation rejected a discount (999.0) exceeding the subtotal (25.0). |
| TEST 14 | `package:hot_burger_last/providers/app_provider.dart 561:7  AppProvider.createInvoice` | Discount validation rejected a discount (50.0) exceeding the subtotal (25.0). |

The production code at those lines (verified in the current working tree, READ-ONLY) is:

> `lib/providers/app_provider.dart`, lines 616–620:
> ```dart
>     for (final entry in requiredIngredients.entries) {
>       final stock = await DatabaseHelper.getIngredientById(entry.key);
>       if (stock.isEmpty) throw Exception('المادة الخام "...’ غير موجودة في المخزون');
>       final available = (stock.first['quantity'] as num).toDouble();
>       if (available < entry.value) throw Exception('المادة الخام "...’ غير كافية لإتمام الطلب (متوفر: $available، مطلوب: ${entry.value})');
>     }
> ```
> `lib/providers/app_provider.dart`, lines 559–561:
> ```dart
>     if (invoice.discountAmount < -epsilon ||
>         invoice.discountAmount - invoice.subtotalAmount > epsilon) {
>       throw Exception('قيمة الخصم غير صالحة');
>     }
> ```

---

# Test Origin

All four failing tests were **added during Phase 4.2.1** as part of the new group `Phase 4.2.1 - shift financial disclosure` in `test/db_integration_test.dart`. None of them existed before Phase 4.2.1. The group contains 14 tests in total (TEST 1–14), of which 10 passed. The pre-existing 74 tests (Groups A–J, Phase 2.1 recipe-snapshot, cost-snapshot, and Phase 4.1 destructive-safety groups) all passed in this run, confirming zero regression among established tests.

---

# Production Diff

The production diff of Phase 4.2.1 is bounded by `95ab4b2..94c565f` (the three Phase 4.2.1 commits):

```
 lib/core/utils/pdf_helper.dart               |  28 +++-
 lib/providers/app_provider.dart              |  44 ++++++
 lib/screens/reports/shift_report_screen.dart |  53 +++++++
 test/db_integration_test.dart                | 205 ++++++++++++++++++++++++++-
 4 files changed, 327 insertions(+), 3 deletions(-)
```

The only substantive production change is an **additive, read-side extension** of `getShiftSummary` in `lib/providers/app_provider.dart` (44 lines added, 0 removed). It queries `invoices`/`invoice_items` with the same period and status filters used previously, calls the shared `summarizeInvoices`/`aggregateSummary` from `financial_calculator.dart`, and computes COGS with the identical historical SQL semantics used by the P&L query. It then adds five new keys (`grossSales`, `discountTotal`, `cogs`, `grossProfit`, `grossProfitFromSnapshot`) to the returned map without altering any existing key (`totalSales`, `cashTotal`, `bankTotal`, `cardTotal`, `invoiceCount`).

The remaining production changes are display-layer only: three disclosure rows and one renamed label in `_buildShiftReport` (`pdf_helper.dart`, 28 additions, 1 label change), and a disclosure card with a helper widget in `shift_report_screen.dart` (53 additions, 0 removals).

---

# Test Diff

The test diff adds 14 new tests (189–205 lines) at the end of `test/db_integration_test.dart`. The failing fixtures at the time of failure (commit `adc2a4c`) were:

| Test | Fixture that caused failure | Production gate hit |
|---|---|---|
| TEST 2 | **40 Burgers × 25.0** = 4,000 beef required (`40 × 100 beef/unit` per fixture recipe) | Stock gate: 1,000 beef stocked (line 620) |
| TEST 8 | **20 Burgers** (2 line items × 10 units) = 2,000 beef required | Stock gate: 1,000 beef stocked (line 620) |
| TEST 9 | 1 Burger × 25.0 with **discount 999.0 > subtotal 25.0** | Discount validation (line 561) |
| TEST 14 | 1 Burger × 25.0 with **discount 50.0 > subtotal 25.0** | Discount validation (line 561) |

---

# Root Cause Analysis

**TEST 2 and TEST 8** assumed `createInvoice` would accept any quantity and let the financial layer compute the summary. Production, however, validates ingredient sufficiency **before** writing anything: each Burger consumes 100 units of beef (fixture recipe `{bread: 2.0, beef: 100.0}` at `test/db_integration_test.dart:50`), so 40 and 20 Burgers require 4,000 and 2,000 beef units respectively, against 1,000 stocked. The thrown exception is the documented, intentional behavior of the stock gate — the test fixture was simply too large for the seeded inventory. The financial assertions the tests intended to make are still reachable with smaller quantities (as TEST 1 and TEST 7, which use 1–5 Burgers, demonstrate by passing).

**TEST 9 and TEST 14** assumed production would accept a discount larger than the subtotal and clamp the net revenue to zero. Production instead treats `discount > subtotal` as **invalid input** and throws `'قيمة الخصم غير صالحة'` at the validation gate (line 561), before any financial computation occurs. The clamping to non-negative net revenue happens on *valid* inputs (via `clamp(0, double.infinity)` on the expected total at line 564), and the correct test for the non-negativity property therefore uses the maximum *legal* discount (discount = subtotal), not an illegal one. The tests' premises were therefore incompatible with the actual, documented validation contract.

In both cases the root cause is that the tests encoded **expected behaviors of a looser hypothetical engine** rather than the **actual validated contract** of the existing production paths they were designed to exercise.

---

# Regression Analysis

A regression is defined as a previously passing test now failing, or previously correct production behavior now incorrect. The regression analysis yields a clean negative result on both counts:

1. **Test-level:** all 74 pre-Phase-4.2.1 tests pass on this run, and every non-new test visible in the run log is green. The four failures are exclusively from tests that did not exist before this phase.
2. **Production-level:** `financial_calculator.dart` — the single source of financial truth mandated by the phase scope — is **unchanged** (`git diff 95ab4b2..94c565f -- lib/core/utils/financial_calculator.dart` is empty). No migration, schema, return/void, inventory, or database path was modified. The new `getShiftSummary` logic is additive and reads from the same frozen `cost_snapshot`/`recipe_snapshot` records used by the P&L layer.
3. **Financial-level:** the tests that probe the actual financial flow (TEST 1 gross/discount/net/COGS/profit, TEST 3 historical COGS under cost change, TEST 4 historical COGS under recipe change, TEST 5/6 return-and-void exclusion, TEST 7 aggregation, TEST 11 legacy fallback, TEST 12 payment breakdown regression, TEST 13 shift-vs-P&L equality) **all pass**. No real financial failure in the Shift was observed or could have been caused by the change.

---

# Financial Integrity Impact

**None.** The four failures are thrown *before* any row is written to `invoices` or `invoice_items`, and before any summary computation runs — the transactions never begin. The passing tests in the same run independently confirm that gross sales, discount totals, net revenue, historical COGS, gross profit, payment-method breakdown, legacy fallback, and return/void exclusion semantics are all correct for the Shift report and equal to the centralized P&L semantics for the same period.

---

# Scope Violation Check

| Scope rule | Compliance |
|---|---|
| Reuse `financial_calculator.dart`; no duplicate engine | Compliant — `getShiftSummary` consumes `summarizeInvoices`/`aggregateSummary`; TEST 13 proves equality with the P&L path |
| No changes to `financial_calculator.dart` | Compliant — file unchanged |
| No changes to `createInvoice`/`returnInvoice`/`voidInvoice` | Compliant — no changes to those paths |
| No schema/migration/historical-data changes | Compliant — diff contains no DDL or migration edits |
| No changes to other reports (Daily/Monthly/BI/P&L/Dashboard) | Compliant — only `shift_report_screen.dart` and the shift section of `pdf_helper.dart` changed |
| `flutter analyze` = 0 errors (Phase 4.2.1 run) | The *first* run had 15 analyzer errors (fixed in `adc2a4c`); the investigated run `32252411608` shows **0 errors** (`250 issues found` — all info/warning, as in all prior green runs) |
| Release APK | Built successfully in the phase's CI runs (the investigated run's build step completed; see run summary) |

The single pre-existing gap carried over from the earlier failure-investigation precedent (Phase 4.1) applies here as well: the `legacy fallback NO links` finding from Phase 4.1 was reconfirmed as settled; nothing in this phase reopens it.

---

# Classification of Each Failure

| Failure | A Production Bug | B Test Bug | C Fixture/Seed Bug | D Infrastructure | E Regression | F Unrelated | Classification |
|---|---|---|---|---|---|---|---|
| TEST 2 (stock: need 4,000 beef, have 1,000) | No | Yes | **Yes** | No | No | No | **C (Fixture/Seed)** |
| TEST 8 (stock: need 2,000 beef, have 1,000) | No | Yes | **Yes** | No | No | No | **C (Fixture/Seed)** |
| TEST 9 (discount 999 > subtotal 25 rejected as invalid) | No | Yes | **Yes** | No | No | No | **C (Fixture/Seed)** |
| TEST 14 (discount 50 > subtotal 25 rejected as invalid) | No | Yes | **Yes** | No | No | No | **C (Fixture/Seed)** |

All four failures are fixture/seed bugs — a subclass of test bugs — where the fixture data violated production's documented, intentional validation gates. The production gates themselves behaved correctly.

---

# Recommended Fix

The fix is confined to `test/db_integration_test.dart` only (test-scoped, per the phase rules — no production changes are needed or permitted):

1. **TEST 2:** reduce the quantity so required beef fits the 1,000-unit stock (e.g., 1 Burger at a higher unit price preserves the gross/discount semantics while requiring only 100 beef units).
2. **TEST 8:** halve the repeated line-item quantities (5 + 5 units = 1,000 beef exactly) and adjust the expected aggregates accordingly.
3. **TEST 9:** use the maximum *legal* discount (25.0 = subtotal) and assert the clamped net-revenue non-negativity (`totalSales = 0`, `grossSales = 25`, `discountTotal = 25`, `grossProfit = −102`).
4. **TEST 14:** same correction as TEST 9, since the underlying validation contract is identical.

No test should be deleted, skipped, or bypassed; the corrected fixtures exercise the same financial semantics (discount allocation, historical COGS, centralized-clamp propagation) that the original tests intended.

---

# STOP Decision

Per the READ-ONLY / NO FIX directive, **nothing has been modified**. No production file, test file, database, schema, migration, or CI configuration was touched during this investigation, and no commit or push was made. The investigation is complete and the evidence is fully documented above. Awaiting user instruction on how to proceed (per the recommended fix, or a different direction).

---

Production Modified = **NO**
Tests Modified = **NO**
Database Modified = **NO**
Schema Modified = **NO**
Migrations Modified = **NO**
CI Modified = **NO**
Commit = **NO**
Push = **NO**

**FINAL VERDICT:** **TEST BUG** (subclass: Fixture/Seed Bug — **C**)

**STOP.**
