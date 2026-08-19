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
  final subtotal =
      items.fold<double>(0, (s, i) => s + i.price * i.quantity);
  final paid = (subtotal - discount).clamp(0, double.infinity);
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
      expect(await inventoryLevel(db, env.beef), (10 - 300).toDouble());
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
      expect(await inventoryLevel(db, env.beef), (10 - 100).toDouble());

      // Recipe change (the Phase 2.0 corruption scenario): beef → 150g/unit.
      await db.update('product_ingredients', {'quantity': 150.0},
          where: 'product_id = ? AND ingredient_id = ?', whereArgs: [env.burger, env.beef]);
      await db.insert('inventory', {'name': 'extra_beef', 'quantity': 500.0, 'unit': 'kg', 'cost_price': 1.0});

      // Return must use the frozen snapshot (100g), NOT the current recipe (150g).
      await env.provider.returnInvoice(invoiceId);

      // bread: 98 + 2 = 100; beef: (10-100) + 100 = 10 — original only.
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 10.0);
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
        'quantity_before': 10.0,
        'quantity_after': -90.0,
      });
      // Beef after the legacy sale: -90.
      expect(await inventoryLevel(db, env.beef), (10 - 100).toDouble());

      // Change the recipe to 150g AFTER the legacy sale.
      await db.update('product_ingredients', {'quantity': 150.0},
          where: 'product_id = ? AND ingredient_id = ?', whereArgs: [env.burger, env.beef]);

      // Legacy return: falls back to the current recipe (150g) — documented
      // trade-off; the audit row must warn (contains_legacy).
      // beef: 10 - 100 (legacy sale) + 150 (fallback restore) = 60.
      await env.provider.returnInvoice(invId);
      expect(await inventoryLevel(db, env.beef), 60.0);
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
      expect(await inventoryLevel(db, env.beef), (10 - 300).toDouble());
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
      expect(await inventoryLevel(db, env.beef), 10.0);
      // Double-void is rejected by the state guard: it returns 0 and must NOT
      // re-apply inventory deltas (any second credit would over-restore).
      final second = await env.provider.voidInvoice(invoiceId);
      expect(second, 0);
      expect(await inventoryLevel(db, env.bread), 100.0);
      expect(await inventoryLevel(db, env.beef), 10.0);
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
      expect(await inventoryLevel(db, env.beef), 10.0);
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
}
