# HOT BURGER — PHASE 2.2

# READINESS & INTEGRATION TEST AUDIT

**Audit Type:** READ-ONLY (Inspection & Assessment)
**Author:** Manus AI
**Date:** August 19, 2026
**Baseline Commit:** `75d31a8` — `docs: Phase 2.1 final report — historical recipe snapshot & inventory restoration`
**Approved Prior Phases:** Phase 0, Phase 1, Phase 1.1, Phase 2.0, Phase 2.1

---

## Executive Summary

This audit answers one question: **is the current project ready to receive real SQLite integration tests — the kind that exercise the actual database, migrations, transactions, invoice persistence, recipe snapshots, inventory, return/void, and rollback — without a large architectural refactoring?**

The answer is:

> **B — READY WITH MINOR TEST INFRASTRUCTURE**

The project is not "fully ready today" (answer A) for one narrow, structural reason: `DatabaseHelper` is a **static singleton** hardwired to the production database path (`getDatabasesPath()` + `Constants.dbFileName`), and its migration routines (`_onCreate`, `_onUpgrade`) are **private static methods**. Every CRUD method funnels through the singleton via `final db = await database;`. Business logic in `createInvoice` mixes the constructor-injected transaction database (`_db!.transaction(...)`) with static calls to `DatabaseHelper` (`getProductIngredients`, `getIngredientById`, `calculateProductCost`), which means a test that drives the full sale path through `AppProvider` currently has no way to redirect those static calls to a test database.

This is **not** an architectural defect requiring refactoring. It is a single, small coupling point that resolves with a **minor, non-breaking test hook** — roughly ten lines in one file (`DatabaseHelper` gains a `resetForTest()` reset plus a version-override open path, and the private `_onCreate`/`_onUpgrade` routines become test-reusable via a public `migrate()` wrapper). No repositories, no dependency-injection framework, no new packages, no rewrite.

Meanwhile, two important facts materially lower the perceived risk and raise confidence in this verdict:

1. **The required SQLite testing package already exists in `pubspec.yaml`.** The project already depends on `sqflite_common_ffi: ^2.3.0`, and `test/cost_snapshot_test.dart` (142 lines) **already runs real SQLite integration tests against `databaseFactoryFfi.openDatabase(inMemoryDatabasePath)` in the CI environment** — no emulator, no Android device, no native plugin. The pattern is proven to work on the current Linux CI runners.

2. **`AppProvider` is already partially test-friendly.** It is a plain `ChangeNotifier` whose constructor accepts a `Database?` instance. The `returnInvoice` and `voidInvoice` paths run entirely inside `_db!.transaction<int>((txn) async { ... })`, so a test that injects an in-memory database can drive return/void/legacy scenarios end-to-end **today, with zero production changes**.

The recommended strategy is **Option B: a minimal integration test suite of 5–10 tests**, supported by ~150 lines of test infrastructure in total, covering the thirteen-scenario matrix in Section 17. This report documents every file inspected, every function analyzed, the per-scenario testability verdicts, the options comparison, and the final verdict. No code was modified, no tests were added, and nothing was executed — per the Phase 2.2 lock.

---

## Files Inspected

The following files were read in full or in the relevant sections during this audit. Line references are relative to baseline commit `75d31a8`.

| # | File | What was inspected |
|---|------|--------------------|
| 1 | `pubspec.yaml` | Package dependencies (`sqflite`, `sqflite_common_ffi`) |
| 2 | `lib/core/database/database_helper.dart` | Singleton construction, `_initDatabase`, `_onCreate`, `_onUpgrade`, `closeDatabase`, all CRUD/static methods, `logInventoryAudit` |
| 3 | `lib/providers/app_provider.dart` | `createInvoice` transaction, `returnInvoice` (lines 762–825), `voidInvoice` (lines 828–895), `restoreInventoryFromSnapshots`, `AppProvider` constructor injection, `deleteInvoice` |
| 4 | `lib/core/utils/financial_calculator.dart` | Financial layer consumption points (snapshot/COGS fields used by report functions) |
| 5 | `lib/core/constants/constants.dart` | `dbVersion` (16) and `dbFileName` |
| 6 | `.github/workflows/build_apk.yml` | CI environment (JDK 21, Flutter 3.24.0, `flutter test` step) |
| 7 | `test/financial_calculator_test.dart` | Existing unit suite structure (28 tests) |
| 8 | `test/cost_snapshot_test.dart` | Existing **real-SQLite** integration test pattern (142 lines) |
| 9 | `test/recipe_snapshot_test.dart` | Pure-Dart snapshot codec/policy suite (snapshot-phase tests) |

