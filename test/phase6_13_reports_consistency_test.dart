
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: Financial Reports Consistency Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('Financial summary (P&L) matches independent calculation from invoices and expenses', () async {
      // 1. Setup Data
      final matId = await provider.addMaterial(MaterialModel(name: 'Ingredient', type: 'raw', unit: 'unit', quantity: 100, costPrice: 10.0));
      final catId = await provider.addCategory(Category(name: 'Cat'));
      final prodId = await provider.addProduct(Product(name: 'Prod', price: 50.0, categoryId: catId));
      await provider.updateRecipe('product', prodId, [RecipeModel(parentType: 'product', parentId: prodId, materialId: matId, quantity: 1.0, unit: 'unit')]);

      // 2. Action: 3 Sales with different payments and discounts
      // Sale 1: 2 units, no discount, cash
      await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-001', totalAmount: 100.0, subtotalAmount: 100.0, discountAmount: 0.0, paymentMethod: 'cash', paidAmount: 100.0),
        [CartItem(productId: prodId, productName: 'Prod', price: 50.0, quantity: 2)]
      );

      // Sale 2: 1 unit, 10.0 discount, card
      await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-002', totalAmount: 40.0, subtotalAmount: 50.0, discountAmount: 10.0, paymentMethod: 'card', paidAmount: 40.0),
        [CartItem(productId: prodId, productName: 'Prod', price: 50.0, quantity: 1)]
      );

      // Sale 3: 1 unit, no discount, transfer
      await provider.createInvoice(
        Invoice(invoiceNumber: 'INV-003', totalAmount: 50.0, subtotalAmount: 50.0, discountAmount: 0.0, paymentMethod: 'transfer', paidAmount: 50.0),
        [CartItem(productId: prodId, productName: 'Prod', price: 50.0, quantity: 1)]
      );

      // 3. Action: Add Expenses
      final todayDateOnly = DateTime.now().toIso8601String().substring(0, 10);
      await provider.addExpense(Expense(name: 'Rent', amount: 30.0, date: todayDateOnly));
      await provider.addExpense(Expense(name: 'Electricity', amount: 20.0, date: todayDateOnly));

      // 4. Independent Calculation
      // Revenue: 100 + 40 + 50 = 190.0
      // COGS: (2*10) + (1*10) + (1*10) = 40.0
      // Gross Profit: 190 - 40 = 150.0
      // Expenses: 30 + 20 = 50.0
      // Net Profit: 150 - 50 = 100.0
      
      // 5. Verification: Profit & Loss Summary
      final pl = await provider.getProfitAndLossSummary();
      expect(pl['totalRevenue'], 190.0);
      expect(pl['cogs'], 40.0);
      expect(pl['grossProfit'], 150.0);
      expect(pl['totalExpenses'], 50.0);
      expect(pl['netProfit'], 100.0);

      // 6. Verification: Daily Report
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final daily = await provider.getDailyReport(todayStr);
      expect(daily['totalSales'], 190.0);
      expect(daily['totalExpenses'], 50.0);
      expect(daily['netProfit'], 100.0);

      // 7. Verification: Business Intelligence
      final bi = await provider.getBusinessIntelligence(
        start: DateTime.now(),
        end: DateTime.now(),
      );
      expect(bi['sales'], 190.0);
      expect(bi['grossProfit'], 150.0);
      expect(bi['expenses'], 50.0);
      expect(bi['netProfit'], 100.0);
      
      // Verification: Payment splits
      final paymentList = bi['payment'] as List<dynamic>;
      expect(paymentList.firstWhere((e) => e['name'] == 'نقدًا')['amount'], 100.0);
      expect(paymentList.firstWhere((e) => e['name'] == 'بطاقة')['amount'], 40.0);
      expect(paymentList.firstWhere((e) => e['name'] == 'تحويل')['amount'], 50.0);
    });
  });
}
