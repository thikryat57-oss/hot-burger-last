# Hot Burger Architecture

## 1. Scope and architectural summary

Hot Burger is an offline-first Flutter application for cafeteria point-of-sale operations. The application uses a single local SQLite database accessed through `sqflite`, a `ChangeNotifier`-based `AppProvider` for domain operations and shared state, and screen-level Flutter widgets for presentation and interaction. Arabic is the primary UI locale and the application-wide direction is RTL.

The runtime starts in `lib/main.dart`. The application initializes Flutter bindings, installs global Flutter and platform error handlers, opens the local database through `AppProvider.initDatabase()`, and then mounts `HotBurgerApp` with `ChangeNotifierProvider`. Authentication is the first screen. After a successful login, `HomeScreen` presents the operational tabs and keeps the provider as the primary source of truth for shared data.

> Architectural principle: the database is the durable source of truth; `AppProvider` is the application-service and notification layer; screens own transient form, filtering, loading, and layout state.

## 2. Functional modules and screens

| Module | Main screens | Responsibility |
|---|---|---|
| Authentication | `screens/auth/login_screen.dart` | Loads active users, validates the selected user and password through `AppProvider.login`, and enters the application after successful authentication. |
| Home/navigation | `screens/home/home_screen.dart` | Hosts the main application shell, tab selection, access-controlled navigation, and the persistent tab structure. |
| Sales/POS | `screens/sales/sales_screen.dart` | Loads available products, manages the cart, quantities, discounts, payment method, customer selection, pending orders, checkout confirmation, invoice creation, and post-sale refresh. |
| Dashboard | `screens/dashboard/dashboard_screen.dart` | Loads daily/monthly business indicators, sales totals, expenses, profit, low-stock information, and top-product summaries. |
| Invoices | `screens/invoices/invoices_screen.dart`, `invoice_detail_screen.dart` | Lists invoices, refreshes data when the tab becomes active, supports search/detail navigation, returns/voids where authorized, and renders printable invoice details. |
| Inventory | `screens/inventory/inventory_screen.dart`, `inventory_history_screen.dart` | Manages ingredients and quantities, low-stock state, stock adjustments, and the inventory audit trail. |
| Products and recipes | `screens/products/products_screen.dart`, `recipe_management_screen.dart` | Manages products/categories and product-to-ingredient recipe links, including recipe cost calculation. |
| Categories | `screens/categories/categories_screen.dart` | Creates, edits, deletes, and lists product categories. |
| Purchases | `screens/purchases/purchases_list_screen.dart`, `new_purchase_screen.dart` | Lists purchase invoices, creates purchase invoices, updates ingredient stock, and records supplier liabilities. |
| Suppliers | `screens/suppliers/suppliers_screen.dart`, `supplier_detail_screen.dart` | Manages suppliers, supplier balances, purchase history, ledger entries, and payments. |
| Customers and loyalty | `screens/customers/customers_screen.dart` | Manages customers, contact information, points, visit count, total spending, and customer purchase history. |
| Expenses | `screens/expenses/expenses_screen.dart` | Creates, edits, deletes, and lists operating expenses used by reports and shift cash reconciliation. |
| Users and permissions | `screens/users/user_management_screen.dart` | Manager-only user administration, password updates, and active/inactive account control. |
| Shifts | `screens/shifts/shift_management_screen.dart` | Opens and closes cashier shifts, calculates expected cash, and displays shift history. |
| Kitchen display | `screens/kitchen_display_screen.dart` | Displays completed invoices that have active kitchen states and advances them through `new → preparing → ready → delivered`. |
| Reports and analytics | `screens/reports/reports_screen.dart`, `profit_report_screen.dart`, `shift_report_screen.dart`, `analytics/business_intelligence_screen.dart` | Produces operational, profit/loss, shift, and business-intelligence summaries from invoice, expense, inventory, and shift data. |
| Backup | `screens/backup/backup_screen.dart`, `core/utils/backup_helper.dart` | Exports and imports the local SQLite database and related backup data. |
| More/administration | `screens/more/more_screen.dart` | Provides secondary navigation, settings-style actions, reports, backup, and administration tools. Temporary crash/status diagnostics are excluded from the release UI. |
| PDF rendering | `core/utils/pdf_helper.dart` | Generates receipts and inventory/shift reports using embedded Noto Arabic fonts and RTL directionality. |

## 3. State and navigation model

`AppProvider` extends `ChangeNotifier`. Authentication state is held in `_currentUser` and `_isLoggedIn`; tab selection is held in `_currentIndex`. CRUD and business operations generally write to SQLite first and then call `notifyListeners()` so dependent screens can refresh. Screens use a mixture of `context.select`, `Consumer`, and local `Future` caching. Tab-sensitive screens use an activity notifier pattern to refresh when the tab becomes active rather than on every dependency change.

