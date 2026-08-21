import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.12: WAC Golden Scenario Verification', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
    });

    test('WAC-GOLDEN: Multi-step Purchase WAC Verification (100@100 -> 100@200 -> 50@300)', () async {
      // 0. Setup: Create Category and Supplier
      await provider.addCategory(Category(name: 'خامات'));
      final supplierId = await provider.addSupplier(Supplier(name: 'مورد الاختبار الذهبي'));

      // 1. Initial State: Create Material with 0 quantity and 0 WAC
      final matId = await provider.addMaterial(MaterialModel(
        name: 'بيض',
        type: 'raw',
        unit: 'حبة',
        costPrice: 0.0,
        quantity: 0.0,
        category: 'خامات',
      ));

      // 2. Purchase #1: 100 units @ 100 cost
      // Expected: Qty=100, WAC=100
      await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'INV-001',
          totalAmount: 10000.0,
          paidAmount: 10000.0,
          status: 'paid',
          date: DateTime.now().toIso8601String(),
        ),
        [PurchaseItem(materialId: matId, materialName: 'بيض', quantity: 100.0, unitCost: 100.0, totalCost: 10000.0, unit: 'حبة')]
      );

      var mat = (await provider.getMaterials()).firstWhere((m) => m.id == matId);
      expect(mat.quantity, 100.0);
      expect(mat.costPrice, 100.0);

      // 3. Purchase #2: 100 units @ 200 cost
      // Calculation: ((100 * 100) + (100 * 200)) / 200 = 30000 / 200 = 150
      // Expected: Qty=200, WAC=150
      await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'INV-002',
          totalAmount: 20000.0,
          paidAmount: 20000.0,
          status: 'paid',
          date: DateTime.now().toIso8601String(),
        ),
        [PurchaseItem(materialId: matId, materialName: 'بيض', quantity: 100.0, unitCost: 200.0, totalCost: 20000.0, unit: 'حبة')]
      );

      mat = (await provider.getMaterials()).firstWhere((m) => m.id == matId);
      expect(mat.quantity, 200.0);
      expect(mat.costPrice, 150.0);

      // 4. Purchase #3: 50 units @ 300 cost
      // Calculation: ((200 * 150) + (50 * 300)) / 250 = (30000 + 15000) / 250 = 45000 / 250 = 180
      // Expected: Qty=250, WAC=180
      await provider.createPurchaseInvoice(
        PurchaseInvoice(
          supplierId: supplierId,
          invoiceNumber: 'INV-003',
          totalAmount: 15000.0,
          paidAmount: 15000.0,
          status: 'paid',
          date: DateTime.now().toIso8601String(),
        ),
        [PurchaseItem(materialId: matId, materialName: 'بيض', quantity: 50.0, unitCost: 300.0, totalCost: 15000.0, unit: 'حبة')]
      );

      mat = (await provider.getMaterials()).firstWhere((m) => m.id == matId);
      expect(mat.quantity, 250.0);
      expect(mat.costPrice, 180.0);
    });
  });
}
