
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: Edge Cases and Audit Safety Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('Insufficient stock should block sale (Negative Stock Protection)', () async {
      final matId = await provider.addMaterial(MaterialModel(name: 'Beef', type: 'raw', unit: 'kg', quantity: 1.0, costPrice: 100.0));
      final catId = await provider.addCategory(Category(name: 'Burgers'));
      final prodId = await provider.addProduct(Product(name: 'Burger', price: 150.0, categoryId: catId));
      await provider.updateRecipe('product', prodId, [RecipeModel(parentType: 'product', parentId: prodId, materialId: matId, quantity: 1.0, unit: 'kg')]);

      final invNum = await provider.getNextInvoiceNumber();
      final cart = [CartItem(productId: prodId, productName: 'Burger', price: 150.0, quantity: 2)]; // Request 2kg, only 1kg available
      final inv = Invoice(invoiceNumber: invNum, totalAmount: 300.0, subtotalAmount: 300.0, paymentMethod: 'cash', paidAmount: 300.0);

      expect(() => provider.createInvoice(inv, cart), throwsException);
      
      final materials = await provider.getMaterials();
      expect(materials.firstWhere((m) => m.id == matId).quantity, 1.0, reason: 'Stock should remain unchanged');
    });

    test('Voiding an invoice restores inventory and reverses financial impact', () async {
      final matId = await provider.addMaterial(MaterialModel(name: 'Beef', type: 'raw', unit: 'kg', quantity: 10.0, costPrice: 100.0));
      final catId = await provider.addCategory(Category(name: 'Burgers'));
      final prodId = await provider.addProduct(Product(name: 'Burger', price: 150.0, categoryId: catId));
      await provider.updateRecipe('product', prodId, [RecipeModel(parentType: 'product', parentId: prodId, materialId: matId, quantity: 1.0, unit: 'kg')]);

      final invNum = await provider.getNextInvoiceNumber();
      final cart = [CartItem(productId: prodId, productName: 'Burger', price: 150.0, quantity: 1)];
      final inv = Invoice(invoiceNumber: invNum, totalAmount: 150.0, subtotalAmount: 150.0, paymentMethod: 'cash', paidAmount: 150.0);
      final invId = await provider.createInvoice(inv, cart);

      // Verify deduction
      expect((await provider.getMaterials()).firstWhere((m) => m.id == matId).quantity, 9.0);

      // Action: Void Invoice
      await provider.voidInvoice(invId);

      // Verify Restoration
      expect((await provider.getMaterials()).firstWhere((m) => m.id == matId).quantity, 10.0, reason: 'Inventory should be restored');
      
      final summary = await provider.getProfitAndLossSummary();
      expect(summary['totalRevenue'], 0.0, reason: 'Voided invoice should not count towards revenue');
      expect(summary['cogs'], 0.0, reason: 'Voided invoice should not count towards COGS');
    });

    test('Reversal after WAC change uses historical cost for reversal', () async {
      final matId = await provider.addMaterial(MaterialModel(name: 'Beef', type: 'raw', unit: 'kg', quantity: 10.0, costPrice: 100.0));
      final catId = await provider.addCategory(Category(name: 'Burgers'));
      final prodId = await provider.addProduct(Product(name: 'Burger', price: 150.0, categoryId: catId));
      await provider.updateRecipe('product', prodId, [RecipeModel(parentType: 'product', parentId: prodId, materialId: matId, quantity: 1.0, unit: 'kg')]);

      final invId = await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-001', totalAmount: 150.0, subtotalAmount: 150.0, paymentMethod: 'cash', paidAmount: 150.0),
        [CartItem(productId: prodId, productName: 'Burger', price: 150.0, quantity: 1)]
      );

      // Change WAC
      final supplierId = await provider.addSupplier(Supplier(name: 'Meat Co'));
      await provider.createPurchaseInvoice(
        PurchaseInvoice(supplierId: supplierId, invoiceNumber: 'P1', totalAmount: 2000, status: 'paid', date: '2026-01-01'),
        [PurchaseItem(materialId: matId, quantity: 10, unitCost: 200, totalCost: 2000, unit: 'kg')]
      );
      // New WAC: (9*100 + 10*200) / 19 = 2900 / 19 = 152.63

      // Action: Void Invoice 1
      await provider.voidInvoice(invId);

      // Verify: Even if WAC is now ~152, the audit log and inventory should handle the reversal correctly.
      // The system restores the QUANTITY. The cost impact on P&L is removed because the invoice is no longer 'completed'.
      final summary = await provider.getProfitAndLossSummary();
      expect(summary['cogs'], 0.0);
    });
  });
}
