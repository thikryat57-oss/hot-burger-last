# HOT BURGER — Phase 0 Baseline Audit Report

## 1. Project Identity & Architecture
- **Framework**: Flutter (3.24.0 verified in CI).
- **Core Library**: `pdf` (3.10.7), `sqflite`, `provider`, `path_provider`.
- **Database**: SQLite (v15 current version).
- **Architecture**: Provider-based State Management with a centralized `AppProvider`.
- **Primary Goal**: Point of Sale (POS) with inventory, kitchen, and financial management.

## 2. Database & Migrations (SQLite v15)
- **Initialization**: `DatabaseHelper` uses `singleInstance: true` and initializes before `runApp`.
- **Migration Logic**: `onUpgrade` handles versions v1 to v15 sequentially.
- **Table Count**: 23 tables (invoices, invoice_items, inventory, inventory_audit_log, users, categories, products, product_ingredients, expenses, suppliers, purchase_invoices, purchase_items, supplier_payments, customer_loyalty, etc.).
- **Risk Identified**: v4 migration uses direct `CREATE TABLE` without `IF NOT EXISTS`, posing a risk if the upgrade is interrupted. v5+ uses `IF NOT EXISTS`.

## 3. Core Business Flows
### A. Sales & Inventory (createInvoice)
- **Transaction**: Fully wrapped in `_db!.transaction`.
- **Stock Logic**: Deducts ingredients based on the *current* recipe at the time of sale.
- **Loyalty**: Adds points to customers and logs the change in `customer_points_log`.
- **Kitchen**: Creates orders with `kitchen_status: 'new'`.

### B. Returns & Voids (returnInvoice / voidInvoice)
- **Inventory Restoration**: Restores stock based on the *current* recipe.
- **Financials**: Updates invoice status to `returned` or `cancelled`.
- **Risk**: Financial reports (BI) filter out these statuses, but discrepancies exist in profit calculation.

### C. Purchases & Suppliers
- **Cost Calculation**: Uses Weighted Average Cost (WAC) for ingredients.
- **Supplier Ledger**: `insertPurchaseInvoice` and `insertSupplierPayment` update supplier balances within transactions.

## 4. Risk Assessment (Baseline Findings)
| Risk ID | Description | Status | Evidence |
|---|---|---|---|
| **A** | Async Pop Risk | **Partial** | Many dialogs fixed with `addPostFrameCallback`, but some confirmation dialogs still lack `useRootNavigator`. |
| **B** | context.mounted Safety | **Strong** | Widespread use of `if (mounted)` after async gaps. |
| **C** | BI Profit Discrepancy | **High** | BI ignores `discount_amount`; profit appears higher than actual. |
| **D** | Daily Report Profit | **High** | Daily report ignores COGS; profit is severely overstated. |
| **E** | Shift Detail Gap | **Medium** | Shift reports lack profit/COGS metrics. |
| **F** | Access Control | **Strong** | `isManager` role-based checks enforced for sensitive operations. |
| **I** | Stock Audit Gap | **Medium** | Manual stock edits via `updateIngredient` bypass the audit log. |
| **K** | Migration Safety | **Medium** | v4 migration lacks `IF NOT EXISTS`. |
| **M** | Rebuild Safety | **Strong** | `HomeScreen` uses `context.select`; `Dashboard` uses `activeListenable`. |
| **Q** | N+1 Queries | **Fixed** | `calculateProductCost` now uses JOIN for optimization. |

## 5. Security & Authentication
- **Hashing**: Salted SHA-256 for new users; legacy hashes (v9-v13) are auto-upgraded upon login.
- **Permissions**: Manager role required for catalog, finance, and user management.

## 6. Project Brief for LLM (ChatGPT)
When analyzing this project, focus on:
1. `lib/providers/app_provider.dart`: Central business logic and database interactions.
2. `lib/core/database/database_helper.dart`: Schema definition and migrations.
3. `lib/screens/sales/sales_screen.dart`: Primary UI for transactions.
4. `lib/core/utils/pdf_helper.dart`: Document generation (RTL fixed).

**Next Steps Recommended**:
- Standardize all `showDialog` to use `useRootNavigator: true`.
- Fix BI and Daily report profit formulas to include COGS and discounts.
- Add audit logging to manual stock adjustments in `DatabaseHelper`.
