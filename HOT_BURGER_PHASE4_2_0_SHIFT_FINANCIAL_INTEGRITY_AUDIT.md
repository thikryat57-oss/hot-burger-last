# HOT BURGER — Phase 4.2.0 Shift Financial Integrity Audit

**Project:** `thikryat57-oss/hot-burger-last` (branch `main`)
**Commit inspected:** `95ab4b2` (HEAD at audit time; last run `32250182309` completed successfully)
**Scope:** READ-ONLY audit of the Shift (وردية) module's financial integrity — Finding E reassessment, full data-flow trace, cross-report consistency, minimal-fix design only.
**Execution mode:** NO code edits, NO test edits, NO database edits, NO build, NO commit, NO push.
**Author:** Manus AI — **Date:** Aug 19, 2026

---

## 1. Executive Summary

This audit traced every number displayed anywhere the Shift module touches — the current-shift cash card on the Shift Management screen, the Close-Shift reconciliation dialog, the Shift Close Report screen (`تقرير تقفيل الوردية`), and its PDF export — from the SQLite query through the provider function to the widget. The same trace was performed in parallel for the other financial reports (Daily, Monthly, P&L, Top Products, BI, Dashboard) to establish whether a single source of financial truth exists.

The central, and confirming, conclusion is that **the Shift Report is the only report in the application that does not use the unified `financial_calculator.dart` pipeline.** It computes exactly four numbers — total sales (net of discount, without a discount line), cash/bank/card splits, and invoice count — via raw SQL, and shows nothing about discount, COGS, gross profit, net profit, expenses, or cash variance. The Close-Shift cash reconciliation works correctly by design (expected = opening cash + cash sales − expenses, persisted on close), but it is a cash-only, per-open-shift mechanism that is architecturally separate from the report screen.

**Finding E — "Shift Summary remains gross-only and does not reflect COGS/Profit fully" — is RE-ASSESSED and CONFIRMED as still open**, though its wording is now refined: the shift report is actually *net-of-discount* (not gross) in its total, but it remains *missing the entire financial layer*: no discount line, no COGS, no profit, no expenses, no variance. The gap is a **feature/completeness gap**, not a data-corruption bug: no number displayed anywhere is mathematically wrong; numbers that *should* be there simply are not.

## 2. Current Baseline

| Item | Status |
|---|---|
| Regression baseline (CI) | **74/74 tests PASS** — run `32250182309` completed 2026-08-19T11:57 (before this audit; no test or code changes were made during the audit, so the baseline remains `989de70`/`95ab4b2`) |
| `flutter analyze` | 0 errors (pre-existing warnings only) |
| `lib/` modifications during audit | **None** (Files Modified = 0 by design) |
| Database version | 16 (unchanged) |
| Shift table | created v8→v9 migration; indexes `(status, opened_at)`, `(user_id, opened_at)` |
| Phase 4.1 state | Safe-delete helpers + L-1 diagnostics merged and green (verified as pre-existing, untouched) |

## 3. Finding E Reassessment

The original Finding E stated that the Shift Summary is "gross-only and does not reflect COGS/Profit." This audit proves the reality is more precise:

1. **The total is not gross — it is net of discount.** `getShiftSummary` sums `total_amount`, which is the post-discount invoice total (`total_amount = subtotal_amount − discount_amount`, per `createInvoice` semantics). So the report already behaves *better* than "gross-only."
2. **But there is no discount line.** The screen and PDF show `إجمالي المبيعات` with no `grossSales`/`discountTotal` companion, so an operator cannot see whether a discount was given.
3. **The entire cost/profit layer is absent.** No COGS, gross profit, net profit, or expenses appear in the shift report (nor in the shift cash card — which intentionally shows only cash-reconciliation figures).
4. **There is no variance line in the report.** Variance (`difference`) exists only on the persisted shift row and is displayed on the history cards — not in the period report.

**Reassessment verdict:** Finding E stands, restated as: *"The Shift Report does not expose the discount, COGS, profit, expense, or variance layers — it is the only report outside the unified `financial_calculator` pipeline."* Severity: **P2 (Medium)** — no data corruption, but the shift operator/manager cannot verify period profitability or discount exposure from the shift screen, which undermines its purpose as a shift-closure decision aid.

## 4. Shift Architecture

The Shift module consists of five code surfaces, all in `lib/`:

| Surface | File (lines) | Role |
|---|---|---|
| Model | `models/models.dart` (700–735) | `Shift` class: id, userId, userName, openedAt, closedAt, openingCash, expectedCash, actualCash, difference, status, notes — **no sales/COGS/profit fields** |
| Lifecycle | `app_provider.dart` (129–205) | `getOpenShift`, `getCurrentUserOpenShift`, `openShift`, `getCurrentShiftCashSummary`, `closeShift`, `getShifts` |
| Report query | `app_provider.dart` (1163–1208) | `getShiftSummary` — raw SQL per payment method |
| Management UI | `screens/shifts/shift_management_screen.dart` (201 lines) | current-shift card (افتتاحي/مبيعات كاش/مصروفات/متوقع), close dialog, history |
| Report UI | `screens/reports/shift_report_screen.dart` (290 lines) | date-range selector + 4 cards (total, cash, bank, card) + PDF button |
| PDF | `pdf_helper.dart` (343–455) | `_buildShiftReport` — prints invoice count + total sales only |

The `shifts` table is a **cash-reconciliation ledger**, not a financial summary store: it persists only opening/expected/actual/difference cash figures. All period sales numbers are re-aggregated live from `invoices`/`invoice_items` on demand.

## 5. Shift Data Flow

Three distinct data paths exist, and they must not be conflated:

**Path A — Shift Management cash card & Close dialog** (`getCurrentShiftCashSummary`, line ~163):
```
invoices WHERE status NOT IN ('cancelled','returned') AND payment_method='cash' AND created_at >= shift.openedAt
expenses WHERE created_at >= shift.openedAt
expected = openingCash + cashSales − expenses
```
→ displayed as افتتاحي / مبيعات كاش / مصروفات / متوقع; persisted by `closeShift` as `expected_cash`, `actual_cash`, `difference`, `status='closed'`.

**Path B — Shift Period Report** (`getShiftSummary`, line 1163):
```
SELECT COALESCE(SUM(total_amount),0) FROM invoices
 WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')
```
→ repeated for `payment_method IN ('cash','bank','card')`, plus invoice count. This is the *only* output of the report screen and its PDF.

**Path C — Every other financial report** (Daily/Monthly/P&L/TopProductsByProfit/BI): all route through `summarizeInvoices()` → `aggregateSummary()` in `financial_calculator.dart`, which computes grossSales, discountTotal, netRevenue, cogs (cost_snapshot), cogsWithFallback (price − unit_profit reconstruction), grossProfit, and netProfit (after expenses).

The audit verified that `createInvoice` (lines ~622–653) freezes `cost_snapshot`, `unit_profit`, `total_profit`, and the full `recipe_snapshot` JSON **inside the same transaction** as the invoice insert, using `calculateProductCost(productId)` computed against the recipe graph at sale time. This is the immutable historical anchor used by Path C.

## 6. Gross Sales Analysis

Only Path C reports gross sales (`SUM(subtotal_amount)` aggregated as `agg.grossSales`). The Shift report (Path B) has **no gross figure**. There is no duplicate gross computation anywhere; the single implementation lives in `financial_calculator.dart`. No discrepancy found — only an absence.

## 7. Discount Analysis

Discount flows through Path C as `SUM(discount_amount)` (via `allocateDiscount` line-item allocation for per-product profit accuracy). Path B has no discount figure at all, and `totalSales` shown there is already discount-deducted, so a naive reader comparing "Shift total" against "P&L gross" would mis-attribute the difference to an error when it is actually the hidden discount. This is the concrete user-facing confusion caused by the gap: **P2, no data corruption.** The Phase 1.1 discount clamp (`discount ≤ gross`) and duplicate-productId allocation in `financial_calculator.dart` protect every Path C report; Path B is trivially unaffected because it never computes discounts (it only sums the post-discount total).

## 8. Net Sales Analysis

`getShiftSummary`'s `totalSales` = `SUM(total_amount)` = net of discount, same semantic as `agg.netRevenue` in Path C. Confirmed identical semantics for the overlapping invoices (both exclude `cancelled`/`returned`). The two will always agree on net sales for a matching date range — **CONSISTENT**. Note: Path B does not pass a status filter of `pending`-like rows because the only non-excluded statuses in practice are `completed`/`pending`; any `pending` invoice *is* included in the shift total (as is true in all Path C reports too — identical behavior).