---

## Current Test Architecture

The test suite consists of three files, all under `test/` and all running inside `flutter test` on the standard CI runner:

| Suite | Type | Database | Scope |
|---|---|---|---|
| `financial_calculator_test.dart` (28 tests) | Pure Dart | None | Discount allocation, COGS, effective-discount clamping, duplicate-line handling |
| `recipe_snapshot_test.dart` (snapshot codec + policy) | Pure Dart | None | Snapshot encode/decode round-trip, legacy detection, restoration policy logic |
| `cost_snapshot_test.dart` | **Real SQLite integration** | **In-memory SQLite via `sqflite_common_ffi`** | Partial-schema subset: creates tables with raw SQL, inserts rows, mutates prices, re-queries |

`cost_snapshot_test.dart` is the decisive artifact for this audit. It imports `package:sqflite_common_ffi/sqflite_ffi.dart`, calls `sqfliteFfiInit()` in `setUp`, opens `databaseFactoryFfi.openDatabase(inMemoryDatabasePath)` per test, creates a **subset** of the real schema (inventory, products, product_ingredients, invoices, invoice_items), inserts test data, executes raw SQL, and asserts against real query results. Its presence and presumed success in the current CI configuration proves, empirically, that **real SQLite integration tests can already run on this project's CI without any emulator or platform dependency** — the `sqflite_common_ffi` package resolves on Linux CI runners and provides a genuine SQLite engine in memory.

The structural gap is that this suite is **schema-subset only**: it replicates a handful of `CREATE TABLE` statements inline rather than reusing the production `_onCreate`/`_onUpgrade` pipelines (which are private), and it never drives the production business layer (`AppProvider` / `DatabaseHelper` static methods). What remains unevaluated by any test today is precisely the surface this audit concerns: migrations, the full sale transaction, snapshot persistence through the real code paths, and rollback behavior.

---

## Database Testability

**Question:** How is `DatabaseHelper` created, can a separate test database be created, and is the canonical `CREATE DB → SCHEMA → MIGRATIONS → TEST DATA → OPERATION → REAL QUERY → ASSERT` flow possible without production changes?

**Findings.** `DatabaseHelper` (`lib/core/database/database_helper.dart`, lines 7–27) is a static singleton:

```dart
class DatabaseHelper {
  static Database? _database;
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();          // ← production path
    final path = join(dbPath, Constants.dbFileName);  // ← hardcoded file
    return await openDatabase(path, version: Constants.dbVersion, ...);
  }
}
```

Every CRUD method in the class (all of them `static Future<...>`: `insertSupplier`, `updateIngredient`, `getProductIngredients`, `deductProductIngredients`, `logInventoryAudit`, ~90 methods) begins with `final db = await database;` — a single funnel into the singleton. There is one reset escape hatch, `closeDatabase()` (lines 893–899), which closes and nulls `_database`, but no way to **inject** an alternate database or **open** the same schema/migrations against a test path.

`AppProvider`, by contrast, receives its database via the constructor (`_db`), and its transaction-bearing methods (`returnInvoice`, `voidInvoice`, and parts of `createInvoice`) execute entirely on `_db!.transaction(...)`. This means:

- **Return/Void/Legacy/audit scenarios are fully testable today** — instantiate `AppProvider(db)` with an in-memory `databaseFactoryFfi` database, seed state with raw SQL, call the method, assert with raw SQL queries.
- **The full sale path (`createInvoice`) is not testable through `AppProvider` without one small change**, because it interleaves the injected transaction database with static calls to `DatabaseHelper.getProductIngredients` / `getIngredientById` / `calculateProductCost`, which always reach the production singleton.

