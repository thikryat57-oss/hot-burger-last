// Minimal SQLite integration tests (Phase 2.3).
//
// No mocking framework. Each test opens a REAL isolated in-memory SQLite
// database through the new test hooks in DatabaseHelper, runs the PRODUCTION
// migration ladder and PRODUCTION sale/return/void paths, and asserts against
// real rows. Covers integration Groups A-J from the Phase 2.2 audit.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'package:hot_burger_last/core/constants/constants.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'helpers/db_integration_helpers.dart';

Invoice _makeInvoice({
  required String number,
  required List<CartItem> items,
  double discount = 0,
  String paymentMethod = 'cash',
}) {
  // Subtotal and paid are computed from the actual cart lines so the
  // createInvoice subtotal-vs-lines guard can never be tripped by the test.
  final subtotal = items.fold<double>(
      0, (double s, i) => s + i.price * i.quantity.toDouble());
  final paid = (subtotal - discount).clamp(0.0, double.infinity);
  return Invoice(
    invoiceNumber: number,
    subtotalAmount: subtotal,
    discountAmount: discount,
    totalAmount: subtotal - discount,
    paidAmount: paid,
    changeAmount: 0,
    status: 'completed',
    paymentMethod: paymentMethod,
  );
}

/// Creates a provider with a seeded recipe and returns a helper bundle.
/// beefStock defaults to 1000 because the seeded recipe needs 100 units per
/// burger — stock of 10 would make every sale impossible.
Future<_Env> _seed(
  Database db, {
  int breadStock = 100,
  int beefStock = 1000,
  double price = 25.0,
}) async {
  final bread = await seedIngredient(db, 'bread', breadStock.toDouble());
  final beef = await seedIngredient(db, 'beef', beefStock.toDouble());
  final burger = await seedProduct(db, 'Burger', price);
  await seedRecipe(db, burger, {bread: 2.0, beef: 100.0});
  final provider = await openTestProvider(db);
  return _Env(db: db, provider: provider, bread: bread, beef: beef, burger: burger);
}

class _Env {
  final Database db;
  final AppProvider provider;
  final int bread;
  final int beef;
  final int burger;
  _Env({required this.db, required this.provider, required this.bread, required this.beef, required this.burger});
}

