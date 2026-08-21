import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Phase 6.12: Legacy Data & Migration Integrity', () {
    late AppProvider provider;
    late Database db;

    setUp(() async {
      // Create a fresh DB
      db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
    });

    test('LEGACY-001: Verify Purchase Items bridge for historical Ingredient ID', () async {
      // 1. Setup: Manually insert into inventory (Legacy)
      final ingredientId = await db.insert('inventory', {
        'name': 'خس قديم',
        'quantity': 10.0,
        'unit': 'كيس',
        'cost_price': 5.0,
      });

      final supplierId = await provider.addSupplier(Supplier(name: 'مورد قديم'));

      // 2. Action: Create Purchase using legacy ingredientId (via materialId bridge)
      final items = [
        PurchaseItem(
          materialId: ingredientId,
          materialName: 'خس قديم',
          quantity: 10.0,
          unitCost: 7.0,
          totalCost: 70.0,
          unit: 'كيس',
        ),
      ];

      final invoiceId = await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'LEGACY-001',
          totalAmount: 70.0,
          paidAmount: 70.0,
          status: 'paid',
          date: DateTime.now().toIso8601String(),
        ),
        items,
      );

      // 3. Verification
      // Check if legacy inventory was updated
      final invRows = await db.query('inventory', where: 'id = ?', whereArgs: [ingredientId]);
      expect(invRows.first['quantity'], 20.0);
      expect(invRows.first['cost_price'], 6.0); // (10*5 + 10*7)/20 = 120/20 = 6

      // Check if audit log was written with legacy note
      final auditLogs = await db.query('inventory_audit_log', where: 'reference_id = ?', whereArgs: [invoiceId]);
      expect(auditLogs.first['note'], contains('Legacy'));
    });
  });
}
