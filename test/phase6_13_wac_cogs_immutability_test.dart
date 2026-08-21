
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: WAC to COGS and Historical Immutability Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('WAC changes correctly affect future sales but preserve historical COGS', () async {
      // 1. Setup: Material "Beef" with initial WAC
      final beefId = await provider.addMaterial(MaterialModel(
        name: 'Beef',
        type: 'raw',
        unit: 'kg',
        quantity: 100,
        costPrice: 100.0, // Initial WAC
      ));

      final categoryId = await provider.addCategory(Category(name: 'Burgers'));
      final productId = await provider.addProduct(Product(name: 'Beef Burger', price: 150.0, categoryId: categoryId));
      await provider.updateRecipe('product', productId, [
        RecipeModel(parentType: 'product', parentId: productId, materialId: beefId, quantity: 1.0, unit: 'kg'),
      ]);

      // 2. Action: Sale #1 (Old WAC)
      final inv1Num = await provider.getNextInvoiceNumber();
      final cart1 = [CartItem(productId: productId, productName: 'Beef Burger', price: 150.0, quantity: 1)];
      final inv1 = Invoice(invoiceNumber: inv1Num, totalAmount: 150.0, subtotalAmount: 150.0, paymentMethod: 'cash', paidAmount: 150.0);
      final inv1Id = await provider.createInvoice(inv1, cart1);

      // Verify Sale #1 COGS
      final savedInv1 = await provider.getInvoiceById(inv1Id);
      expect(savedInv1!.items!.first.costSnapshot, 100.0);

      // 3. Action: New Purchase changing WAC
      // Current: 99kg @ 100.0 (Total: 9900)
      // New: 101kg @ 200.0 (Total: 20200)
      // New WAC: (9900 + 20200) / 200 = 30100 / 200 = 150.5
      final supplierId = await provider.addSupplier(Supplier(name: 'Meat Co'));
      final purchase = PurchaseInvoice(
        supplierId: supplierId,
        invoiceNumber: 'PUR-001',
        totalAmount: 20200.0,
        status: 'paid',
        date: DateTime.now().toIso8601String(),
      );
      final pItems = [
        PurchaseItem(materialId: beefId, quantity: 101.0, unitCost: 200.0, totalCost: 20200.0, unit: 'kg'),
      ];
      await provider.createPurchaseInvoice(purchase, pItems);

      // Verify New WAC
      final materials = await provider.getMaterials();
      final beef = materials.firstWhere((m) => m.id == beefId);
      expect(beef.costPrice, 150.5);

      // 4. Action: Sale #2 (New WAC)
      final inv2Num = await provider.getNextInvoiceNumber();
      final cart2 = [CartItem(productId: productId, productName: 'Beef Burger', price: 150.0, quantity: 1)];
      final inv2 = Invoice(invoiceNumber: inv2Num, totalAmount: 150.0, subtotalAmount: 150.0, paymentMethod: 'cash', paidAmount: 150.0);
      final inv2Id = await provider.createInvoice(inv2, cart2);

      // Verify Sale #2 COGS
      final savedInv2 = await provider.getInvoiceById(inv2Id);
      expect(savedInv2!.items!.first.costSnapshot, 150.5);

      // 5. CRITICAL: Verify Sale #1 COGS is UNCHANGED
      final savedInv1Again = await provider.getInvoiceById(inv1Id);
      expect(savedInv1Again!.items!.first.costSnapshot, 100.0, reason: 'Historical COGS must be immutable');

      // 6. Verify Financial Summary
      final summary = await provider.getProfitAndLossSummary();
      // Revenue: 150 + 150 = 300
      // COGS: 100.0 + 150.5 = 250.5
      // Profit: 300 - 250.5 = 49.5
      expect(summary['totalRevenue'], 300.0);
      expect(summary['cogs'], 250.5);
      expect(summary['grossProfit'], 49.5);
    });
  });
}
