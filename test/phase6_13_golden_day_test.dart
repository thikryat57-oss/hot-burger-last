
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: Golden Restaurant Day E2E Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('Full operational cycle: Purchase -> Production -> Sale -> Audit -> Report', () async {
      // --- 1. PROCUREMENT ---
      final bunId = await provider.addMaterial(MaterialModel(name: 'Bun', type: 'raw', unit: 'piece', quantity: 0, costPrice: 0));
      final meatId = await provider.addMaterial(MaterialModel(name: 'Meat', type: 'raw', unit: 'kg', quantity: 0, costPrice: 0));
      final supplierId = await provider.addSupplier(Supplier(name: 'Main Supplier'));
      
      // Purchase 100 buns @ 1.0 and 10kg meat @ 50.0
      await provider.createPurchaseInvoice(
        PurchaseInvoice(supplierId: supplierId, invoiceNumber: 'P-001', totalAmount: 600.0, status: 'paid', date: '2026-08-21'),
        [
          PurchaseItem(materialId: bunId, quantity: 100.0, unitCost: 1.0, totalCost: 100.0, unit: 'piece'),
          PurchaseItem(materialId: meatId, quantity: 10.0, unitCost: 50.0, totalCost: 500.0, unit: 'kg'),
        ]
      );

      // --- 2. PRODUCTION ---
      final pattyId = await provider.addMaterial(MaterialModel(name: 'Patty', type: 'prepared', unit: 'piece', quantity: 0, costPrice: 0));
      // Recipe for 1 Patty: 0.1kg Meat
      await provider.updateRecipe('material', pattyId, [
        RecipeModel(parentType: 'material', parentId: pattyId, materialId: meatId, quantity: 0.1, unit: 'kg'),
      ]);
      // Produce 50 Patties
      await provider.produceBatch(pattyId, 50.0);
      // Cost per Patty: 0.1 * 50.0 = 5.0
      // Remaining Meat: 10 - (50 * 0.1) = 5kg

      // --- 3. SALES SETUP ---
      final catId = await provider.addCategory(Category(name: 'Main'));
      final burgerId = await provider.addProduct(Product(name: 'Classic Burger', price: 20.0, categoryId: catId));
      // Recipe: 1 Bun + 1 Patty
      await provider.updateRecipe('product', burgerId, [
        RecipeModel(parentType: 'product', parentId: burgerId, materialId: bunId, quantity: 1.0, unit: 'piece'),
        RecipeModel(parentType: 'product', parentId: burgerId, materialId: pattyId, quantity: 1.0, unit: 'piece'),
      ]);

      // --- 4. SALES ACTIONS ---
      // Sale 1: 10 Burgers, 10% discount
      await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-001', subtotalAmount: 200.0, discountAmount: 20.0, totalAmount: 180.0, paymentMethod: 'cash', paidAmount: 200.0, changeAmount: 20.0),
        [CartItem(productId: burgerId, productName: 'Classic Burger', price: 20.0, quantity: 10)]
      );
      // COGS per Burger: (1*1.0) + (1*5.0) = 6.0. Total COGS: 60.0

      // Sale 2: 5 Burgers, no discount
      await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-002', subtotalAmount: 100.0, discountAmount: 0.0, totalAmount: 100.0, paymentMethod: 'card', paidAmount: 100.0, changeAmount: 0.0),
        [CartItem(productId: burgerId, productName: 'Classic Burger', price: 20.0, quantity: 5)]
      );
      // Total COGS: 30.0

      // --- 5. EXPENSES ---
      await provider.addExpense(Expense(name: 'Gas', amount: 50.0, date: '2026-08-21'));

      // --- 6. FINAL RECONCILIATION ---
      // Revenue: 180 + 100 = 280.0
      // COGS: 60 + 30 = 90.0
      // Gross Profit: 280 - 90 = 190.0
      // Expenses: 50.0
      // Net Profit: 190 - 50 = 140.0
      
      final summary = await provider.getProfitAndLossSummary(
        startDate: DateTime(2026, 8, 21),
        endDate: DateTime(2026, 8, 21),
      );
      
      expect(summary['totalRevenue'], 280.0);
      expect(summary['cogs'], 90.0);
      expect(summary['grossProfit'], 190.0);
      expect(summary['totalExpenses'], 50.0);
      expect(summary['netProfit'], 140.0);

      // Inventory Check
      final mats = await provider.getMaterials();
      expect(mats.firstWhere((m) => m.id == bunId).quantity, 85.0); // 100 - 15
      expect(mats.firstWhere((m) => m.id == pattyId).quantity, 35.0); // 50 - 15
      expect(mats.firstWhere((m) => m.id == meatId).quantity, 5.0); // 10 - 5 (production)
    });
  });
}
