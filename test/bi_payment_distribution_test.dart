// Phase 5.1.1 — BI-F-01 regression suite.
//
// Business Intelligence payment distribution must reflect the ACTUAL stored
// payment split for the included invoices (net total_amount per payment
// method, excluding cancelled/returned). Before the fix the BI 'payment'
// list is always zeros because getBusinessIntelligence() invoked the
// canonical aggregateSummary() without paymentSplits.
//
// Real file-based SQLite only (sqflite_common_ffi), production funnel,
// manager login, open shift, createInvoice for all fixtures, legitimate
// returnInvoice/voidInvoice paths. No mocks, no schema changes.
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
    sqflite.databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('hb_bi_pay_test_');
    databaseFactoryFfi.setDatabasesPath(tmpDir.path);
    DatabaseHelper.resetForTest();
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

  /// Completes a sale of [quantity] units of [productId] via the legitimate
  /// createInvoice path, returning the created invoice id.
  Future<int> sell(int productId, int quantity,
      {String paymentMethod = 'cash'}) async {
    final productRows = await liveDb.query('products',
        where: 'id = ?', whereArgs: [productId], limit: 1);
    final price = (productRows.first['price'] as num).toDouble();
    final subtotal = price * quantity;
    final invoice = Invoice(
      invoiceNumber: 'INV-${DateTime.now().microsecondsSinceEpoch}',
      totalAmount: subtotal,
      subtotalAmount: subtotal,
      paidAmount: subtotal,
      status: 'completed',
      paymentMethod: paymentMethod,
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

  /// Completes a discounted sale (net total = subtotal - discount) paid by
  /// [paymentMethod].
  Future<int> sellDiscounted(int productId, int quantity, double discount,
      {String paymentMethod = 'cash'}) async {
    final productRows = await liveDb.query('products',
        where: 'id = ?', whereArgs: [productId], limit: 1);
    final price = (productRows.first['price'] as num).toDouble();
    final subtotal = price * quantity;
    final invoice = Invoice(
      invoiceNumber: 'INV-${DateTime.now().microsecondsSinceEpoch}',
      totalAmount: subtotal - discount,
      subtotalAmount: subtotal,
      discountAmount: discount,
      paidAmount: subtotal - discount,
      status: 'completed',
      paymentMethod: paymentMethod,
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

  Map<String, dynamic> biNow() => {
        'start': DateTime.now().subtract(const Duration(days: 1)),
        'end': DateTime.now().add(const Duration(days: 1)),
      };

  List<Map<String, dynamic>> paymentOf(Map<String, dynamic> data) =>
      (data['payment'] as List).cast<Map<String, dynamic>>();

  double byName(List<Map<String, dynamic>> list, String name) =>
      list.firstWhere((m) => m['name'] == name)['amount'] as double;

  // NOTE (regression anchor, Phase 5.1.1): this anchor intentionally asserts
  // the PRE-FIX behavior (zeros) so the CI record proves the bug was
  // reproduced before the fix was applied. It is SKIPPED once the fix lands
  // (HBP511_FIX_APPLIED=1), because passing the assertion would then falsely
  // mean the fix regressed. Baseline reproduction: 3f757bc, anchor PASSED
  // (zeros observed, BI-F-01 reproduced); this file's TEST 1-8 FAILED with
  // Expected >0 / Actual 0.0 — the full before/after record is preserved.
  final fixApplied =
      Platform.environment['HBP511_FIX_APPLIED'] == '1';

  test(
      'BI payment distribution is zero for a cash invoice BEFORE the fix '
      '(regression anchor)',
      () async {
    expect(fixApplied, isFalse,
        reason: 'anchor must run only against the unfixed baseline');
    final ingr = await seedIngredient(liveDb, 'لحم برجر', 100);
    final prod = await seedProduct(liveDb, 'بيرقر', 50);
    await seedRecipe(liveDb, prod, {ingr: 0.5});
    await sell(prod, 2, paymentMethod: 'cash');

    final data = await provider.getBusinessIntelligence(
        start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
    final pay = paymentOf(data);
    // If this expectation fails on the pre-fix baseline, the test path is
    // broken — STOP and investigate.
    expect(byName(pay, 'نقدًا'), 0);
  },
      skip: fixApplied);

  // ---------------------------------------------------------------------------
  // TEST 1 — CASH ONLY
  // ---------------------------------------------------------------------------
  group('BI-F-01 regression matrix', () {
    test('TEST 1 — cash-only invoice: cashTotal>0, card/bank = 0', () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 100);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});
      await sell(prod, 2, paymentMethod: 'cash');

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'نقدًا'), 100.0);
      expect(byName(pay, 'بطاقة'), 0.0);
      expect(byName(pay, 'تحويل'), 0.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 2 — CARD ONLY
    // ---------------------------------------------------------------------------
    test('TEST 2 — card-only invoice: cardTotal>0, cash/bank = 0', () async {
      final ingr = await seedIngredient(liveDb, 'خبز', 100);
      final prod = await seedProduct(liveDb, 'ساندويتش', 30);
      await seedRecipe(liveDb, prod, {ingr: 0.2});
      await sell(prod, 3, paymentMethod: 'card');

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'بطاقة'), 90.0);
      expect(byName(pay, 'نقدًا'), 0.0);
      expect(byName(pay, 'تحويل'), 0.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 3 — BANK/TRANSFER ONLY
    // ---------------------------------------------------------------------------
    test('TEST 3 — bank-only invoice: bankTotal>0, cash/card = 0', () async {
      final ingr = await seedIngredient(liveDb, 'جبن', 100);
      final prod = await seedProduct(liveDb, 'تشيز بيرقر', 40);
      await seedRecipe(liveDb, prod, {ingr: 0.3});
      await sell(prod, 5, paymentMethod: 'bank');

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'تحويل'), 200.0);
      expect(byName(pay, 'نقدًا'), 0.0);
      expect(byName(pay, 'بطاقة'), 0.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 4 — MIXED PAYMENT SPLIT
    //
    // The application model allows ONE payment method per invoice (single
    // payment_method column). "Mixed split" is therefore exercised at the
    // aggregate level: multiple invoices whose net totals split across
    // methods. Expected split: cash 100, card 60, bank 40.
    // ---------------------------------------------------------------------------
    test('TEST 4 — mixed split across invoices: exact per-method amounts',
        () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 200);
      final p1 = await seedProduct(liveDb, 'بيرقر', 50);
      final p2 = await seedProduct(liveDb, 'بطاطس', 30);
      final p3 = await seedProduct(liveDb, 'مشروب', 20);
      await seedRecipe(liveDb, p1, {ingr: 0.5});
      await seedRecipe(liveDb, p2, {ingr: 0.1});
      await seedRecipe(liveDb, p3, {ingr: 0.1});

      await sell(p1, 2, paymentMethod: 'cash'); // 100
      await sell(p2, 2, paymentMethod: 'card'); // 60
      await sell(p3, 2, paymentMethod: 'bank'); // 40

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'نقدًا'), 100.0);
      expect(byName(pay, 'بطاقة'), 60.0);
      expect(byName(pay, 'تحويل'), 40.0);
      // Accounting invariant: sum of payment splits == net payment total of
      // included invoices (net of discount, NOT gross).
      expect(
          byName(pay, 'نقدًا') + byName(pay, 'بطاقة') + byName(pay, 'تحويل'),
          200.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 5 — MULTIPLE INVOICES
    // ---------------------------------------------------------------------------
    test('TEST 5 — aggregates multiple invoices of the same and mixed methods',
        () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 200);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});

      await sell(prod, 1, paymentMethod: 'cash'); // 50
      await sell(prod, 3, paymentMethod: 'cash'); // 150
      await sell(prod, 2, paymentMethod: 'card'); // 100

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'نقدًا'), 200.0);
      expect(byName(pay, 'بطاقة'), 100.0);
      expect(byName(pay, 'تحويل'), 0.0);
      expect(data['invoices'], 3);
      expect(data['sales'], 300.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 6 — DISCOUNT
    // ---------------------------------------------------------------------------
    test('TEST 6 — discount: payment equals the NET total, no duplication',
        () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 200);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});

      // subtotal 100, discount 20 → net total 80, paid by card.
      await sellDiscounted(prod, 2, 20, paymentMethod: 'card');

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'بطاقة'), 80.0);
      expect(byName(pay, 'نقدًا'), 0.0);
      expect(byName(pay, 'تحويل'), 0.0);
      // Net-payment invariant: cardTotal == included invoices net total.
      expect(byName(pay, 'نقدًا') + byName(pay, 'بطاقة') + byName(pay, 'تحويل'),
          80.0);
      expect(data['discounts'], 20.0);
      expect(data['sales'], 80.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 7 — RETURN / VOID EXCLUSION
    // ---------------------------------------------------------------------------
    test('TEST 7 — returned and voided invoices excluded from payment split',
        () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 200);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});

      final cashId = await sell(prod, 2, paymentMethod: 'cash'); // 100
      await sell(prod, 2, paymentMethod: 'card'); // 100 — stays included
      final bankId = await sell(prod, 2, paymentMethod: 'bank'); // 100

      // Legitimate return/void paths (status moves to returned/cancelled;
      // inventory restored from the historical snapshot — no direct SQL).
      await provider.returnInvoice(cashId);
      await provider.voidInvoice(bankId);

      final data = await provider.getBusinessIntelligence(
          start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
      final pay = paymentOf(data);
      expect(byName(pay, 'نقدًا'), 0.0);
      expect(byName(pay, 'بطاقة'), 100.0);
      expect(byName(pay, 'تحويل'), 0.0);
      expect(data['invoices'], 1);
    });

    // ---------------------------------------------------------------------------
    // TEST 8 — BI ↔ CANONICAL RECONCILIATION
    // ---------------------------------------------------------------------------
    test('TEST 8 — BI payment totals reconcile with the canonical shift '
        'payment data for the same window', () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 300);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});

      await sell(prod, 2, paymentMethod: 'cash'); // 100
      await sell(prod, 1, paymentMethod: 'card'); // 50
      await sell(prod, 4, paymentMethod: 'bank'); // 200

      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final end = now.add(const Duration(days: 1));

      final bi = await provider.getBusinessIntelligence(start: start, end: end);
      final shift = await provider.getShiftSummary(startDate: start, endDate: end);

      final biCash = byName(paymentOf(bi), 'نقدًا');
      final biCard = byName(paymentOf(bi), 'بطاقة');
      final biBank = byName(paymentOf(bi), 'تحويل');

      // The canonical shift summary computes per-method totals from the same
      // stored invoices (raw SQL per method). They must match exactly.
      expect(biCash, (shift['cashTotal'] as num).toDouble());
      expect(biCard, (shift['cardTotal'] as num).toDouble());
      expect(biBank, (shift['bankTotal'] as num).toDouble());

      // Sum of splits == net total of included invoices == shift totalSales.
      expect(biCash + biCard + biBank, 350.0);
      expect((shift['totalSales'] as num).toDouble(), 350.0);
    });

    // ---------------------------------------------------------------------------
    // TEST 9 — EMPTY RANGE
    // ---------------------------------------------------------------------------
    test('TEST 9 — empty BI window yields zero payment splits (existing '
        'semantics preserved)', () async {
      final ingr = await seedIngredient(liveDb, 'لحم برجر', 100);
      final prod = await seedProduct(liveDb, 'بيرقر', 50);
      await seedRecipe(liveDb, prod, {ingr: 0.5});
      await sell(prod, 1, paymentMethod: 'cash');

      final data = await provider.getBusinessIntelligence(
          start: DateTime(2000), end: DateTime(2000, 1, 2));
      final pay = paymentOf(data);
      expect(byName(pay, 'نقدًا'), 0.0);
      expect(byName(pay, 'بطاقة'), 0.0);
      expect(byName(pay, 'تحويل'), 0.0);
      expect(data['invoices'], 0);
    });

    // ---------------------------------------------------------------------------
    // FINANCIAL INTEGRITY: fix must not change revenue/discount/cogs/profit
    // ---------------------------------------------------------------------------
    group('financial integrity (no regression)', () {
      test('revenue, discount, gross/net profit, invoice count unchanged '
          'after the fix', () async {
        final ingr = await seedIngredient(liveDb, 'لحم برجر', 200);
        final prod = await seedProduct(liveDb, 'بيرقر', 50);
        await seedRecipe(liveDb, prod, {ingr: 0.5});

        await sellDiscounted(prod, 2, 10, paymentMethod: 'cash');

        final bi = await provider.getBusinessIntelligence(
            start: biNow()['start'] as DateTime, end: biNow()['end'] as DateTime);
        final daily = await provider.getDailyReport(
            DateTime.now().toIso8601String().substring(0, 10));

        // BI and the canonical daily report must agree on revenue and
        // invoice count — the fix touches payment splits only.
        expect(bi['sales'], 90.0);
        expect(bi['sales'], daily['totalSales']);
        expect(bi['discounts'], daily['discountTotal']);
        expect(bi['discounts'], 10.0);
        expect(bi['invoices'], 1);
        expect(bi['invoices'], daily['invoiceCount']);
        expect(bi['grossProfit'], daily['grossProfit']);
        expect(bi['netProfit'], daily['netProfit']);
      });
    });
  });
}
