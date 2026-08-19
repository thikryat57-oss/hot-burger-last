// Phase 4.7.2 — R-04 closure proof tests.
//
// Real SQLite (in-memory via sqflite_common_ffi), production schema, full
// migration ladder. NO mocks. The production semantics under test:
//
//   insertSupplierPayment(payment, userId, userName) inside ONE transaction:
//     1. INSERT supplier_payments  (returns paymentId)
//     2. UPDATE suppliers balance - amount
//     3. INSERT inventory_audit_log (action_type = 'supplier_payment',
//        reference_type = 'supplier_payment', reference_id = paymentId)
//
// If step 3 fails, the WHOLE transaction rolls back (sqflite mechanism).
// Historic payments receive no audit (NO backfill policy).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hot_burger_last/core/database/database_helper.dart';
import 'package:hot_burger_last/models/models.dart';
import 'helpers/db_integration_helpers.dart';

Future<int> _seedSupplier(Database db, String name, double balance) async {
  final now = DateTime.now().toIso8601String();
  return db.insert('suppliers', {
    'name': name,
    'balance': balance,
    'created_at': now,
    'updated_at': now,
  });
}

SupplierPayment _payment({
  required int supplierId,
  double amount = 250.0,
  String date = '2026-08-20',
  String? notes,
}) =>
    SupplierPayment(
      supplierId: supplierId,
      amount: amount,
      date: date,
      notes: notes,
    );

Future<List<Map<String, dynamic>>> _auditForPayment(Database db, int paymentId) =>
    db.query('inventory_audit_log',
        where: 'action_type = ? AND reference_type = ? AND reference_id = ?',
        whereArgs: ['supplier_payment', 'supplier_payment', paymentId]);

