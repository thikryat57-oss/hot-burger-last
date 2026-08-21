import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.12: Multi-item Purchase & Financial Reconciliation', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
    });

    test('PROC-MULTI: Verify Multi-item Invoice Sum, Database Consistency and Audit Logs', () async {
      // 1. Setup
      await provider.addCategory(Category(name: 'خامات'));
      final supplierId = await provider.addSupplier(Supplier(name: 'مورد الجملة'));

      final eggsId = await provider.addMaterial(MaterialModel(name: 'بيض', type: 'raw', unit: 'حبة', costPrice: 0, quantity: 0, category: 'خامات'));
      final oilId = await provider.addMaterial(MaterialModel(name: 'زيت', type: 'raw', unit: 'لتر', costPrice: 0, quantity: 0, category: 'خامات'));
      final sugarId = await provider.addMaterial(MaterialModel(name: 'سكر', type: 'raw', unit: 'كيلو', costPrice: 0, quantity: 0, category: 'خامات'));

      // 2. Action: Create Multi-item Purchase
      // Eggs: 100 * 100 = 10,000
      // Oil: 20 * 5000 = 100,000
      // Sugar: 10 * 1500 = 15,000
      // Total = 125,000
      final items = [
        PurchaseItem(materialId: eggsId, materialName: 'بيض', quantity: 100.0, unitCost: 100.0, totalCost: 10000.0, unit: 'حبة'),
        PurchaseItem(materialId: oilId, materialName: 'زيت', quantity: 20.0, unitCost: 5000.0, totalCost: 100000.0, unit: 'لتر'),
        PurchaseItem(materialId: sugarId, materialName: 'سكر', quantity: 10.0, unitCost: 1500.0, totalCost: 15000.0, unit: 'كيلو'),
      ];

      final invoiceId = await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'MULTI-001',
          totalAmount: 125000.0,
          paidAmount: 125000.0,
          status: 'paid',
          date: DateTime.now().toIso8601String(),
        ),
        items,
      );

      // 3. Verification: Database Counts
      final db = await DatabaseHelper.database;
      
      // Verify 1 Purchase Invoice
      final invoices = await db.query('purchase_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      expect(invoices.length, 1);
      expect(invoices.first['total_amount'], 125000.0);

      // Verify 3 Purchase Items
      final dbItems = await db.query('purchase_items', where: 'purchase_invoice_id = ?', whereArgs: [invoiceId]);
      expect(dbItems.length, 3);
      
      double calculatedTotal = 0;
      for (var item in dbItems) {
        calculatedTotal += (item['quantity'] as num) * (item['unit_cost'] as num);
      }
      expect(calculatedTotal, 125000.0);

      // Verify 3 Inventory Audit Logs (IN transactions)
      final auditLogs = await db.query('inventory_audit_log', where: 'reference_type = ? AND reference_id = ?', whereArgs: ['purchase_invoice', invoiceId]);
      expect(auditLogs.length, 3);

      // Verify Material ID Integrity
      for (var item in dbItems) {
        expect(item['material_id'], isNotNull);
        expect(item['material_id'], isNot(0));
      }
    });
  });
}