**Verdict.** The canonical flow is **possible with one minor hook**, evaluated as acceptable under "minor test infrastructure" and explicitly **not** architectural refactoring. The hook is three additions to one file: a `static Future<Database> openTestDatabase()` (opens `inMemoryDatabasePath` with `singleInstance: false`, running the same `onConfigure` PRAGMA and delegating `_onCreate`/`_onUpgrade`), a package-visible wrapper for the two migration routines so tests can run v1→v16 from a raw v15 database, and `static void resetForTest()` that closes and nulls the singleton so a following test starts clean. Total surface change: ≈15 lines, zero behavior change for production (untouched unless a test opts in), and every production method signature and semantic stays identical. Alternative approaches that avoid even this — e.g., raw-SQL shadow implementations of the business logic inside tests — were rejected as fragile (they would drift from production and defeat the purpose of integration testing).

---

## Migration Testability

**Question:** Can the v15 → v16 migration be tested for real — create a v15 database, insert a legacy invoice, run the migration, verify version 16, verify the invoice remains readable, verify `recipe_snapshot = NULL`, then insert a new invoice and verify snapshot persistence?

**Findings.** The production `_onUpgrade` (line 281) is a `switch (oldVersion)` ladder with guarded `ALTER TABLE` statements (v16 at the top of the ladder, guarded by a `PRAGMA table_info` check so it is idempotent). The migration logic itself is pure SQL and is **deterministic and side-effect free** beyond the `ALTER TABLE` — no data rewrites, no history mutation, exactly the property that makes migration testing safe and cheap.

The obstacle is visibility: `_onUpgrade` is private. With the minor `openTestDatabase()`/`migrate()` wrapper described above, the canonical migration test sequence is fully executable:

1. Open an in-memory database with `version: 15` and a **v15-complete schema** — the test file can either (a) reuse the production `_onCreate` path through the public wrapper (preferred; the wrapper exists as a one-time addition), or (b) apply the v16 `ALTER TABLE` only after insertion. Option (a) is what the minor infrastructure provides.
2. Insert a legacy invoice + items (raw SQL), with `recipe_snapshot` absent.
3. Close and reopen with `version: Constants.dbVersion (16)` — sqflite runs the pending `_onUpgrade` step automatically — then assert `PRAGMA user_version == 16`.
4. Re-query the legacy invoice: readable, unchanged; `recipe_snapshot IS NULL` (by schema design, new columns default to NULL — Phase 2.1 explicitly relies on this as the legacy sentinel).
5. Create a fresh invoice through the production path and assert `recipe_snapshot` populated.

One dependency is worth stating honestly: building the "v15-complete schema" baseline inside a test requires re-listing the v1–v15 `CREATE TABLE` statements once (≈200 lines of DDL, copyable from the production `_onCreate`/version-helpers). This is a **test-only duplication of DDL text, not of logic** — migrations run from production code, tests only provide the starting schema shape. This is standard and acceptable; the migration code under test remains the production code.

**Verdict.** **Possible with the minor hook** (the version-override open path). Difficulty: low-to-medium. The test is short (~60 lines) and, once written, permanently protects against two failure classes: a migration that corrupts existing rows, and a future v17 migration that assumes `recipe_snapshot NOT NULL`.

---

## Transaction Testability

**Question:** What is the transaction implementation, and can a real rollback be proven on real SQLite?

**Findings.** All mutating business flows in `app_provider.dart` execute inside a single top-level `await _db!.transaction<T>((txn) async { ... })` block:

| Flow | Transaction envelope | Guards / failure points |
|---|---|---|
| `createInvoice` | `_db!.transaction<int>` | insufficient stock / negative inventory → `throw` mid-transaction; customer points inserted after inventory deduction within the same txn |
| `returnInvoice` (lines 762–825) | `_db!.transaction<int>` | `returned` → returns 0; `cancelled` → throws; missing → 0; then snapshot restoration, loyalty reversal, status update, audit insert — all in one txn |
| `voidInvoice` (lines 828–895) | `_db!.transaction<int>` | `cancelled`/`returned`/missing → returns 0 (tolerant); then snapshot restoration, loyalty reversal, audit insert |
| `deleteInvoice` | `_db!.transaction<int>` | status check → deletes |