Dialogs and sheets that return values must use the dialog context and the root navigator. When a dialog button awaits a provider operation that calls `notifyListeners()`, the route close is scheduled with `WidgetsBinding.instance.addPostFrameCallback` and guarded by `dialogContext.mounted`. This avoids closing a route while the provider-triggered rebuild is still applying.

## 4. SQLite database schema

The database is opened by `DatabaseHelper.database` with the version in `core/constants/constants.dart`. `PRAGMA foreign_keys = ON` is enabled in `onConfigure`. New databases run `_onCreate`, which creates the base schema and then invokes the versioned table/index helpers. Existing databases run `_onUpgrade` sequentially from their old version to the current version.

### Core tables

| Table | Key fields | Relationships and purpose |
|---|---|---|
| `users` | `id`, `name`, `password_hash`, `password_salt`, `is_active`, `role`, `created_at` | Authentication and authorization. Roles are manager/cashier. Legacy plaintext/hash columns remain for migration compatibility, while successful login upgrades credentials to salted hashes. |
| `categories` | `id`, `name`, `description`, `is_active`, timestamps | Product classification. `products.category_id` references it with `ON DELETE SET NULL`. |
| `products` | `id`, `name`, `category_id`, `price`, `cost`, availability, timestamps | Sellable catalog items. |
| `raw_materials` | `id`, `name`, `unit`, quantity/cost, supplier, notes, active flag, timestamps | Legacy raw-material table retained for backward compatibility. The active inventory model is `inventory`. |
| `inventory` | `id`, `name`, `quantity`, `unit`, `min_quantity`, `cost_price`, timestamps | Current ingredient stock and low-stock thresholds. |
| `product_ingredients` | `id`, `product_id`, `ingredient_id`, `quantity`, `created_at` | Recipe bridge between products and inventory. It has a unique `(product_id, ingredient_id)` constraint and cascading product/ingredient deletes. |
| `invoices` | `id`, unique `invoice_number`, totals, status, payment, kitchen status, customer, timestamps | Sales header. The unique invoice-number index prevents duplicate invoice identifiers. |
| `invoice_items` | `id`, `invoice_id`, `product_id`, snapshot name/price/quantity, cost/profit snapshots | Immutable sale-line snapshots. `invoice_id` cascades on invoice deletion. |
| `pending_orders` | `id`, customer name, discount, payment method, timestamps | Parked POS carts that do not affect inventory until completed. |
| `pending_order_items` | `id`, pending order, product snapshot, price, quantity, total | Parked-cart lines, cascading from `pending_orders`. |
| `expenses` | `id`, name, amount, date, notes, timestamps | Operating expenses used in reports and shift cash calculations. |

### Purchasing, supplier, loyalty, audit, kitchen, and shift tables

| Table | Key fields | Relationships and purpose |
|---|---|---|
| `suppliers` | `id`, contact fields, `balance`, timestamps | Supplier master data and outstanding balance. |
| `purchase_invoices` | `id`, `supplier_id`, invoice number, totals, paid amount, status, date | Purchase header. Supplier deletion is restricted. |
| `purchase_items` | `id`, `purchase_invoice_id`, `ingredient_id`, quantity, unit/total cost | Purchase lines; invoice deletion cascades, ingredient deletion is restricted. |
| `supplier_payments` | `id`, `supplier_id`, optional purchase invoice, amount, date | Supplier ledger payments. Supplier deletion cascades; invoice deletion sets the optional link to null. |
| `customers` | `id`, name/contact fields, points, total spent, visit count, active flag, timestamps | Loyalty customer master data. |
| `customer_points_log` | `id`, `customer_id`, optional invoice, points change, reason, timestamp | Auditable loyalty changes; customer deletion cascades and invoice deletion nulls the optional invoice link. |
| `inventory_audit_log` | `id`, action metadata, ingredient snapshot, before/change/after quantities, cost, reference | Central inventory movement history. |
| `invoice_audit_log` | `id`, invoice, action type/date, user, note | Financial action and kitchen/return/void audit trail. |
| `shifts` | `id`, user, open/close times, opening/expected/actual/difference cash, status | Cashier shift lifecycle and reconciliation. User deletion is restricted. |

### Important indexes

The schema includes indexes for invoice date/status/payment/customer/kitchen lookups, invoice item invoice/product lookups, expense dates, inventory low-stock scans, recipe product/ingredient lookups, pending-order timestamps, supplier/customer lookups, shift status/user lookups, audit-log foreign keys, and unique invoice numbers. The production-hardening migration adds indexes on customer phone, customer points invoice, invoice audit action, and `product_ingredients.ingredient_id`.

## 5. Database migrations