## 9. COGS Analysis

The Shift module has **no COGS path at all** — neither in the report nor in the management card nor in close reconciliation. Path C computes COGS exclusively from the frozen `cost_snapshot` at sale time (with a deterministic fallback to `price − unit_profit` for pre-snapshot legacy rows), never from current recipe cost. Post-Phase 4.1, deleting an ingredient (blocked when linked, audited otherwise) or a product (safe-delete with audit) cannot alter historical `cost_snapshot` values, so historical COGS remains immutable. The Shift report's total-similarity to P&L net sales means the *revenue side* agrees, but *profitability* is invisible from the shift screen.

## 10. Profit Analysis

No profit computation exists anywhere in the Shift module. This is the core of the confirmed gap: the operator closing a shift sees cash reconciliation only and cannot see whether the period was profitable, what margin it carried, or how much discount was granted. The profit truth for any date range is uniquely computed by Path C and is internally consistent (same pipeline for Daily/Monthly/P&L/BI/TopProducts).

## 11. Return Analysis

`returnInvoice` (line 766) sets `status='returned'` inside an atomic transaction, restores inventory strictly from the historical `recipe_snapshot` (never current recipe), reverses loyalty points from the actual log, and writes an audit row. The shift filters (`status NOT IN ('cancelled','returned')`) exclude returned invoices from **all** reports including the Shift report — identical semantics everywhere. Because both paths share the filter, a return during a shift immediately reduces the shift total consistently with the daily total. No divergence. ✓

## 12. Void Analysis

`voidInvoice` (line 832) mirrors return semantics with `status='cancelled'`; `deleteInvoice` is aliased to `voidInvoice` (no physical delete). Same exclusion filter, same audit trail. Consistent across all reports. ✓

## 13. Shift Boundary Analysis

Two boundary models coexist: **calendar-date** (`DATE(created_at)` BETWEEN two user-picked dates) for the Shift Period Report, and **timestamp** (`created_at >= openedAt`) for the live open-shift card and close reconciliation. Consequences: (1) a shift crossing midnight (e.g., 23:00→02:00) is split across two report dates and cannot be reported as a single shift period by the report screen; (2) the live card correctly tracks one shift across midnight while open, but closes out that view on close; (3) the history cards show only timestamps, not sales. This is a **representational limitation (P3)**, not a calculation error.

## 14. Cash Reconciliation