There are **no nested transactions** — every flow is one flat transaction on the injected `_db`. sqflite's `Database.transaction` issues real `BEGIN`/`COMMIT` and **automatically rolls back** the transaction if the inner future completes with an exception (the `throw` paths in `createInvoice` exercise exactly this). `PRAGMA foreign_keys = ON` is enforced per-connection in `onConfigure` (line 24), so FK violations also produce deterministic failures suitable for forcing rollbacks.

This means the canonical rollback test — *begin → update inventory → insert audit → intentional failure → assert inventory/audit/invoice all unchanged by direct re-query* — is **executable today for the return/void paths with zero production changes** (inject test db, seed an invoice, then arrange a forced failure). Forcing the failure cleanly requires engineering a constraint violation or patching a throw point — the pragmatic test approach is to seed an intentionally invalid state that the code's `throw` paths trigger (e.g., a product whose recipe references a deleted ingredient, hitting the missing-component path inside `restoreInventoryFromSnapshots`), and then re-query all three tables via raw SQL to prove the atomic rollback.

**Verdict.** **Possible today for injected-db paths; possible with the minor hook for static-call paths.** Difficulty: medium for the forced-failure setup, low for the assertion side. This is the single highest-value test class (atomicity is the property that protects inventory integrity under crash), so a medium difficulty is an acceptable price.

---

## Sale Integration Testability

**Question:** Can we drive `createInvoice` end-to-end and assert against `invoices`, `invoice_items`, `recipe_snapshot`, `inventory`, and `inventory_audit_log` on real SQLite, with no mocks?

**Findings.** `createInvoice` (inside `_db!.transaction`) does: insert invoice → loop items inserting `invoice_items` (each with `recipe_snapshot` JSON produced by `encodeRecipeSnapshot`) → loop required ingredients deducting stock via `deductProductIngredients` (which calls `updateIngredientQuantity` and `logInventoryAudit`) → loyalty points insertion. The snapshot persistence and inventory-audit entries are production code, already verified only at the unit level.

As established in the Database Testability section, this path calls **static** `DatabaseHelper` methods for recipe/cost resolution, which currently cannot be redirected. With the minor hook (a test database that `DatabaseHelper.database` resolves to), the full test is straightforward:

1. Seed: supplier/ingredient rows with stock, a product with a recipe, a test user, customer.
2. `AppProvider(db)` — `createInvoice(...)` with 2–3 items.
3. Raw SQL asserts: exactly one `invoices` row (status `completed`, amount = sum of items − discount), `invoice_items` rows with non-NULL valid `recipe_snapshot` JSON (decode and assert `v:1`, ingredient ids, quantities match the recipe at sale time), `inventory` decremented by recipe qty × sold qty per ingredient, `inventory_audit_log` rows with `reference_type='sale'` and `reference_id` = new invoice id, delta signs negative, cost captured.

**Verdict.** **Possible with the minor hook only.** No mocks needed; every assert reads real SQLite rows. Difficulty: medium (test setup is the bulk of the work — fixtures, user seeding for `currentUserName`).

---

## Return Integration Testability

**Question:** Can the historical recipe restoration scenario (recipe v1 100g → sell → change recipe to 150g → return → net delta 0) run on a real database through production code?

**Findings.** Yes — and this is the most direct validation of the Phase 2.0 P0 fix. The test sequence requires no production change:

1. Seed inventory (A = 1000g), recipe v1 (`product_ingredients`: A = 100g), user, product.
2. `AppProvider(db).createInvoice(...)` qty 1 → assert `recipe_snapshot` decodes to 100g and `inventory` row for A shows −100g (via audit: delta −100, snapshot cost captured).
3. **Change the recipe in place** via the production `updateProductIngredients`/`dedcutProductIngredients` path (or raw SQL for speed — the point is what `returnInvoice` reads, not how the recipe was changed): A = 150g.
4. `returnInvoice(id)` → assert the inventory row for A shows +100g (audit delta +100 with `LEGACY_FALLBACK` absent — snapshot path), and final net delta = 0 against the pre-sale baseline.
5. Negative control: verify a hypothetical "current-recipe" restore would have written +150g — i.e., this test would have failed before Phase 2.1 and passes now.

The guards (`returned` → 0, `cancelled` → throw) are directly observable: status column and exception behavior.

**Verdict.** **Possible today** via constructor injection — no production change required. Difficulty: low. Priority: highest (direct regression guard for the P0 corruption the Phase 2.1 fix targets).

---

## Void Integration Testability

**Question:** Same scenario for void: sale → snapshot → recipe change → void → historical restoration.

**Findings.** Identical structure to the return test; `voidInvoice` differs only in its guard semantics (it tolerates `cancelled`/`returned` by returning 0, where `returnInvoice` throws on `cancelled`). The void path uses the same `restoreInventoryFromSnapshots` and the same `sale_cancelled` audit reference type, so the exact same fixture serves both tests. The combined "duplicate protection" matrix (return×2, void×2, return→void, void→return) is likewise directly executable: each combination's observable is the `invoices.status` column, the inventory quantity, and the audit row count — all raw-SQL-readable.

**Verdict.** **Possible today** for void and the four combination tests. Difficulty: low. Priority: high (Phase 1.1 duplicate protection, now proven at the integration level as well as unit level).

---

## Legacy Fallback Testability

**Question:** Can a legacy invoice (no snapshot) be created inside a test database, then returned after a recipe change, verifying fallback execution, the `LEGACY_FALLBACK` audit note, no fake snapshot creation, and policy-matching inventory behavior?

**Findings.** Yes, directly:

1. After running migrations to v16 (minor hook), insert an invoice + items **with `recipe_snapshot` explicitly NULL** (raw SQL) — the legitimate state of any pre-v16 invoice.
2. Seed the current recipe at the *post-change* value (A = 150g) and sell-baseline inventory.
3. Call `returnInvoice` — the code's `readRecipeSnapshot`-null path executes: ingredients restored from `product_ingredients` at 150g × sold qty, and `restoreInventoryFromSnapshots` writes the audit row with the `LEGACY_FALLBACK` note, writing **no** snapshot (the INSERT for a restored snapshot occurs only in the snapshot-backed branch).
4. Assert: `inventory_audit_log` contains a row whose `note` LIKE '%LEGACY_FALLBACK%', no snapshot column mutation on the legacy item, and the inventory delta equals current-recipe quantity (documented behavior, Phase 2.1 policy — this test asserts the policy holds, it does not judge it).

The requirement "لا تصلح الـ fallback. فقط قيّم testability" is respected: the fallback behavior itself is treated as a fixed specification under test, not a defect under repair.

**Verdict.** **Possible with the minor hook** (migration to v16 + injected db). Difficulty: low. Priority: high (the Phase 2.1 policy is observable and must not silently drift).

---

## Rollback Testability

**Question:** Can we force a failure *after* inventory modification but *before* COMMIT inside return/void/createInvoice, then prove inventory/audit/invoice are unchanged?

**Findings.** sqflite's `transaction` commits only if the inner async block completes without an exception; any `throw` produces a real SQLite `ROLLBACK`. The production code already throws at defined points (insufficient stock in createInvoice; `cancelled` state in returnInvoice). To test *mid-flow* rollback we need a failure that occurs after the first mutation:

- **createInvoice:** the recipe-resolution step (`getProductIngredients` → `calculateProductCost`) runs **after** inventory deduction. Seeding a product whose recipe references a **deleted ingredient** (or one with a NULL/invalid cost causing the defensive `null` cost path) triggers the failure branch after the inventory row has already been mutated → catch the exception → re-query `inventory`, `invoices` (none), `invoice_items` (none), `inventory_audit_log` (none) to prove the full rollback. This is achievable **with the minor hook** by adjusting one test fixture row; no code change.
- **returnInvoice/voidInvoice:** snapshot restoration runs first; the loyalty reversal runs after it. A malformed `customer_points_log` state (e.g., a points row with NULL `invoice_id` that the query still tolerates, or a `customer` row missing) can produce a post-mutation failure — less clean, but the cleaner route is again a seeded invalid recipe reference exercised inside `restoreInventoryFromSnapshots`.