void main() {
  sqfliteFfiInit();

  group('Phase 4.7.2 — R-04: supplier payment audit closure', () {
    late Database db;

    setUp(() async {
      DatabaseHelper.resetTestAuditFailure();
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
    });

    tearDown(() {
      DatabaseHelper.useTestDatabase(null);
      DatabaseHelper.resetTestAuditFailure();
    });

    // TEST 1 + 4 combined: one successful payment → exactly one audit row
    // with correct amount, reference, action type, and metadata.
    test('successful supplier payment creates EXACTLY ONE audit row', () async {
      final supplierId = await _seedSupplier(db, 'دجاج البركة', 1000.0);

      final paymentId = await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: supplierId).toMap(),
        userId: 5,
        userName: 'Manager Yara',
      );

      final payments = await db.query('supplier_payments',
          where: 'id = ?', whereArgs: [paymentId]);
      expect(payments, hasLength(1));
      expect(payments.first['amount'], 250.0);

      final rows = await _auditForPayment(db, paymentId);
      expect(rows, hasLength(1)); // not 2 — no duplicate audit
      final row = rows.first;
      expect(row['action_type'], 'supplier_payment');
      expect(row['reference_type'], 'supplier_payment');
      expect(row['reference_id'], paymentId);
      // Honest zeros — quantity fields carry no fabricated numbers.
      expect(row['quantity_before'], 0);
      expect(row['quantity_change'], 0);
      expect(row['quantity_after'], 0);
      // Supplier balance updated exactly as before the fix.
      final supplier = await db.query('suppliers',
          where: 'id = ?', whereArgs: [supplierId]);
      expect(supplier.first['balance'], 750.0);
      // The real amount survives inside the note.
      final note = row['note']!.toString();
      expect(jsonDecode(note)['note'], contains('amount=250.0'));
    });

    // TEST 2: payment + balance + audit are committed together (same txn).
    test('payment, balance, and audit commit TOGETHER in one transaction',
        () async {
      final supplierId = await _seedSupplier(db, 'اللحوم الطازجة', 500.0);

      // Mid-flight observation must be impossible outside a transaction, so
      // instead we prove atomicity both ways: success leaves all three, and
      // TEST 3 proves failure removes all three. Here we also verify no audit
      // row exists BEFORE the call returns its id.
      final before = await db.query('inventory_audit_log');
      expect(before, isEmpty);

      final paymentId = await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: supplierId, amount: 100.0).toMap(),
        userId: 5,
        userName: 'Manager Yara',
      );

      final after = await db.query('inventory_audit_log');
      expect(after, hasLength(1));
      expect(after.first['reference_id'], paymentId);

      // Balance and payment and audit are all mutually consistent.
      final supplier = await db.query('suppliers',
          where: 'id = ?', whereArgs: [supplierId]);
      expect(supplier.first['balance'], 400.0);
      final payments = await db.query('supplier_payments');
      expect(payments, hasLength(1));
    });

    // TEST 3 (CRITICAL): an audit failure rolls back payment + balance.
    test('audit failure ROLLS BACK the payment and the balance', () async {
      final supplierId = await _seedSupplier(db, 'المزرعة السعيدة', 2000.0);

      DatabaseHelper.setTestAuditFailure(true);

      await expectLater(
        () => DatabaseHelper.insertSupplierPayment(
          _payment(supplierId: supplierId, amount: 300.0).toMap(),
          userId: 5,
          userName: 'Manager Yara',
        ),
        throwsA(isA<StateError>()),
      );

      // No partial mutation must survive: payment absent, balance untouched,
      // no audit row. sqflite rolls back the open transaction automatically.
      expect(await db.query('supplier_payments'), isEmpty);
      final supplier = await db.query('suppliers',
          where: 'id = ?', whereArgs: [supplierId]);
      expect(supplier.first['balance'], 2000.0);
      expect(await db.query('inventory_audit_log'), isEmpty);
    });

    // TEST 5: two different payments → two distinct audit rows, no mixing.
    test('multiple payments produce distinct, correctly-linked audit rows',
        () async {
      final s1 = await _seedSupplier(db, 'مورد 1', 1000.0);
      final s2 = await _seedSupplier(db, 'مورد 2', 2000.0);

      final p1 = await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: s1, amount: 111.0, date: '2026-08-01',
            notes: 'دفعة أولى').toMap(),
        userId: 5,
        userName: 'Manager Yara',
      );
      final p2 = await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: s2, amount: 222.0, date: '2026-08-02',
            notes: 'دفعة ثانية').toMap(),
        userId: 6,
        userName: 'Admin Ahmed',
      );
      expect(p1, isNot(equals(p2)));

      final rows = await db.query('inventory_audit_log',
          where: "action_type = 'supplier_payment'",
          orderBy: 'id ASC');
      expect(rows, hasLength(2));

      expect(rows[0]['reference_id'], p1);
      final note1 = jsonDecode(rows[0]['note']!.toString());
      expect(note1['note'], contains('amount=111.0'));
      expect(note1['note'], contains('supplier_id=$s1'));
      expect(note1['user_id'], 5);
      expect(note1['user_name'], 'Manager Yara');

      expect(rows[1]['reference_id'], p2);
      final note2 = jsonDecode(rows[1]['note']!.toString());
      expect(note2['note'], contains('amount=222.0'));
      expect(note2['note'], contains('supplier_id=$s2'));
      expect(note2['user_id'], 6);
      expect(note2['user_name'], 'Admin Ahmed');

      // Balances deducted independently.
      final b1 = await db.rawQuery(
          'SELECT balance FROM suppliers WHERE id = ?', [s1]);
      final b2 = await db.rawQuery(
          'SELECT balance FROM suppliers WHERE id = ?', [s2]);
      expect(b1.first['balance'], 889.0);
      expect(b2.first['balance'], 1778.0);
    });

    // TEST 6: actor attribution matches the current authenticated actor.
    test('audit actor matches the current authenticated user', () async {
      final supplierId = await _seedSupplier(db, 'الذهب الأخضر', 800.0);

      final paymentId = await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: supplierId, amount: 42.5).toMap(),
        userId: 11,
        userName: 'Manager Salma',
      );

      final rows = await _auditForPayment(db, paymentId);
      expect(rows, hasLength(1));
      final map = jsonDecode(rows.first['note']!.toString());
      expect(map['user_id'], 11);
      expect(map['user_name'], 'Manager Salma');
      expect(map['note'], contains('amount=42.5'));

      // NO fake actor: an anonymous call records null actor keys instead.
      await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: supplierId, amount: 7.0).toMap(),
        // no actor — must NOT invent one
      );
      final anonRows = await db.query('inventory_audit_log',
          where: "action_type = 'supplier_payment'", orderBy: 'id DESC');
      expect(anonRows.first['reference_id'], paymentId + 1);
      final anonMap = jsonDecode(anonRows.first['note']!.toString());
      expect(anonMap['user_id'], isNull);
      expect(anonMap['user_name'], isNull);
    });

    // TEST 7: historical payments untouched — no fake audit is fabricated.
    test('historical payments (inserted before the fix) get NO fabricated audit',
        () async {
      final supplierId = await _seedSupplier(db, 'تاريخي بلا تدقيق', 3000.0);

      // A payment that "already existed" before the fix — written with a raw
      // INSERT, the way a legacy device inserted it: zero audit trail.
      await db.insert('supplier_payments', {
        'supplier_id': supplierId,
        'amount': 999.0,
        'date': '2026-01-05',
        'notes': 'دفعة تاريخية',
        'created_at': '2026-01-05T10:00:00.000',
      });

      // Any number of fresh audited payments afterwards must never reach back
      // and invent a history entry for the legacy row.
      await DatabaseHelper.insertSupplierPayment(
        _payment(supplierId: supplierId, amount: 50.0).toMap(),
        userId: 5,
        userName: 'Manager Yara',
      );

      final rows = await db.query('inventory_audit_log',
          where: "action_type = 'supplier_payment'");
      expect(rows, hasLength(1));
      final legacyPayments = await db.query('supplier_payments',
          where: "date = '2026-01-05'");
      expect(legacyPayments, hasLength(1));
      expect(legacyPayments.first['amount'], 999.0);
      expect(rows.first['reference_id'],
          isNot(equals(legacyPayments.first['id'])));
    });

    // Regression guard: existing callers passing no actor still work
    // (backward compatibility of the optional signature).
    test('existing callers without actor params remain compatible', () async {
      final supplierId = await _seedSupplier(db, 'توافق خلفي', 100.0);
      final id = await DatabaseHelper.insertSupplierPayment({
        'supplier_id': supplierId,
        'amount': 10.0,
        'date': '2026-08-20',
        'notes': null,
      });
      final rows = await db.query('inventory_audit_log',
          where: "action_type = 'supplier_payment'");
      expect(rows, hasLength(1));
      expect(rows.first['reference_id'], id);
      final supplier = await db.query('suppliers',
          where: 'id = ?', whereArgs: [supplierId]);
      expect(supplier.first['balance'], 90.0);
    });
  });
}
