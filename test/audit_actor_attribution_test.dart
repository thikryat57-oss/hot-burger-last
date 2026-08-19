// HOT BURGER — Phase 4.6.1: Inventory Audit Actor Attribution (NEW-F-01).
//
// Real file-based SQLite only: a fresh temp directory is wired as the
// application databases path so every production helper operates on an actual
// file on disk, exactly like a real device. No mocks, no in-memory
// substitutes — an attribution bug (missing executor identity) is exercised
// the same way production does.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/providers/app_provider.dart';

import 'helpers/db_integration_helpers.dart';

void main() {
  late Directory tmpDir;
  late Database liveDb;
  late AppProvider provider;

  setUp(() async {
    sqfliteFfiInit();
    // Route the global sqflite factory to FFI so all production helpers
    // (getDatabasesPath, databaseFactory.openDatabase) operate on the temp dir.
    sqflite.databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('hb_actor_test_');
    databaseFactoryFfi.setDatabasesPath(tmpDir.path);
    DatabaseHelper.resetForTest();
    // The live DB must be a real file at the production path
    // (tmpDir/hot_burger.db) opened through the production funnel so the
    // real migration ladder sets user_version and creates every table.
    liveDb = await DatabaseHelper.database;
    provider = await openTestProvider(liveDb);
  });

  tearDown(() async {
    provider.dispose();
    DatabaseHelper.useTestDatabase(null);
    await DatabaseHelper.resetForTest();
    sqflite.databaseFactoryOrNull = null;
    await tmpDir.delete(recursive: true);
  });

  Map<String, dynamic> actorNoteOf(Map<String, dynamic> row) {
    final raw = row['note'];
    if (raw == null) return const {};
    return Map<String, dynamic>.from(jsonDecode(raw.toString()) as Map);
  }

  /// Completes a sale of [quantity] units of [productId] with the current
  /// seeded prices, returning the created invoice id.
  Future<int> sell(int productId, int quantity) async {
    final productRows = await liveDb.query('products',
        where: 'id = ?', whereArgs: [productId], limit: 1);
    final price = (productRows.first['price'] as num).toDouble();
    final invoice = Invoice(
      invoiceNumber: 'INV-${DateTime.now().microsecondsSinceEpoch}',
      totalAmount: price * quantity,
      subtotalAmount: price * quantity,
      paidAmount: price * quantity,
      status: 'completed',
      paymentMethod: 'cash',
    );
    final items = [
      CartItem(
        productId: productId,
        productName: productRows.first['name'].toString(),
        price: price,
        quantity: quantity,
      ),
    ];
    return await provider.createInvoice(invoice, items);
  }

  test('currentUser identity matches the expected test actor', () async {
    // All tests below assert the executor is the manager seeded by
    // openTestProvider — verify that contract once, explicitly.
    expect(provider.currentUser?.name, 'Manager Test');
    expect(provider.currentUser?.id, isNotNull);
  });

  // -------------------------------------------------------------------------
  // Create invoice (sale): ingredient deduction rows must carry the actor.
  // -------------------------------------------------------------------------
  group('createInvoice (sale deduction)', () {
    test('every deducted ingredient row carries the executor identity',
        () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 100);
      final prod = await seedProduct(liveDb, 'بيرقر', 25);
      await seedRecipe(liveDb, prod, {ingr: 0.5});
      final id = await sell(prod, 2);
      final rows = await auditRowsForInvoice(liveDb, id);
      expect(rows, hasLength(1));
      final note = actorNoteOf(rows.first);
      expect(note['user_id'], provider.currentUser?.id);
      expect(note['user_name'], provider.currentUser?.name);
      // Diagnostic notes are absent for normal sales (only failures add one).
      expect(note.containsKey('note'), isFalse);
    });

    test('quantities are exact — attribution never changes the math',
        () async {
      final ingr = await seedIngredient(liveDb, 'جبنة', 40);
      final prod = await seedProduct(liveDb, 'تشيز بيرقر', 30);
      await seedRecipe(liveDb, prod, {ingr: 0.1});
      final before = await inventoryLevel(liveDb, ingr);
      final id = await sell(prod, 3);
      // -3 * 0.1 = -0.3
      expect(await inventoryLevel(liveDb, ingr), closeTo(before! - 0.3, 1e-9));
      final deltas = await auditDeltaPerIngredient(liveDb, id);
      expect(deltas[ingr], closeTo(-0.3, 1e-9));
    });
  });

  // -------------------------------------------------------------------------
  // Return invoice: snapshot restoration rows must carry the actor.
  // -------------------------------------------------------------------------
  group('returnInvoice (sale_returned restoration)', () {
    test('restoration rows carry the executor and preserve the snapshot note',
        () async {
      final ingr = await seedIngredient(liveDb, 'خبز', 80);
      final prod = await seedProduct(liveDb, 'ساندويتش', 20);
      await seedRecipe(liveDb, prod, {ingr: 1});
      final id = await sell(prod, 4);
      expect(await inventoryLevel(liveDb, ingr), closeTo(76, 1e-9));

      await provider.returnInvoice(id);
      final rows = await auditRowsForInvoice(liveDb, id);
      // sale rows + sale_returned rows
      final restored = rows.where((r) => r['action_type'] == 'sale_returned');
      expect(restored, hasLength(1));
      final note = actorNoteOf(restored.first);
      expect(note['user_id'], provider.currentUser?.id);
      expect(note['user_name'], provider.currentUser?.name);
      expect(note['note'], 'HISTORICAL_SNAPSHOT');
      expect(await inventoryLevel(liveDb, ingr), closeTo(80, 1e-9));
    });
  });

  // -------------------------------------------------------------------------
  // Void invoice: cancellation rows must carry the actor.
  // -------------------------------------------------------------------------
  group('voidInvoice (sale_cancelled restoration)', () {
    test('cancellation rows carry the executor identity', () async {
      final ingr = await seedIngredient(liveDb, 'طماطم', 60);
      final prod = await seedProduct(liveDb, 'بيرقر دبل', 35);
      await seedRecipe(liveDb, prod, {ingr: 0.2});
      final id = await sell(prod, 5);
      await provider.voidInvoice(id);
      final rows = await auditRowsForInvoice(liveDb, id);
      final cancelled =
          rows.firstWhere((r) => r['action_type'] == 'sale_cancelled');
      final note = actorNoteOf(cancelled);
      expect(note['user_id'], provider.currentUser?.id);
      expect(note['user_name'], provider.currentUser?.name);
      expect(note['note'], 'HISTORICAL_SNAPSHOT');
      // Everything restored, original state intact.
      expect(await inventoryLevel(liveDb, ingr), closeTo(60, 1e-9));
    });
  });

  // -------------------------------------------------------------------------
  // Legacy fallback (deleted product-ingredient links): diagnostic note
  // must be preserved alongside the actor identity.
  // -------------------------------------------------------------------------
  test('legacy fallback keeps the diagnostic AND adds the actor', () async {
    final ingr = await seedIngredient(liveDb, 'خس', 50);
    final prod = await seedProduct(liveDb, 'سلطة', 15);
    await seedRecipe(liveDb, prod, {ingr: 0.3});
    final id = await sell(prod, 2);
    // Erase the stored recipe snapshot on the invoice line AFTER the sale —
    // the restoration must fall back to the CURRENT recipe links and log
    // LEGACY_FALLBACK (Phase 2.2 snapshot migration keeps rows valid even
    // when links disappear, so the fallback is triggered by the absent
    // snapshot, not by the deleted link).
    await liveDb.update('invoice_items', {'recipe_snapshot': null},
        where: 'invoice_id = ?', whereArgs: [id]);
    await DatabaseHelper.deleteProductIngredientSafe(prod, ingr,
        userId: provider.currentUser?.id,
        userName: provider.currentUser?.name,
        reason: 'تفصيل اختبار');
    await provider.returnInvoice(id);
    final rows = await auditRowsForInvoice(liveDb, id);
    final legacy = rows.where((r) => r['action_type'] == 'sale_returned');
    expect(legacy, isNotEmpty);
    for (final row in legacy) {
      final note = actorNoteOf(row);
      expect(note['user_id'], provider.currentUser?.id);
      expect(note['user_name'], provider.currentUser?.name);
      // With the snapshot erased AND the current recipe link deleted, the
      // restoration logs LEGACY_FALLBACK_NO_RECIPE_LINKS (a stricter
      // documented variant). Either variant proves the fallback path was
      // exercised and the diagnostic was preserved.
      final noteText = (note['note'] as String?) ?? '';
      expect(noteText.startsWith('LEGACY_FALLBACK'), isTrue,
          reason: 'expected a LEGACY_FALLBACK diagnostic, got: $noteText');
    }
  });

  // -------------------------------------------------------------------------
  // addIngredient / updateIngredient / recordPurchase: manual + purchase
  // movements must carry the actor; quantities stay exact.
  // -------------------------------------------------------------------------
  test('addIngredient records the executor in the creation movement',
      () async {
    await provider.addIngredient(IngredientModel(
      name: 'كيتشب جديد',
      quantity: 20,
      unit: 'زجاجة',
      costPrice: 2.5,
    ));
    final rows = await liveDb.query('inventory_audit_log',
        where: "action_type = 'added'", orderBy: 'id DESC', limit: 1);
    expect(rows, hasLength(1));
    final note = actorNoteOf(rows.first);
    expect(note['user_id'], provider.currentUser?.id);
    expect(note['user_name'], provider.currentUser?.name);
    // Quantity recorded exactly as submitted.
    expect((rows.first['quantity_after'] as num).toDouble(), closeTo(20, 1e-9));
  });

  test('updateIngredient records the executor without changing stock math',
      () async {
    final ingr = await seedIngredient(liveDb, 'مايونيز', 30);
    final before = await inventoryLevel(liveDb, ingr);
    await provider.updateIngredient(IngredientModel(
      id: ingr,
      name: 'مايونيز',
      quantity: 35,
      unit: 'كجم',
      costPrice: 3,
    ));
    final rows = await liveDb.query('inventory_audit_log',
        where: 'ingredient_id = ?', whereArgs: [ingr], orderBy: 'id DESC', limit: 1);
    final note = actorNoteOf(rows.first);
    expect(note['user_id'], provider.currentUser?.id);
    expect(note['user_name'], provider.currentUser?.name);
    expect((rows.first['quantity_change'] as num).toDouble(), closeTo(5, 1e-9));
    expect((rows.first['quantity_after'] as num).toDouble(), closeTo(35, 1e-9));
    expect(await inventoryLevel(liveDb, ingr), closeTo(before! + 5, 1e-9));
  });

  test('recordPurchase records the executor and exact quantity', () async {
    final ingr = await seedIngredient(liveDb, 'لحمة مطحونة', 70);
    final before = await inventoryLevel(liveDb, ingr);
    await provider.recordPurchase(ingr, 10, 4);
    final rows = await liveDb.query('inventory_audit_log',
        where: "action_type = 'purchase' AND ingredient_id = ?",
        whereArgs: [ingr],
        orderBy: 'id DESC',
        limit: 1);
    final note = actorNoteOf(rows.first);
    expect(note['user_id'], provider.currentUser?.id);
    expect(note['user_name'], provider.currentUser?.name);
    expect((rows.first['quantity_change'] as num).toDouble(), closeTo(10, 1e-9));
    expect(await inventoryLevel(liveDb, ingr), closeTo(before! + 10, 1e-9));
  });

  // -------------------------------------------------------------------------
  // createPurchaseInvoice: every movement inside the transaction carries the
  // actor, with a real supplier satisfying the FK.
  // -------------------------------------------------------------------------
  group('createPurchaseInvoice (purchase transaction)', () {
    Future<int> seedSupplier() async {
      return await provider.addSupplier(Supplier(name: 'مورد الاختبار'));
    }

    test('movement rows carry the executor and exact cost/quantity math',
        () async {
      final ingr = await seedIngredient(liveDb, 'دجاج', 15);
      final supplierId = await seedSupplier();
      await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'PUR-461',
          totalAmount: 20,
          status: 'unpaid',
          date: DateTime.now().toIso8601String(),
        ),
        [
          PurchaseItem(
              ingredientId: ingr, quantity: 5, unitCost: 4, totalCost: 20),
        ],
      );
      final rows = await liveDb.query('inventory_audit_log',
          where: "action_type = 'purchase' AND ingredient_id = ?",
          whereArgs: [ingr],
          orderBy: 'id DESC',
          limit: 1);
      expect(rows, hasLength(1));
      final note = actorNoteOf(rows.first);
      expect(note['user_id'], provider.currentUser?.id);
      expect(note['user_name'], provider.currentUser?.name);
      expect((rows.first['quantity_change'] as num).toDouble(), closeTo(5, 1e-9));
      expect(await inventoryLevel(liveDb, ingr), closeTo(20, 1e-9));
    });
  });

  // -------------------------------------------------------------------------
  // Negative proof: a movement written WITHOUT actor attribution must fail
  // these tests. The shared builder guarantees the executor is never silently
  // omitted, and an absent actor is still recorded so the absence is visible
  // in the audit rather than invisible.
  // -------------------------------------------------------------------------
  test('actor note is never an empty map for a signed-in executor', () async {
    final ingr = await seedIngredient(liveDb, 'خبز محمص', 10);
    await provider.recordPurchase(ingr, 3, 2);
    final rows = await liveDb.query('inventory_audit_log',
        where: 'ingredient_id = ?', whereArgs: [ingr], orderBy: 'id DESC', limit: 1);
    final note = actorNoteOf(rows.first);
    expect(note['user_id'], isNotNull);
    expect(note['user_name'], isNotNull);
    expect(note.keys, containsAll(['user_id', 'user_name']));
  });

  // -------------------------------------------------------------------------
  // logInventoryAudit direct contract: optional actor params serialize as the
  // shared JSON shape and leave plain notes intact when provided.
  // -------------------------------------------------------------------------
  test('logInventoryAudit preserves a plain diagnostic note plus actor',
      () async {
    final ingr = await seedIngredient(liveDb, 'مواد تنظيف', 5);
    await DatabaseHelper.logInventoryAudit(
      actionType: 'manual',
      ingredientId: ingr,
      quantityBefore: 5,
      quantityChange: 0,
      quantityAfter: 5,
      costPriceAtAction: 0,
      note: 'فحص مخزون',
      userId: provider.currentUser?.id,
      userName: provider.currentUser?.name,
    );
    final rows = await liveDb.query('inventory_audit_log',
        where: 'action_type = ?', whereArgs: ['manual'], limit: 1);
    final note = actorNoteOf(rows.first);
    expect(note['user_id'], provider.currentUser?.id);
    expect(note['user_name'], provider.currentUser?.name);
    expect(note['note'], 'فحص مخزون');
  });

  test('logInventoryAudit without an actor still succeeds (null-safe)',
      () async {
    final ingr = await seedIngredient(liveDb, 'صلصة', 8);
    await DatabaseHelper.logInventoryAudit(
      actionType: 'manual',
      ingredientId: ingr,
      quantityBefore: 8,
      quantityChange: 1,
      quantityAfter: 9,
      costPriceAtAction: 0,
    );
    final rows = await liveDb.query('inventory_audit_log',
        where: 'action_type = ?', whereArgs: ['manual'], limit: 1);
    // A null actor yields a note with only the actor keys set to null — the
    // row is still written and the absence is explicit in the log.
    final note = actorNoteOf(rows.first);
    expect(note, containsPair('user_id', null));
    expect(note, containsPair('user_name', null));
  });
}