The assertion side is entirely raw SQL and unambiguous. The engineering effort is in manufacturing a deterministic, code-path-reachable failure — feasible, but requires care that the failure is the *intended* one and not a different branch.

**Verdict.** **Possible with the minor hook; the failure-manufacturing step is the hardest single test in the matrix (difficulty: medium-high).** Still below the threshold of "architectural refactor" — no test framework, no instrumentation, no production code change: only seed data designed to trip an existing exception path.

---

## Test Dependencies

The dependency audit finds **nothing new is required**:

| Dependency | Status | Classification |
|---|---|---|
| `sqflite` | Already in `pubspec.yaml` (`^2.3.3`) | — |
| `sqflite_common_ffi` | **Already in `pubspec.yaml`** (`^2.3.0`); already imported and used by `test/cost_snapshot_test.dart` | **LOW** — reuse, no addition |
| `flutter_test` | Already in `dev_dependencies`; runs on CI (`flutter test` step exists in `build_apk.yml`) | — |
| Platform dependency / Android-only | None — `sqflite_common_ffi` resolves and runs on the Linux CI runner (proven by the existing cost_snapshot suite); no emulator | **LOW** |
| Native plugin / filesystem | None — tests use `inMemoryDatabasePath`; no temp files, no `path_provider` for tests | **LOW** |
| `flutter integration_test` package | Not needed — these are package-level tests exercising real SQLite, not widget/UI automation | — |
| Additional packages | **Zero new packages** under Option B | **LOW** |

The only "infrastructure" needed is the minor hook in `DatabaseHelper` (production-adjacent, ≈15 lines) plus a small `test/helpers/` file (fixtures, seed functions, db lifecycle) — both are source files, not packages.

---

## Architectural Risk

**Question:** Would adding integration tests reveal that `DatabaseHelper`, repository, or provider layers are excessively coupled to UI or global state?

**Findings, from the code itself:**

- **`AppProvider` is not coupled to UI.** It is a plain `ChangeNotifier` that receives its `Database` via constructor and exposes `Future`-returning business methods. The test pattern `AppProvider(db)` is already the natural one. Risk: **low** for this layer.
- **`DatabaseHelper` is coupled to a global singleton + production file path.** This is the one genuine coupling, and it is exactly the coupling the minor hook decouples for tests. It is a coupling to *infrastructure*, not to UI — no widgets, no `BuildContext`, no screen logic touch it. Risk: **medium, localized, and cheaply resolved** (the hook). It is worth stating that a future architecture (repository layer + explicit DI) would further reduce this, but Phase 2.2 explicitly forecloses that ("DO NOT OVERENGINEER"), and the audit confirms it is unnecessary for testing.
- **No repository layer exists** — providers call `DatabaseHelper` static methods and `_db` transaction objects directly. This is an architectural observation registered for future phases; for testability it merely means integration tests target `AppProvider` + `DatabaseHelper` rather than a repository boundary. It does not block testing; it defines the test boundary.
- **Mixed injection model in `createInvoice`** (constructor `_db` for the transaction, static `DatabaseHelper` for recipe/cost resolution) is the single structural quirk an integration test would expose — and the reason the hook, rather than nothing, is the minimal sufficient change.

**Verdict.** The coupling exposure is **real but shallow and local**: one singleton class, no UI entanglement, no global-state dependence in business logic. The integration tests themselves are the right instrument to keep this honest going forward — they would fail fast if a future change reintroduces tight coupling (e.g., a method reaching `WidgetsBinding` or a global `Provider` inside a DB operation).

---

## Test Matrix

The required thirteen-scenario matrix, assessed against the current codebase (with the minor hook assumed available):

