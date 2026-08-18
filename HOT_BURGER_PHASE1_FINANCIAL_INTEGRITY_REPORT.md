# HOT BURGER — Phase 1: Financial Integrity Core — Final Report

**Date:** 2026-08-18
**Repository:** `thikryat57-oss/hot-burger-last` (branch `main`)
**Starting commit:** `a8a5ccf` → **Final commit:** `289b047`
**CI verification:** GitHub Actions Run `32158294505` — `flutter analyze` passed, Release APKs built successfully.

---

## 1. Objective

Phase 1 ("Financial Integrity Core") replaces the fragmented, duplicated financial arithmetic that existed across six report functions in `app_provider.dart` with a **single, pure-Dart calculation layer** (`lib/core/utils/financial_calculator.dart`). All sales, daily/monthly, BI, P&L, and top-products reporting surfaces now compute revenue, discount, COGS, and profit from the same code path, with defensive arithmetic (no silent NaN/Infinity), proportional discount allocation, and strict separation between snapshot-based COGS and legacy fallback COGS so that historical data is never silently rewritten.

## 2. Files Changed

| File | Action | Lines Changed |
|---|---|---|
| `lib/core/utils/financial_calculator.dart` | **New** | 457 lines |
| `lib/providers/app_provider.dart` | Modified (read paths only) | +93 / −55 |
| `test/financial_calculator_test.dart` | **New** | 340 lines, 16 tests |
| `pubspec.yaml` | Modified | +1 (dev_dependency `test`) |
| `HOT_BURGER_PHASE0_BASELINE.md` | Added | Phase 0 audit reference |

**Net change:** +962 / −55 across 5 files. Zero modifications to database schema, migrations, write operations, or UI screens.

## 3. The New Calculation Layer

`lib/core/utils/financial_calculator.dart` is framework-independent (no Flutter/sqflite dependency): all inputs arrive as plain `Map<String, dynamic>` rows from queries, and the layer performs all arithmetic.

| Component | Purpose |
|---|---|
| `FinancialLineItem` | Typed view of one `invoice_items` row; exposes `hasLegacyCost` when `cost_snapshot` is missing/zero. |
| `InvoiceFinancials` | Per-invoice view: net revenue, strict COGS, fallback COGS, discount allocations, `grossProfit`, `grossProfitWithFallback`. |
| `FinancialSummary` | Aggregated totals: gross sales, discount, net revenue, both COGS figures, both profit figures, expenses, payment splits, margin, invoice/item counts. |
| `allocateDiscount()` | **Proportional allocation** of the invoice discount across line items by their share of gross revenue, rounded to the cent with the last penny assigned to the largest line so allocations always sum **exactly** to the invoice discount. |
| `summarizeInvoices()` | Builds per-invoice financials from flat `invoice` + `invoice_items` rows; strict COGS from frozen `cost_snapshot`; legacy fallback reconstructs cost as `max(price − unitProfit, 0)` without re-running the recipe graph. |
| `aggregateSummary()` | Sums across invoices; all fields clamped (NaN/Infinity → 0). |
| `topProductsByDiscountedProfit()` | Per-product discounted profit = `qty × unitProfit − allocated_discount`, sorted descending. |

## 4. Formulas (now uniform across all reports)

> **Net revenue** = subtotal − discount
> **Gross profit (strict)** = net revenue − COGS (snapshot only)
> **Gross profit (with fallback)** = net revenue − COGS incl. legacy reconstructed cost
> **Discount allocation per item** = invoice_discount × (item_total ÷ sum_of_item_totals), last penny to largest item
> **Discounted item profit** = qty × unitProfit − allocated_discount

The stored `total_profit` / `unit_profit` columns remain the **gross (pre-discount)** values, exactly as captured at sale time. Discounted profit is always computed by this layer and never assumed equal to the stored value.

## 5. Report Functions Updated in `app_provider.dart`

| Function | What changed |
|---|---|
| `getDailyReport(date)` | Now queries joined invoice+item rows and delegates to `summarizeInvoices` + `aggregateSummary`; net sales = `total_amount` (after discount), gross + discount reported alongside. |
| `getMonthlyReport(year, month)` | Same delegation; expense share subtracted from strict and fallback profits separately. |
| `getBusinessIntelligence()` | BI KPIs (margin, avg invoice, top line) derived from the unified summary. |
| `getTopProductsByProfit()` | Now calls `topProductsByDiscountedProfit` (discounted profit ranking). |
| `getDashboardDailyNetSales()` | Net (post-discount) daily sales series. |
| `getProfitAndLossSummary()` | P&L rebuilt on `FinancialSummary` with `copyWith` for expenses. |