| Version transition | Migration |
|---|---|
| v1 → v2 | Creates `inventory` and `product_ingredients` if absent. |
| v2 → v3 | Adds invoice `payment_method`. |
| v3 → v4 | Creates supplier and purchase tables. |
| v4 → v5 | Adds invoice-item cost/profit snapshot columns. |
| v5 → v6 | Creates `inventory_audit_log`. |
| v6 → v7 | Adds reporting and POS indexes. |
| v7 → v8 | Creates `invoice_audit_log`, status/date index, and unique invoice number index. |
| v8 → v9 | Adds secure user-authentication columns, migrates legacy passwords, and creates shifts. |
| v9 → v10 | Adds subtotal/discount/paid/change invoice fields and backfills subtotal from total. |
| v10 → v11 | Creates parked-order tables and indexes. |
| v11 → v12 | Adds kitchen status and kitchen queue index. |
| v12 → v13 | Creates customers/loyalty tables, conditionally adds `invoices.customer_id`, and creates loyalty/customer indexes. |
| v13 → v14 | Adds password-salt security hardening and preserves compatibility with older hashes. |
| v14 → v15 | Adds production-hardening indexes, including the ingredient-side recipe index. |

The migration design is intended to support both clean database creation and sequential upgrades. Conditional `IF NOT EXISTS`/column checks are used in later helpers to reduce repeat-creation risk. A release QA pass should still test a fresh database and representative upgrade fixtures from prior versions because SQLite migrations are operationally critical.

## 6. Main business data flows

### Sale and inventory flow

The POS builds a transient `CartItem` list. Checkout creates an `Invoice` header and executes `AppProvider.createInvoice` inside a SQLite transaction. Within that transaction, the application inserts the invoice, inserts every invoice item with price/cost/profit snapshots, decrements inventory according to the product recipe, writes inventory audit entries, updates the customer and loyalty records when a customer is attached, and commits the transaction. After commit, provider state is notified and low-stock information is refreshed. Inventory is therefore changed only by a completed sale transaction, not by a parked order.

### Recipe cost flow

Each recipe link records the amount of an ingredient consumed per unit of product. `calculateProductCost` joins product ingredients to inventory cost prices and sums `recipe quantity × ingredient cost`. Product cost updates are then propagated to affected products when an ingredient cost changes. The ingredient-side recipe index supports this reverse lookup.

### Purchase and supplier flow

A purchase invoice is created with its item lines in a transaction. Ingredient quantities are increased and inventory audit entries are written. Supplier balance is derived from invoice totals, payments, and outstanding amounts. Supplier payments are recorded separately and linked to an optional purchase invoice for ledger reporting.

### Customer and loyalty flow

Customers are managed independently. During a completed sale, the customer’s total spending and visit count are updated and loyalty points are recorded in `customer_points_log`. Invoice/customer indexes support customer history and loyalty lookups.

### Shift, expense, and reporting flow

Opening a shift records the cashier and opening cash. Closing calculates expected cash from opening cash plus cash sales minus expenses, then stores actual cash and the difference. Reports aggregate invoices, invoice items, expenses, inventory, supplier, and shift data. Audit logs preserve financial and inventory changes for review.

### Kitchen flow

Completed invoices start with a kitchen status and are returned to the kitchen display while their status is `new`, `preparing`, or `ready`. Status transitions are validated, persisted transactionally with an invoice audit record, and exposed to the kitchen screen through provider queries.

## 7. Architectural constraints and assumptions

The application is offline-first and depends on the local SQLite file for normal operation. There is no remote synchronization layer in the current `lib` tree. The initial database creates one default manager account using a configured default password, while later successful logins upgrade legacy credentials to salted iterative hashes. Authorization is enforced in `AppProvider` for catalog, finance, user, and void operations.

The application is primarily a single-device POS. The provider owns one database handle and one current authenticated user in memory. SQLite foreign-key enforcement is enabled, but some historical tables intentionally retain denormalized snapshots such as product names, user names, and supplier balances to preserve report readability and historical values.

The application is Arabic-first and RTL. PDF output embeds Noto Arabic fonts and applies `pw.Directionality` at page/document content boundaries. UI layouts must account for narrow screens, variable Arabic text length, and keyboard/dialog route lifecycles.

## 8. Known operational risks for the regression and release audit

The highest-risk areas are route closure after provider notifications, stale data in screens retained by the home tab structure, variable-height cart/payment layouts, migration compatibility across all database versions, and transaction completeness for sales/purchases/returns/voids. The diagnostic build passed in CI before the temporary crash/status instrumentation was removed. The release workflow now runs clean analysis and split-per-ABI packaging in CI.

## 9. Verification scope

This document describes the implementation observed in the current `lib` tree. It is paired with the regression audit, provider/database review, and CI QA results produced during the current engineering pass. The final release artifact must be validated through the GitHub Actions workflow and on a real Android device before production distribution.