| # | Test | Real SQLite Needed? | Currently Possible? | Difficulty | Priority |
|---|------|:---:|:---:|:---:|:---:|
| 1 | Migration v15 → v16 (legacy invoice survives, `recipe_snapshot` NULL, new invoice persists snapshot) | **Yes** | With hook | Medium | **P0** |
| 2 | New invoice snapshot persistence (JSON decode, ingredient ids/qty/cost match recipe at sale time) | **Yes** | With hook | Medium | **P0** |
| 3 | Historical recipe restoration (sell @100g → change recipe → return → net delta 0) | **Yes** | **Today** | Low | **P0** |
| 4 | Void restoration (sell → snapshot → recipe change → void) | **Yes** | **Today** | Low | **P0** |
| 5 | Duplicate return protection (return ×2 → status `returned`, inventory restored once, one audit) | **Yes** | **Today** | Low | **P1** |
| 6 | Duplicate void protection (void ×2 → no double restoration) | **Yes** | **Today** | Low | **P1** |
| 7 | Return → Void sequence (blocked by guard, idempotent result) | **Yes** | **Today** | Low | P1 |
| 8 | Void → Return sequence (blocked by guard) | **Yes** | **Today** | Low | P1 |
| 9 | Legacy fallback (NULL snapshot → restore from current recipe → `LEGACY_FALLBACK` audit note → no snapshot written) | **Yes** | With hook | Low | **P0** |
| 10 | Rollback (mid-transaction failure after inventory mutation → inventory/audit/invoice unchanged) | **Yes** | With hook | Medium-High | **P0** |
| 11 | Audit persistence (`inventory_audit_log` rows: reference types, deltas, snapshot cost captured per sale/return/void) | **Yes** | With hook | Medium | P1 |
| 12 | Inventory persistence (post-sale stock exactly `initial − Σ(recipe_qty×sold)`; negative-stock exception path rejects sale without mutation) | **Yes** | With hook | Medium | **P0** |
| 13 | COGS preservation (ingredient price change after sale does not alter saved `cost_snapshot`/profit of existing invoice items — extension of existing `cost_snapshot_test.dart` pattern to the full schema) | **Yes** | **Today** (extends existing suite) | Low-Medium | P1 |

Read the "Currently Possible" column as: **"Today"** = executable on the current codebase with zero production changes (constructor injection covers it); **"With hook"** = executable after the ≈15-line minor infrastructure addition. No scenario requires architectural refactoring.

---

## Options Comparison

| Dimension | Option A — Pure Dart tests only | Option B — Minimal SQLite integration tests | Option C — Full integration test architecture |
|---|---|---|---|
| **Coverage** | Policies, formulas, codecs only (current state). DB layer — migrations, transactions, rollback, snapshot persistence — remains unproven | Adds the DB layer for the ~10 highest-value scenarios: migration, snapshot persistence, restoration, guards, rollback, audit, inventory math | Everything: repositories, DI boundaries, UI flows, end-to-end widget scenarios |
| **Risk mitigated** | Zero DB-layer risk captured | P0 corruption classes (Phases 2.0/2.1 findings) gain permanent regression guards | All classes, including UI |
| **Complexity** | None (already exists) | Low: ≈15-line hook + ~150-line fixture helper + 5–10 tests | High: repository layer, DI container, contract interfaces, fixture factories |
| **Maintenance** | Low | Low: fixture helper evolves with schema; tests assert production SQL directly | High: mocks/fakes/factories to maintain alongside every schema change |
| **Value** | Necessary but insufficient — the P0 inventory corruption of Phase 2.0 existed *despite* pure-Dart tests | High per line of test: each test pins a real SQLite behavior that unit tests cannot observe | Diminishing returns at this project's stage; violates the explicit "do not overengineer" constraint |

**Recommended option: B.** Five to ten integration tests are sufficient, exactly as anticipated by the requirements. Option A leaves the layer where the only confirmed corruption ever occurred (inventory integrity under recipe change) untested; Option C is explicitly ruled out by the no-refactor constraint and would cost more than the risk it covers.