Only the **read/report** logic was modified. `createInvoice`, `recordPurchase`, all mutation flows, and all schema/migrations are untouched.

## 6. Test Results — 16/16 Passing

`test/financial_calculator_test.dart` covers:

- `FinancialLineItem` defensive clamping (negative quantity, NaN — 2 tests)
- `allocateDiscount` proportional allocation, exact-penny sum, zero/negative discount, discount clamped to gross, empty lines (5 tests)
- `summarizeInvoices`: unknown invoice_id ignored, legacy cost reconstruction from frozen `unit_profit`, snapshot COGS on both strict and fallback paths (3 tests)
- `aggregateSummary` / `FinancialSummary`: empty input, cross-invoice aggregation, NaN/Infinity clamping (3 tests)
- `topProductsByDiscountedProfit`: ranking + limit, **aggregate consistency** — the per-product discounted profits sum to the aggregate discounted profit (2 tests)

**Final result: 16/16 passed** (local Dart SDK runner), verified against the final committed source.

### Last-test fix detail

The failing test (`discounted profits across products approximate aggregate discounted profit`) compared the per-product discounted-profit sum against `aggregateSummary.grossProfitWithFallback` on a manually-constructed `InvoiceFinancials` whose `cogsWithFallback` field defaulted to 0 while its lines implied a fallback COGS of 10. The layer's aggregate logic was correct; the assertion compared against a wrong oracle. The test was corrected to (a) assert the mathematically exact sum of 80 and (b) build the fallback-COGS oracle the same way production does (`max(price − unitProfit, 0)` per line), which yields the identical 80.0 — confirming full consistency between the per-product and aggregate views.

## 7. CI — flutter analyze (GitHub Actions)

| Run | Result |
|---|---|
| `32157061791` | Analyze failed — test file used local sandbox import (`package:fintest/...`) |
| `32157290938` | Analyze failed — wrong package name (`package:hotburger/...`) |
| `32157770439` | **Analyze passed** (0 errors) |
| `32158294505` | **Passed** (0 errors, 6 warnings, all pre-existing outside this phase) |

**Final state: 0 errors, 227 infos, 6 warnings** — and the 6 remaining warnings are all **pre-existing** in files untouched by this phase (`backup_helper.dart`, `backup_screen.dart`, `profit_report_screen.dart`, `sales_screen.dart`, plus two local variables in report functions). `lib/core/utils/financial_calculator.dart` contributes **no warnings or errors** in the final run.

**Release APKs (Run `32158294505`):** built successfully — `release-apk` and `release-apk-raw` artifacts available at:
https://github.com/thikryat57-oss/hot-burger-last/actions/runs/32158294505

## 8. What Was NOT Changed (Deliberate Scope Boundaries)

1. **No schema changes** — no new tables, columns, indexes, or migrations; DB stays at version 15.
2. **No write-path changes** — `createInvoice`, `recordPurchase`, purchases, payments, loyalty writes are identical.
3. **No historical data rewriting** — legacy invoices keep their frozen `unit_profit`; the layer only *reconstructs* missing costs at query time and reports strict vs fallback COGS separately.
4. **No UI changes** — all screens untouched.
5. **Stored profit values unchanged** — `total_profit` / `unit_profit` remain gross; discounted profit is a computed reporting figure.

## 9. Outstanding / Next-Phase Notes

- The pre-existing analyzer warnings listed in §7 can be cleaned in a later maintenance pass (out of Phase 1 scope).
- `expensesRemainingUnits` existed as a leftover of an earlier expenses-allocation design; it was removed as dead code inside `summarizeInvoices` (its `expensesTotal` parameter is retained for future per-line expense allocation without breaking the API).
- The `test` package was added as a dev dependency to make `flutter analyze` validate `test/` (previously analysis stopped at missing URIs).

---
*Report prepared by Manus AI — Phase 1 Financial Integrity Core, HOT BURGER POS.*
