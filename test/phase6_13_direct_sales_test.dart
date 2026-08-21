
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: Direct Raw Material Product Sales Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('Sale of product with direct raw material deducts inventory and records COGS correctly', () async {
      // 1. Setup: Add a raw material (Bread)
      final breadId = await provider.addMaterial(MaterialModel(
        name: 'Bread',
        type: 'raw',
        unit: 'piece',
        quantity: 10,
        costPrice: 2.0, // WAC = 2.0
      ));

      // 2. Setup: Add a product (Burger) with a recipe using 1 Bread
      final categoryId = await provider.addCategory(Category(name: 'Burgers'));
      final productId = await provider.addProduct(Product(
        name: 'Single Burger',
        price: 15.0,
        categoryId: categoryId,
      ));

      await provider.updateRecipe('product', productId, [
        RecipeModel(
          parentType: 'product',
          parentId: productId,
          materialId: breadId,
          quantity: 1.0,
          unit: 'piece',
        )
      ]);

      // 3. Action: Sell 2 Burgers
      final invoiceNumber = await provider.getNextInvoiceNumber();
      final cart = [
        CartItem(productId: productId, productName: 'Single Burger', price: 15.0, quantity: 2),
      ];
      
      final invoice = Invoice(
        invoiceNumber: invoiceNumber,
        totalAmount: 30.0,
        subtotalAmount: 30.0,
        discountAmount: 0.0,
        paymentMethod: 'cash',
        paidAmount: 30.0,
        changeAmount: 0.0,
      );

      final invoiceId = await provider.createInvoice(invoice, cart);

      // 4. Verification: Inventory OUT
      final materials = await provider.getMaterials();
      final bread = materials.firstWhere((m) => m.id == breadId);
      expect(bread.quantity, 8.0, reason: 'Inventory should decrease by 2 (1 bread per burger * 2 burgers)');

      // 5. Verification: COGS and Profit in Database
      final savedInvoice = await provider.getInvoiceById(invoiceId);
      expect(savedInvoice, isNotNull);
      expect(savedInvoice!.items!.length, 1);
      
      final item = savedInvoice.items!.first;
      expect(item.costSnapshot, 2.0, reason: 'Cost snapshot should be the WAC of bread at sale time');
      expect(item.unitProfit, 13.0, reason: 'Unit profit = 15.0 - 2.0 = 13.0');
      expect(item.totalProfit, 26.0, reason: 'Total profit = 13.0 * 2 = 26.0');

      // 6. Verification: Financial Summary (COGS)
      final summary = await provider.getProfitAndLossSummary();
      expect(summary['totalRevenue'], 30.0);
      expect(summary['cogs'], 4.0, reason: 'COGS = 2 pieces * 2.0 cost = 4.0');
      expect(summary['grossProfit'], 26.0);
    });
  });
}