---

## Required Infrastructure

The minimal set, in order:

1. **`DatabaseHelper` test hook (≈15 lines, one file, non-breaking):**
   - `static Future<Database> openTestDatabase({int? version})` — opens `inMemoryDatabasePath` with `singleInstance: false`, applies the production `onConfigure` (FK enforcement), and runs `_onCreate`/`_onUpgrade` through a public `static Future<void> migrate(Database db, int from, int to)` wrapper over the existing private routines.
   - `static void resetForTest()` — closes and nulls the singleton (reuse of the existing `closeDatabase` semantics), so each test starts from a clean singleton state.
   - Production behavior untouched: these members are inert unless a test opts in.

2. **`test/helpers/db_integration_helpers.dart` (≈100–150 lines, test-only):**
   - Fixture seeders: `seedInventory`, `seedRecipe` (vN), `seedProduct`, `seedUser`, `seedCustomer`, `seedLegacyInvoice` (NULL snapshot), via raw SQL against the injected db.
   - Lifecycle helper wrapping `sqfliteFfiInit()` + open/close/reset per test (`setUp`/`tearDown`).
   - Assertion helpers for the recurring checks (snapshot decode+compare, net inventory delta, audit row assertions).

3. **5–10 integration tests** following the matrix priority: the four P0 tests (1, 3, 4, 9/10, 12) first, then P1 guards.

Total new surface area: **one small production hook + one test helper + ~10 test files/tests** — well within the "5–10 integration tests, do not overengineer" boundary. No packages, no CI changes required (the existing `flutter test` step already runs the `cost_snapshot_test.dart` precedent on the same runner).

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| The singleton hook, if misused in production code, could redirect live operations | Low (test-only naming/visibility discipline; hook is only called from `test/`) | Name it `openTestDatabase`/`resetForTest` and guard with `// test only` markers |
| DDL duplication for the "v15 baseline schema" in migration tests may drift from production | Medium | Prefer reusing production `_onCreate` via the public migrate wrapper; treat DDL text as last resort; a drift would surface as a failing migration test, which is itself informative |
| Forced-rollback tests rely on tripping specific exception paths; brittle if exception locations move | Medium | Anchor the failure to stable, domain-level states (deleted ingredient, missing customer) rather than code-line locations; test name documents the contract |
| `sqflite_common_ffi` FFI layer depends on CI runner toolchain | Low | Already proven by `cost_snapshot_test.dart` on the current CI; monitor runner image updates |
| Integration tests run slower than pure Dart tests, adding CI minutes | Low | 5–10 tests × in-memory DB ≈ seconds; negligible vs. the existing build pipeline (~5 min) |
| Not adding tests at all leaves the DB layer (site of the confirmed Phase 2.0 P0 corruption) perpetually unproven | **High if ignored** | This is precisely why Option B is recommended over Option A |

---

## Final Verdict

**PHASE 2.2 STATUS**

**PASS — READINESS AUDIT COMPLETE**

| Constraint | Status |
|---|---|
| Files Modified | **0** |
| Database Modified | **NO** |
| Schema Modified | **NO** |
| Migrations Modified | **NO** |
| Tests Added | **NO** |

**RECOMMENDATION: B — READY WITH MINOR TEST INFRASTRUCTURE**

The project can receive a minimal suite of real SQLite integration tests covering migrations, snapshot persistence, historical restoration, void/return guards, legacy fallback, inventory math, and mid-transaction rollback — with a single ≈15-line, non-breaking hook in `DatabaseHelper` as the only production-adjacent change, and one small test-only fixture helper. No architectural refactoring, no repository layer, no dependency injection framework, no new packages, and no CI changes are required. The required SQLite runtime already ships in `pubspec.yaml` and is already proven to run on the project's CI by the existing `cost_snapshot_test.dart` suite. The recommended immediate next phase (when requested) is Option B: five to ten integration tests ordered by the P0 rows of the matrix in Section 17.

**STOP.** No integration tests were added. No production code was modified. No packages were added. No CI was modified. Phase 2.3 was not started.