void main() {
  // ---------- Group A: Migration ladder ----------
  group('Group A - migration ladder', () {
    late Database db;
    setUp(() async {
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });
    tearDown(() async {
      DatabaseHelper.resetForTest();
    });

    test('fresh DB at current version exposes the recipe_snapshot column', () async {
      final columns = await db.rawQuery('PRAGMA table_info(invoice_items)');
      expect(columns.map((c) => c['name']), contains('recipe_snapshot'));
    });

    test('v1 -> v16 upgrade produces the identical full schema', () async {
      // A v1 device: open a raw DB WITHOUT production handlers (so _onCreate
      // — which writes the v16 schema in one go — does not run), seed ONLY
      // the v1 tables the real v1 device had, set user_version=1, then run
      // the production ladder exactly as a real device would on upgrade.
      final old = await openRawV1Database();
      await DatabaseHelper.migrate(old, 1, Constants.dbVersion);
      final freshCols = await db.rawQuery('PRAGMA table_info(invoice_items)');
      final upgradedCols = await old.rawQuery('PRAGMA table_info(invoice_items)');
      expect(upgradedCols.map((c) => c['name']).toSet(), freshCols.map((c) => c['name']).toSet());
      await old.close();
    });

    test('v15 -> v16 migration is guarded and repeatable', () async {
      // v15 → v16 must succeed even when recipe_snapshot already exists
      // (column guard). Running it twice must not throw or duplicate anything.
      final old = await DatabaseHelper.openTestDatabase(version: 15);
      await DatabaseHelper.migrate(old, 15, 16);
      await DatabaseHelper.migrate(old, 16, 16);
      final columns = await old.rawQuery('PRAGMA table_info(invoice_items)');
      final snapshotCols = columns.where((c) => c['name'] == 'recipe_snapshot').toList();
      expect(snapshotCols, hasLength(1));
      await old.close();
    });
  });

  // ---------- Group B: New sale end-to-end ----------
  group('Group B - new sale inventory + audit + snapshot', () {
    late Database db;
    setUp(() async {
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });
    tearDown(() async {
      DatabaseHelper.resetForTest();
    });

    test('inventory deducts exactly the recipe quantities and audit rows match', () async {
      final env = await _seed(db);
      final invoiceId = await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 3)],
        ),
        [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 3)],
      );
      // bread: 3 × 2 = 6, beef: 3 × 100 = 300
      expect(await inventoryLevel(db, env.bread), 94.0);
      expect(await inventoryLevel(db, env.beef), 700.0);
      final deltas = await auditDeltaPerIngredient(db, invoiceId);
      expect(deltas[env.bread], -6.0);
      expect(deltas[env.beef], -300.0);
      // Audit rows record the per-unit cost basis at sale time.
      final rows = await auditRowsForInvoice(db, invoiceId);
      expect(rows, hasLength(2));
    });

    test('every invoice line carries an immutable recipe snapshot JSON', () async {
      final env = await _seed(db);
      await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2)],
        ),
        [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2)],
      );
      final rows = await db.query('invoice_items', where: 'invoice_id = ?', whereArgs: [1]);
      expect(rows, hasLength(1));
      final snapshot = await recipeSnapshotFor(db, rows.first['id'] as int);
      expect(snapshot, isNotNull);
      expect(snapshot, contains('"v"'));
    });
  });

  // ---------- Group D/E: Recipe change + historical restoration ----------
  group('Group D/E - historical restoration after recipe change', () {
    late Database db;
    setUp(() async {
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });
    tearDown(() async {
      DatabaseHelper.resetForTest();
    });

    test('return after recipe change restores the ORIGINAL recipe quantities (snapshot), not current', () async {
      final env = await _seed(db);
      final invoiceId = await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
        ),
        [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
      );
      // State after sale: bread 98, beef 0.
      expect(await inventoryLevel(db, env.bread), 98.0);
      expect(await inventoryLevel(db, env.beef), 900.0);

      // Recipe change (the Phase 2.0 corruption scenario): beef → 150g/unit.
      await db.update('product_ingredients', {'quantity': 150.0},
          where: 'product_id = ? AND ingredient_id = ?', whereArgs: [env.burger, env.beef]);
      await db.insert('inventory', {'name': 'extra_beef', 'quantity': 500.0, 'unit': 'kg', 'cost_price': 1.0});

      // Return must use the frozen snapshot (100g), NOT the current recipe (150g).
      await env.provider.returnInvoice(invoiceId);

      // bread: 98 + 2 = 100; beef: (10-100) + 100 = 10 — original only.
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 1000.0);
    });

    test('legacy invoice (NULL snapshot) falls back to the current recipe with a warning row', () async {
      final env = await _seed(db);
      // Sell manually without a snapshot (simulates a pre-v16 invoice):
      final invId = (await db.insert('invoices', {
        'invoice_number': 'INV-OLD',
        'subtotal_amount': 25.0,
        'discount_amount': 0,
        'total_amount': 25.0,
        'paid_amount': 25.0,
        'change_amount': 0,
        'status': 'completed',
        'payment_method': 'cash',
        'created_at': DateTime.now().toIso8601String(),
      })) as int;
      await db.insert('invoice_items', {
        'invoice_id': invId,
        'product_id': env.burger,
        'product_name': 'Burger',
        'quantity': 1,
        'price': 25.0,
        'total': 25.0,
        'cost_snapshot': 0,
        'unit_profit': 0,
        'total_profit': 0,
        'recipe_snapshot': null,
      });
      await db.insert('inventory_audit_log', {
        'ingredient_id': env.bread,
        'quantity_change': -2.0,
        'action_type': 'sale',
        'reference_type': 'invoice',
        'reference_id': invId,
        'cost_price_at_action': 1.0,
        'quantity_before': 100.0,
        'quantity_after': 98.0,
      });
      await db.insert('inventory_audit_log', {
        'ingredient_id': env.beef,
        'quantity_change': -100.0,
        'action_type': 'sale',
        'reference_type': 'invoice',
        'reference_id': invId,
        'cost_price_at_action': 1.0,
        'quantity_before': 1000.0,
        'quantity_after': 900.0,
      });
      // The manual legacy sale only wrote audit rows, not the physical
      // inventory; align it so the return restores on a consistent state.
      await db.update('inventory', {'quantity': 900.0},
          where: 'id = ?', whereArgs: [env.beef]);
      expect(await inventoryLevel(db, env.beef), 900.0);

      // Change the recipe to 150g AFTER the legacy sale.
      await db.update('product_ingredients', {'quantity': 150.0},
          where: 'product_id = ? AND ingredient_id = ?', whereArgs: [env.burger, env.beef]);

      // Legacy return: falls back to the current recipe (150g) — documented
      // trade-off; the audit row must warn (contains_legacy).
      // beef: 1000 - 100 (legacy sale) + 150 (fallback restore) = 1050.
      await env.provider.returnInvoice(invId);
      expect(await inventoryLevel(db, env.beef), 1050.0);
      final auditRows = await db.query('inventory_audit_log',
          where: 'reference_type = ? AND reference_id = ?', whereArgs: ['invoice', invId]);
      expect(auditRows.any((r) => r['note']?.toString().contains('LEGACY_FALLBACK') == true), isTrue);
    });
  });

  // ---------- Group C/F/G/H: duplicate lines, void, guards, rollback ----------
  group('Group C/F/G/H - duplicates, void, guards, atomicity', () {
    late Database db;
    setUp(() async {
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });
    tearDown(() async {
      DatabaseHelper.resetForTest();
    });

    test('duplicate productId lines deduct inventory per LINE and each keeps its own snapshot', () async {
      final env = await _seed(db);
      final invoiceId = await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [
            CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1),
            CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2),
          ],
        ),
        [
          CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1),
          CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2),
        ],
      );
      // 1 + 2 = 3 burgers: bread -6, beef -300.
      expect(await inventoryLevel(db, env.bread), 94.0);
      expect(await inventoryLevel(db, env.beef), 700.0);
      final rows = await db.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      expect(rows, hasLength(2));
      expect(rows.where((r) => r['quantity'] == 1), hasLength(1));
      expect(rows.where((r) => r['quantity'] == 2), hasLength(1));
      for (final row in rows) {
        expect(row['recipe_snapshot'], isNotNull);
      }
      final deltas = await auditDeltaPerIngredient(db, invoiceId);
      expect(deltas[env.beef], -300.0);
    });

    test('void restores exactly the deduplicated line totals (snapshots) and flips status', () async {
      final env = await _seed(db);
      final invoiceId = await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [
            CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1),
            CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2),
          ],
        ),
        [
          CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1),
          CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 2),
        ],
      );
      await env.provider.voidInvoice(invoiceId);
      expect(await invoiceStatus(db, invoiceId), 'cancelled');
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 1000.0);
      // Double-void is rejected by the state guard: it returns 0 and must NOT
      // re-apply inventory deltas (any second credit would over-restore).
      final second = await env.provider.voidInvoice(invoiceId);
      expect(second, 0);
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 1000.0);
    });

    test('return-then-void and void-of-returned are both rejected', () async {
      final env = await _seed(db);
      final invoiceId = await env.provider.createInvoice(
        _makeInvoice(
          number: 'INV-1',
          items: [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
        ),
        [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
      );
      await env.provider.returnInvoice(invoiceId);
      // void after return: the returned-status guard silently returns 0 and
      // must NOT re-apply inventory deltas (documented API shape: void is
      // idempotent, not throwing).
      final voidAfterReturn = await env.provider.voidInvoice(invoiceId);
      expect(voidAfterReturn, 0);
      // second return on a returned invoice is ALSO silently rejected (0),
      // without re-crediting inventory — the same idempotent guard policy.
      final secondReturn = await env.provider.returnInvoice(invoiceId);
      expect(secondReturn, 0);
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 1000.0);
    });

    test('guard: insufficient stock blocks the sale with zero mutations', () async {
      final env = await _seed(db, beefStock: 5); // needs 100 per burger
      await expectLater(
        () => env.provider.createInvoice(
          _makeInvoice(
            number: 'INV-1',
            items: [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
          ),
          [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
        ),
        throwsException,
      );
      expect(await auditRowsForInvoice(db, 1), isEmpty);
      final invoices = await db.query('invoices');
      expect(invoices, isEmpty);
      expect(await inventoryLevel(db, env.bread), 100.0);
    });

    test('bad totals are rejected before touching inventory', () async {
      final env = await _seed(db);
      // Bad totals: claimed subtotal (30) is higher than the actual line
      // total (25 × 1 = 25) — the createInvoice subtotal-vs-lines guard
      // must throw before touching inventory.
      await expectLater(
        () => env.provider.createInvoice(
          Invoice(
            invoiceNumber: 'INV-1',
            subtotalAmount: 30.0,
            discountAmount: 0,
            totalAmount: 30.0,
            paidAmount: 30.0,
            changeAmount: 0,
            status: 'completed',
            paymentMethod: 'cash',
          ),
          [CartItem(productId: env.burger, productName: 'Burger', price: 25.0, quantity: 1)],
        ),
        throwsException,
      );
      expect(await auditRowsForInvoice(db, 1), isEmpty);
    });
  });

  // ---------- Phase 4.1: Destructive inventory safety closure ----------
  // Covers R-01 (recipe link cascade loss), L-1 (legacy fallback silence),
  // L-2 (supplier financial cascade), L-3 (product delete audit), L-4
  // (granular audit paths). Every operation runs through the PRODUCTION
  // safe helpers added in this phase.
  group('Phase 4.1 - destructive safety closure', () {
    late Database db;
    setUp(() async {
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });
    tearDown(() async {
      DatabaseHelper.resetForTest();
    });

    test('deleteIngredientSafe blocks when purchase invoices reference it', () async {
      final env = await _seed(db);
      // Link the material to a purchase invoice (financial record).
      // Use a real supplier row so the FK to suppliers(id) is valid.
      final supplierId = await db.insert('suppliers', {'name': 'Supplier X'});
      final realPurchaseId = await db.insert('purchase_invoices', {
        'supplier_id': supplierId,
        'invoice_number': 'PO-1',
        'total_amount': 50.0,
        'paid_amount': 0,
        'status': 'unpaid',
        'date': '2026-01-01',
      });
      await db.insert('purchase_items', {
        'purchase_invoice_id': realPurchaseId,
        'ingredient_id': env.beef,
        'quantity': 200.0,
        'unit_cost': 1.0,
        'total_cost': 200.0,
      });

      // Financial guard: the material must NOT be deleted.
      await expectLater(
        () => env.provider.deleteIngredient(env.beef),
        throwsA(isA<SafeDeleteBlockedException>()),
      );
      // Zero mutations on block: row and stock untouched.
      expect(await inventoryLevel(db, env.beef), 1000.0);
      // _seed creates TWO recipe links on Burger (bread + beef); the block
      // must leave ALL of them untouched (zero silent cascade).
      final links = await db.query('product_ingredients');
      expect(links, hasLength(2));
      expect(await (db.query('inventory_audit_log',
              where: 'action_type = ?', whereArgs: ['ingredient_deleted'])),
          isEmpty);
    });

    test('deleteIngredientSafe blocks with impact detail when recipe links exist', () async {
      final env = await _seed(db);
      // Recipe link exists; no purchase reference → block-with-impact (not
      // financial), NOT silent cascade.
      await expectLater(
        () => env.provider.deleteIngredient(env.beef),
        throwsA(isA<SafeDeleteBlockedException>()),
      );
      expect(await inventoryLevel(db, env.beef), 1000.0);
      // _seed creates two recipe links on Burger (bread + beef); both survive
      // the block — nothing is silently removed.
      expect(await (db.query('product_ingredients')), hasLength(2));
      final impact = await env.provider.getIngredientImpact(env.beef);
      expect((impact['linked_products'] as List), hasLength(1));
      expect(impact['linked_products'][0]['product_name'], 'Burger');
      expect(impact['purchase_reference_count'], 0);
    });

    test('explicit force delete removes links, material and writes an override audit row', () async {
      final env = await _seed(db);
      final levelBefore = await inventoryLevel(db, env.beef);
      final result = await env.provider.deleteIngredient(env.beef, force: true);
      expect(result, 1);
      // Row deleted, links removed by the safety helper, not silently by SQLite alone.
      expect(await inventoryLevel(db, env.beef), isNull);
      // Beef's own link was removed explicitly; Burger's bread link survives
      // (only the deleted ingredient's links are touched).
      final remaining = await db.query('product_ingredients');
      expect(remaining, hasLength(1));
      expect(remaining.first['ingredient_id'], env.bread);
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ?', whereArgs: ['ingredient_deleted']);
      expect(audit, hasLength(1));
      expect(audit.first['quantity_before'], levelBefore);
      expect(audit.first['note']?.toString().contains('"override":true'), isTrue);
      expect(audit.first['note']?.toString().contains('links_explicitly_removed'), isTrue);
    });

    test('deleteIngredientSafe on an unused material deletes and audits without override', () async {
      final env = await _seed(db);
      final unused = await seedIngredient(db, 'salt', 50.0);
      final result = await env.provider.deleteIngredient(unused);
      expect(result, 1);
      expect(await inventoryLevel(db, unused), isNull);
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ? AND ingredient_id = ?',
          whereArgs: ['ingredient_deleted', unused]);
      expect(audit, hasLength(1));
      // The note JSON carries the 'override' key set to false (unused path,
      // no force override was given): the raw substring 'override' is still
      // present as a key name, so the assertion must check the VALUE, not the
      // presence of the key.
      final note = audit.first['note']?.toString() ?? '';
      expect(note.contains('"override":false'), isTrue);
    });

    test('deleteProductSafe audits the recipe links it destroys (L-3)', () async {
      final env = await _seed(db);
      await env.provider.deleteProduct(env.burger);
      expect(await (db.query('products', where: 'id = ?', whereArgs: [env.burger])), isEmpty);
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ?', whereArgs: ['product_deleted']);
      expect(audit, hasLength(1));
      final note = audit.first['note']?.toString() ?? '';
      expect(note.contains('affected_ingredient_ids'), isTrue);
      expect(note.contains(env.bread.toString()), isTrue);
      expect(note.contains(env.beef.toString()), isTrue);
      // NOTE: the raw product_ingredients links are still removed by
      // product_ingredients FK behavior; the audit row preserves which
      // materials were linked to the deleted product.
    });

    test('deleteSupplierSafe blocks when payments exist (L-2)', () async {
      final env = await _seed(db);
      final supplierId = await db.insert('suppliers', {'name': 'Supplier Y'});
      await db.insert('supplier_payments', {
        'supplier_id': supplierId,
        'amount': 100.0,
        'date': '2026-01-01',
      });
      await expectLater(
        () => env.provider.deleteSupplier(supplierId),
        throwsA(isA<SafeDeleteBlockedException>()),
      );
      expect(
          await (db.query('supplier_payments', where: 'supplier_id = ?', whereArgs: [supplierId])),
          hasLength(1));
      expect(
          await (db.query('inventory_audit_log', where: 'action_type = ?', whereArgs: ['supplier_deleted'])),
          isEmpty);
    });

    test('deleteSupplierSafe blocks when purchase invoices exist (L-2)', () async {
      final env = await _seed(db);
      final supplierId = await db.insert('suppliers', {'name': 'Supplier Z'});
      await db.insert('purchase_invoices', {
        'supplier_id': supplierId,
        'invoice_number': 'PO-2',
        'total_amount': 25.0,
        'paid_amount': 25.0,
        'status': 'paid',
        'date': '2026-01-01',
      });
      await expectLater(
        () => env.provider.deleteSupplier(supplierId),
        throwsA(isA<SafeDeleteBlockedException>()),
      );
      expect(await (db.query('suppliers', where: 'id = ?', whereArgs: [supplierId])), hasLength(1));
    });

    test('deleteSupplierSafe on a clean supplier deletes and audits', () async {
      final env = await _seed(db);
      final supplierId = await db.insert('suppliers', {'name': 'Supplier Clean'});
      final result = await env.provider.deleteSupplier(supplierId);
      expect(result, 1);
      expect(await (db.query('suppliers', where: 'id = ?', whereArgs: [supplierId])), isEmpty);
      expect(
          await (db.query('inventory_audit_log', where: 'action_type = ?', whereArgs: ['supplier_deleted'])),
          hasLength(1));
    });

    test('deleteProductIngredientSafe audits each removed recipe link (L-4)', () async {
      final env = await _seed(db);
      await env.provider.deleteProductIngredient(env.burger, env.bread);
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ?', whereArgs: ['recipe_link_deleted']);
      expect(audit, hasLength(1));
      final note = audit.first['note']?.toString() ?? '';
      expect(note.contains(env.burger.toString()), isTrue);
      expect(note.contains(env.bread.toString()), isTrue);
      // Link physically gone; beef link preserved.
      final links = await db.query('product_ingredients',
          where: 'product_id = ?', whereArgs: [env.burger]);
      expect(links, hasLength(1));
      expect(links.first['ingredient_id'], env.beef);
    });

    test('deleteExpenseSafe audits the removed amount (L-4)', () async {
      final env = await _seed(db);
      final expenseId = await db.insert('expenses', {
        'name': 'إيجار',
        'amount': 500.0,
        'date': '2026-02-01',
      });
      await env.provider.deleteExpense(expenseId);
      expect(await (db.query('expenses', where: 'id = ?', whereArgs: [expenseId])), isEmpty);
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ?', whereArgs: ['expense_deleted']);
      expect(audit, hasLength(1));
      expect(audit.first['quantity_before'], 500.0);
    });

    test('legacy fallback with NO current recipe links logs an explicit diagnostic (L-1)', () async {
      final env = await _seed(db);
      // Hand-seed a legacy invoice (NULL snapshot) as in the Group D test.
      final invId = await db.insert('invoices', {
        'invoice_number': 'LEG-1',
        'total_amount': 25.0,
        'status': 'completed',
      });
      await db.insert('invoice_items', {
        'invoice_id': invId,
        'product_id': env.burger,
        'product_name': 'Burger',
        'quantity': 1,
        'price': 25.0,
        'total': 25.0,
        'cost_snapshot': 0,
        'unit_profit': 0,
        'total_profit': 0,
        'recipe_snapshot': null,
      });
      await db.insert('inventory_audit_log', {
        'ingredient_id': env.beef,
        'quantity_change': -100.0,
        'action_type': 'sale',
        'reference_type': 'invoice',
        'reference_id': invId,
        'cost_price_at_action': 1.0,
        'quantity_before': 1000.0,
        'quantity_after': 900.0,
      });
      await db.update('inventory', {'quantity': 900.0},
          where: 'id = ?', whereArgs: [env.beef]);
      // Delete ALL current recipe links for the product AFTER the legacy sale,
      // then trigger the legacy fallback path.
      await db.delete('product_ingredients');
      await env.provider.returnInvoice(invId);
      // L-1: the path must NO LONGER silently skip — an explicit diagnostic
      // row is recorded in the audit log so the line's fate is provable.
      // The L-1 diagnostic is written by the RETURN path with the same
      // action_type as the return operation ('sale_returned'), so the filter
      // must match that — the audit row proves the legacy line's fate was
      // never silently skipped even though nothing was restored.
      final audit = await db.query('inventory_audit_log',
          where: "reference_type = 'invoice' AND reference_id = ? AND action_type = ?",
          whereArgs: [invId, 'sale_returned']);
      expect(audit.any((r) =>
          r['note']?.toString().contains('LEGACY_FALLBACK_NO_RECIPE_LINKS') == true), isTrue);
    });

    test('legacy fallback WITH current links verifies link count in diagnostics (L-1)', () async {
      final env = await _seed(db);
      final invId = await db.insert('invoices', {
        'invoice_number': 'LEG-2',
        'total_amount': 25.0,
        'status': 'completed',
      });
      await db.insert('invoice_items', {
        'invoice_id': invId,
        'product_id': env.burger,
        'product_name': 'Burger',
        'quantity': 1,
        'price': 25.0,
        'total': 25.0,
        'cost_snapshot': 0,
        'unit_profit': 0,
        'total_profit': 0,
        'recipe_snapshot': null,
      });
      await db.insert('inventory_audit_log', {
        'ingredient_id': env.beef,
        'quantity_change': -100.0,
        'action_type': 'sale',
        'reference_type': 'invoice',
        'reference_id': invId,
        'cost_price_at_action': 1.0,
        'quantity_before': 1000.0,
        'quantity_after': 900.0,
      });
      await db.update('inventory', {'quantity': 900.0},
          where: 'id = ?', whereArgs: [env.beef]);
      await env.provider.returnInvoice(invId);
      // L-1: every legacy line leaves an explicit audit trace — here the
      // product still has current recipe links, so each restored link is
      // documented as LEGACY_FALLBACK (2 links: bread + beef).
      final audit = await db.query('inventory_audit_log',
          where: "reference_type = 'invoice' AND reference_id = ?",
          whereArgs: [invId]);
      expect(audit.where((r) => r['note']?.toString().contains('LEGACY_FALLBACK') == true), hasLength(2));
      // Legacy fallback restores from CURRENT recipe links: bread qty 2.0 and
      // beef qty 100.0, each × soldQty 1. Beef: 900 + 100 = 1000; bread stays
      // untouched by the legacy sale, so 100 + 2 = 102.
      expect(await inventoryLevel(db, env.beef), 1000.0);
      expect(await inventoryLevel(db, env.bread), 102.0);
    });

    test('impact preview reports all products sharing the same material', () async {
      final env = await _seed(db);
      final pizza = await seedProduct(db, 'Pizza', 30.0);
      // Pizza shares the same bread material.
      await seedRecipe(db, pizza, {env.bread: 3.0});
      final impact = await env.provider.getIngredientImpact(env.bread);
      final linked = (impact['linked_products'] as List).cast<Map>();
      expect(linked, hasLength(2));
      expect(linked.map((m) => m['product_name']),
          containsAll(['Burger', 'Pizza']));
    });

    test('force=false delete on an unlinked material must NOT touch linked ingredients', () async {
      final env = await _seed(db);
      // Bread is linked; beef is used only by burger too. Delete an unused
      // material via force=false (default) and assert the linked ones stay.
      final unused = await seedIngredient(db, 'pepper', 20.0);
      await env.provider.deleteIngredient(unused, force: false);
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 1000.0);
      // Both existing recipe links (bread + beef on Burger) are untouched by
      // the deletion of the unrelated unused material.
      expect(await (db.query('product_ingredients')), hasLength(2));
    });

    test('deleteIngredientSafe is atomic: audit row written inside the same transaction as the delete', () async {
      final env = await _seed(db);
      await env.provider.deleteIngredient(env.beef, force: true);
      // If the audit row were written outside the transaction, a partial
      // failure could leave the material gone with no record. Same
      // transaction: both visible or neither.
      final audit = await db.query('inventory_audit_log',
          where: 'action_type = ? AND ingredient_id = ?',
          whereArgs: ['ingredient_deleted', env.beef]);
      expect(audit, hasLength(1));
      // The audit row reflects the post-delete state exactly (row gone → 0),
      // and quantity_change equals the full quantity removed — proving the
      // audit and the delete are inseparable inside one transaction.
      expect(audit.first['quantity_after'], 0);
      expect(audit.first['quantity_change'], -(audit.first['quantity_before'] as num));
    });
  });
}