Expected cash = opening + cash sales − expenses (cash-only, correct till logic: bank/card never enter the till). Verified against `closeShift` (line 177): the persisted `expected_cash`/`actual_cash`/`difference` are exactly the values the operator saw in the dialog moments before confirming — **no pre-close vs post-close divergence** for the displayed figures. One race-window exists: between reading the summary and the UPDATE in `closeShift`, a new cash invoice created by a second device/user is not reflected in the persisted expected value (the operator's own screen already showed the pre-race value, so the visible and persisted numbers still match; only the "true" expected value could drift). Likelihood low (single-operator POS), detectability medium, recoverability full (history row preserves both figures). Classified **P3**.

## 15. Payment Methods

The sales screen exposes exactly three methods — `cash` / `bank` (تحويل) / `card` — and `getShiftSummary` splits on exactly these three, so the shift report covers **100% of payment volume**. `financial_calculator`'s `transferTotal` slot is never populated (no `transfer` rows exist in production). `totalSales == cashTotal + bankTotal + cardTotal` holds by construction (no other methods). ✓

## 16. Expense Treatment

Expenses are a *reconciliation* item in Path A (deducted from expected cash) and a *profit* item in Path C (deducted from gross profit). Two filters are used: Path A uses `expenses.created_at >= openedAt` (auto timestamp), while Daily/Monthly/BI reports use the **user-editable** `expenses.date` column (the expenses screen defaults the manual date to today but allows picking another day). If a user back-dates an expense, the shift's expected cash at close will not reflect it while the daily/P&L reports will — a **semantic divergence risk (P3)**. Additionally, Path A includes expenses of *all users* during the shift, while the shift itself is per-user. Documented, not fixed (READ-ONLY).

## 17. Financial Calculator Consistency

| Component | Uses `financial_calculator`? |
|---|---|
| Shift Period Report (`getShiftSummary`) | **NO — raw SQL** |
| Shift close reconciliation (`getCurrentShiftCashSummary`) | **NO — by design (cash-only ledger math)** |
| Daily / Monthly report | YES — `summarizeInvoices` + `aggregateSummary` |
| P&L summary | YES — same pipeline + explicit COGS SQL (cost_snapshot with current-recipe fallback) |
| Top Products by Profit | YES — `topProductsByDiscountedProfit` (discount allocated pro rata) |
| Business Intelligence | YES — full pipeline for profit side; raw SQL for top-card splits |
| Dashboard | P&L + top products YES; daily sales chart raw SQL (net semantics, consistent) |

**Duplicate logic exists only between Path A (expected-cash math) and report math — and it is legitimate:** expected cash is inherently cash-reconciliation arithmetic (opening + inflow − outflow), not financial-statement arithmetic. The single-source-of-truth principle holds for every *financial-statement* number. **Duplicate-risk classification: P2 for the missing discount/COGS/profit view (Path B), P3 for Path A's expense-filter divergence — neither is a corruption risk.**

## 18. Cross-Report Consistency

Using the audit's canonical invoice (Gross 1000, Discount 100, Net 900, COGS 500):

| Report | Net Revenue | COGS | Profit | Verdict |
|---|---|---|---|---|
| Shift Period Report | shows 900 as "إجمالي المبيعات" (no label "net") | — | — | CONSISTENT on value, INCOMPLETE in disclosure |
| Daily / Monthly | 900 (`agg.netRevenue`) | 500 (`cogs`) | 400 (`netProfit`) | CONSISTENT |
| P&L | 900 | 500 (+ cogsFallback + grossProfitFromSnapshot) | 400 (+ margin) | CONSISTENT |
| BI | 900 | 500 | 400 (+ hourly) | CONSISTENT |
| Dashboard | 900 (net chart) | — | 400 (P&L card) | CONSISTENT |

All Path C reports derive from the same pipeline call and will always agree on the same date range. The only inconsistency is *presence*, not *value*.

## 19. Historical Cost Integrity

Verified: every invoice row carries `cost_snapshot`, `unit_profit`, `total_profit` (v4 migration), and Phase 2.1 added the full `recipe_snapshot` JSON (v16). Path C's `summarizeInvoices` uses `costSnapshot` when > 0 and reconstructs legacy cost deterministically from `(price − unitProfit)` — the comment at lines 291–295 of `financial_calculator.dart` explicitly forbids re-running the recipe graph against current prices. No path re-computes historical COGS from today's cost. ✓ Historical integrity is intact and was not affected by Phase 4.1's safe-delete changes (deletions audit and preserve; blocked when linked).

## 20. Recipe Snapshot Interaction

The Shift module does **not** need `recipe_snapshot` because it computes no cost figures. Its displayed numbers depend only on `invoices.total_amount` and `payment_method` (plus `created_at`). A recipe change after the fact therefore **cannot** affect any displayed shift number — not even indirectly — while a recipe change *can* affect Path C profit only for items whose `cost_snapshot` is 0 (fallback), and the fallback uses the frozen `unit_profit`, not the current recipe. **No mutable path from current recipe to any reported historical number exists.** ✓

## 21. Legacy Invoice Analysis

Legacy invoice_items rows (pre-snapshot) have `cost_snapshot = 0`. Path C handles them via the frozen `(price − unit_profit)` reconstruction; the Shift report is unaffected because it sums `total_amount` only. No silent omissions: legacy rows participate fully in every filter used by the shift module. ✓

## 22. Deleted Entity Impact

After Phase 4.1: `deleteIngredientSafe` blocks (with impact preview) or audit-deletes; `deleteProductSafe` removes rows with audit; expenses/ suppliers deletions are audited. Because all historical financial numbers are stored on `invoice_items` (cost/unit/total snapshots) and `invoices` (status/amounts), and because the shift module reads none of the deletable tables for its figures, **no deletion path can alter any historical shift or financial report number.** The only observable effect is the preserved audit trail. ✓

## 23. Shift Closure

Closure sequence verified end-to-end: Summary read → dialog shows expected/cash/expenses → operator enters actual → `closeShift` persists `expected_cash`, `actual_cash`, `difference`, `status='closed'` under `WHERE id = ? AND status = 'open'`. The persisted row is exactly what was displayed. The management history cards show persisted values (immutable). The period report re-aggregates live (mutable by later returns/voids — see §24). **No divergence between "summary before close" and "persisted shift values."** ✓

## 24. Immutability / Snapshot

The model is **mixed**: the closed shift *row* (cash reconciliation) is a frozen snapshot; the shift *period's sales figures* are dynamically re-aggregated whenever the report screen is opened. Since returns/voids have no undo path and themselves freeze state (`status='returned'/'cancelled'`), practical drift after close is bounded. Implication: reopening a shift period's report after a same-day return will show different totals than those visible at close time — an operator comparing the two should understand which source they are reading. Documented (P3 design note), no fix required.

## 25. Date/Time Analysis

All timestamps are stored as local-time ISO-8601 strings (`DateTime.now().toIso8601String()`), and all `DATE()`-based filters operate on those strings — internally consistent. There is **no UTC conversion anywhere**, so a device-timezone change mid-shift would misplace subsequent invoices into wrong dates/shifts. Risk: P3 (environmental). No midnight-special handling exists; `DATE()` correctly splits at 00:00 local time.

## 26. Financial Semantics Matrix

| Metric | Definition | Current Source | Formula | Uses FinCalc? | Uses cost_snapshot? | Discount-aware | Return-aware | Void-aware | Risk |
|---|---|---|---|---|---|---|---|---|---|
| Gross Sales | Sum of line totals before discount | `agg.grossSales` (FinCalc) | `SUM(subtotal_amount)` | YES | — | YES | YES (excluded) | YES (excluded) | Low |
| Discount | Sum of invoice discounts | `agg.discountTotal` | `SUM(discount_amount)` | YES | — | YES | YES | YES | Low |
| Net Sales | Revenue after discount | `agg.netRevenue` / shift `totalSales` | `SUM(total_amount)` | Shift: NO | — | Implicitly | YES | YES | Low (disclosure P2) |
| COGS | Cost of items sold | FinCalc `cogs`/`cogsWithFallback` | `SUM(q × cost_snapshot)` (+ fallback) | YES | YES | YES (allocated) | YES | YES | Low |
| Gross Profit | Net revenue − COGS | `agg.grossProfit` | `netRevenue − cogs` | YES | YES | YES | YES | YES | Low |
| Expenses | Period spend | `agg.expenses` / shift expected math | `SUM(amount)` | Path C: YES | — | — | — | — | P3 (date vs created_at) |
| Net Profit | Gross profit − expenses | `agg.netProfit` | `netRevenue − cogs − expenses` | YES | YES | YES | YES | YES | Low |
| Cash Sales | Cash-method sales | shift `cashTotal` / FinCalc split | `SUM(total_amount) WHERE method='cash'` | NO (raw SQL) | — | Implicitly | YES | YES | Low |
| Expected Cash | Till cash due | `getCurrentShiftCashSummary` | `opening + cashSales − expenses` | NO (by design) | — | — | YES | YES | P3 (expense filter, race) |
| Cash Variance | Actual − expected | persisted `difference` | `actual − expected` | NO | — | — | — | — | Low |

## 27. Cross-Report Matrix

| Metric | Shift Report | Daily/Monthly | BI | P&L | Dashboard |
|---|---|---|---|---|---|
| Gross Sales | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | NOT PRESENT |
| Discount | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT |
| Net Sales | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT |
| COGS | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | NOT PRESENT |
| Gross Profit | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT |
| Expenses | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT |
| Net Profit | NOT PRESENT | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT |
| Cash Sales | CONSISTENT | PARTIAL (chart-only) | CONSISTENT | NOT PRESENT | PARTIAL |
| Invoice Count | CONSISTENT | CONSISTENT | CONSISTENT | CONSISTENT | NOT PRESENT |

**Every metric that two reports both expose agrees in value; the only defects are absence (Shift report) and granularity (Dashboard chart).**

## 28. Findings

| ID | Severity | Description | Evidence | File / Function | Impact | Likelihood | Detectability | Recoverability | Recommendation |
|---|---|---|---|---|---|---|---|---|---|
| F-01 (Finding E, confirmed) | P2 | Shift Period Report exposes no discount/COGS/profit/expense/variance layer; only report outside the unified pipeline | `getShiftSummary` raw SQL (1163–1208); screen shows 4 cards; PDF prints 2 rows | `app_provider.dart:getShiftSummary`, `shift_report_screen.dart` | Operator cannot verify shift-period profitability or discount exposure | High (always) | High (visible absence) | N/A (no wrong data) | Phase 4.2.1: extend `getShiftSummary` to reuse `summarizeInvoices`+`aggregateSummary` with payment splits |
| F-02 | P3 | Shift expected cash filters expenses by `created_at`; all other reports filter by user-editable `date` | `getCurrentShiftCashSummary` vs `getDailyReport` | `app_provider.dart:163` vs `1098` | Back-dated expense invisible to shift close but visible in daily/P&L | Low | Medium | Full (both figures preserved) | Align both to the same expense date semantics |
| F-03 | P3 | Close-shift race: summary read and persist are not atomic with respect to new invoices | `closeShift` reads summary then updates | `app_provider.dart:177` | Expected value could drift from true till if another operator sells during close | Low (single-operator POS) | Medium | Full (history row shows both) | Re-read summary inside the close transaction |
| F-04 | P3 | Cross-midnight shifts cannot be reported as one period; report is calendar-date based | `DATE(created_at) BETWEEN` | `app_provider.dart:1163` | Shift spanning 2 days splits into 2 reports | Low | High | N/A | Optional: report-by-shift-id mode |
| F-05 | P3 | Device timezone change mid-shift misplaces invoices across dates/shifts | local-only ISO timestamps, no UTC handling | `createInvoice`, `getCurrentShiftCashSummary` | Wrong day/shift attribution | Low | Low | Full (data intact, mislabeled) | Store timezone or use UTC+local offset |

No new findings beyond F-01…F-05 were proven; absence of a feature was classified only where it affects financial verification (F-01) per the audit rule.

## 29. Priority Ranking

| Rank | Priority | Finding |
|---|---|---|
| 1 | P2 | F-01 — Shift report missing financial layer (Finding E) |
| 2 | P3 | F-02 — expense date semantic divergence |
| 3 | P3 | F-03 — close-shift race window |
| 4 | P3 | F-04 — cross-midnight reporting |
| 5 | P3 | F-05 — timezone handling |

There are **no P0 or P1 findings** in the Shift financial path. The shift cash ledger is internally correct, and every shared financial number across reports is value-identical.

## 30. Minimal Fix Design

Principle: **Single Source of Financial Truth = `financial_calculator.dart`.**

For F-01 (the only P2), the minimal fix is confined to one provider function and one screen:

1. `getShiftSummary` keeps its three method-split queries (they are already correct and cheap) and **adds** a single call to `summarizeInvoices` + `aggregateSummary` over the same date range (the exact same SQL already used by Daily/Monthly), returning the existing keys **plus**: `grossSales`, `discountTotal`, `cogs`, `grossProfit`, `expenses`, `netProfit`. No new tables, no migration, no schema change.
2. `shift_report_screen.dart` adds labeled cards for the new fields (discount, COGS, gross profit, net profit) — UI-only additions, no layout rework required beyond the existing card pattern.
3. `pdf_helper.dart:_buildShiftReport` appends the same rows (2-line addition).
4. F-02/F-03 (P3) can ride the same Phase 4.2.1 with one-line changes: filter expenses by `date` in `getCurrentShiftCashSummary`, and re-run the summary query inside `closeShift`'s transaction.

Estimated scope: ~3 provider functions, 1 screen, 1 PDF builder — no architecture rewrite, no refactor of financial_calculator.

## 31. Required Future Tests (Phase 4.2.1)

| # | Test | Type |
|---|---|---|
| 1 | Shift summary with normal invoice matches P&L net revenue | SQLite integration |
| 2 | Shift summary with discount shows correct discount + net | SQLite integration |
| 3 | Shift summary COGS = cost_snapshot values (via financial_calculator path) | SQLite integration |
| 4 | Shift summary after return excludes returned invoice | SQLite integration |
| 5 | Shift summary after void excludes cancelled invoice | SQLite integration |
| 6 | Shift crossing midnight: live card vs date-based report divergence documented/checked | SQLite integration |
| 7 | Shift with expenses: expected cash = opening + cash − expenses | SQLite integration |
| 8 | Shift cash reconciliation: persisted difference = actual − expected | SQLite integration |
| 9 | Shift after recipe change: profit unchanged (snapshot-backed) | SQLite integration |
| 10 | Shift with legacy invoice: totals consistent, COGS fallback deterministic | SQLite integration |
| 11 | Shift after product deletion: historical numbers unchanged | SQLite integration |
| 12 | Shift after ingredient deletion: historical numbers unchanged, blocked-if-linked honored | SQLite integration |
| 13 | Closed shift immutability: re-aggregation after post-close return changes report but not shift row | SQLite integration |
| 14 | Cross-report consistency: identical date range yields identical net/COGS/profit across Shift-Daily-P&L-BI | SQLite integration |

All 14 are best served as **SQLite integration tests** (they require live queries against the invoice/expense graph); `financial_calculator` edge cases (discount clamp, duplicate productId) are already covered by the 29 existing unit tests and need not be re-tested.

## 32. Remaining Risks

Post-Phase 4.1, the residual risk surface is: (1) the P2 disclosure gap (F-01) — the only financially material gap; (2) three P3 operational risks (expense-filter divergence, close race, timezone) that cannot corrupt data but can confuse reconciliation; (3) the representational limit of calendar-date shift reporting. No data-integrity risk remains in the shift path: returns/voids are atomic with inventory and loyalty reversal, deletions are audited and snapshot-anchored, and all historical figures are frozen at sale time.

## 33. Recommended Phase 4.2.1 Scope

Implement F-01 (shift report on the unified pipeline + disclosure cards + PDF rows) as the headline item; fold F-02/F-03 (one-line expense-filter alignment and in-transaction summary re-read) into the same phase as zero-risk hygiene; defer F-04/F-05 to a later phase unless cross-midnight shifts are actively used. Add the 14 integration tests of §31. No schema change, no migration, no modification of `financial_calculator.dart`.

## 34. Files Inspected

| File | Lines / Scope |
|---|---|
| `lib/models/models.dart` | 700–735 (Shift model), 357–390 (Expense model), 248–285 (Invoice model) |
| `lib/providers/app_provider.dart` | 129–205 (shift lifecycle), 615–660 (createInvoice snapshots), 766–900 (return/void), 1059–1095 (expenses), 1098–1160 (Daily/Monthly), 1163–1210 (getShiftSummary), 1216–1280 (P&L), 1282–1320 (Dashboard), 1309–1360 (TopProducts/ExpenseSummary), 1362–1410+ (BI) |
| `lib/core/utils/financial_calculator.dart` | 31–125 (line item / invoice / summary models), 214–265 (allocateDiscount), 268–340 (summarizeInvoices), 342–380 (aggregateSummary), 382+ (topProducts) |
| `lib/core/database/database_helper.dart` | 162–225 (invoice_items/expenses schema), 344–348 (v5 cost_snapshot migration), 515–532 (shifts schema), 1120–1170 (safe deletes, Phase 4.1) |
| `lib/screens/shifts/shift_management_screen.dart` | full (201 lines) |
| `lib/screens/reports/shift_report_screen.dart` | full (290 lines) |
| `lib/screens/reports/reports_screen.dart` | 43–55 (Daily/Monthly wiring) |
| `lib/screens/reports/profit_report_screen.dart` | 54 (P&L wiring) |
| `lib/screens/dashboard/dashboard_screen.dart` | 108–111 (today dashboard queries) |
| `lib/screens/expenses/expenses_screen.dart` | 39–190 (expense date controllers) |
| `lib/screens/sales/sales_screen.dart` | 836–840 (payment chips), 496/210–215 (payment handling) |
| `lib/core/utils/pdf_helper.dart` | 343–455 (`_buildShiftReport`) |

## 35. Final Verdict

**B — SHIFT FINANCIAL INTEGRITY VERIFIED WITH MINOR GAPS**

The shift module computes no wrong number; every financial number that exists is value-consistent with all other reports (single unified pipeline, frozen historical costs, atomic return/void handling, audited deletions). The gaps are **disclosure and reconciliation hygiene**, headed by the confirmed Finding E (the Shift Period Report is the only report outside `financial_calculator`, exposing neither discount nor cost nor profit nor variance). Recommended action: Phase 4.2.1 per §33.

---

**PHASE 4.2.0 STATUS:**
PASS — READ-ONLY AUDIT COMPLETE

Files Modified = 0
Production Code Modified = NO
Database Modified = NO
Schema Modified = NO
Migrations Modified = NO
Tests Added = NO
Tests Modified = NO
CI Modified = NO
Commit = NO
Push = NO
