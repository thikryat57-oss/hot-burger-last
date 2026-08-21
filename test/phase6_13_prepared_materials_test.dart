
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_burger_last/providers/app_provider.dart';
import 'package:hot_burger_last/models/models.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'helpers/db_integration_helpers.dart';

void main() {
  group('Phase 6.13: Prepared Materials and Multi-level Recipe Sales Test', () {
    late AppProvider provider;

    setUp(() async {
      final db = await openIntegrationTestDatabase();
      DatabaseHelper.useTestDatabase(db);
      provider = await openTestProvider(db);
    });

    test('Sale of product with prepared material (multi-level) calculates COGS and deducts stock correctly', () async {
      // 1. Setup Raw Materials
      final eggId = await provider.addMaterial(MaterialModel(name: 'Egg', type: 'raw', unit: 'piece', quantity: 100, costPrice: 0.5));
      final oilId = await provider.addMaterial(MaterialModel(name: 'Oil', type: 'raw', unit: 'ml', quantity: 1000, costPrice: 0.02));

      // 2. Setup Prepared Material (Mayonnaise)
      final mayoId = await provider.addMaterial(MaterialModel(
        name: 'Mayonnaise',
        type: 'prepared',
        unit: 'ml',
        quantity: 0, // Initially 0
        costPrice: 0, // Initially 0, will be calculated from production
      ));

      // Recipe for Mayonnaise: 0.01 Egg + 1ml Oil = 1ml Mayo
      await provider.updateRecipe('material', mayoId, [
        RecipeModel(parentType: 'material', parentId: mayoId, materialId: eggId, quantity: 0.01, unit: 'piece'),
        RecipeModel(parentType: 'material', parentId: mayoId, materialId: oilId, quantity: 1.0, unit: 'ml'),
      ]);

      // 3. Produce Mayonnaise
      // Cost: (1 * 0.5) + (100 * 0.02) = 0.5 + 2.0 = 2.5 per 100ml => 0.025 per ml
      await provider.produceBatch(mayoId, 200.0); // Produces 200ml

      // Verify production: Eggs should be 98, Oil should be 800, Mayo should be 200
      final materialsAfterProduction = await provider.getMaterials();
      expect(materialsAfterProduction.firstWhere((m) => m.id == eggId).quantity, 98.0);
      expect(materialsAfterProduction.firstWhere((m) => m.id == oilId).quantity, 800.0);
      expect(materialsAfterProduction.firstWhere((m) => m.id == mayoId).quantity, 200.0);
      expect(materialsAfterProduction.firstWhere((m) => m.id == mayoId).costPrice, 0.025);

      // 4. Setup Product (Mayo Burger)
      final categoryId = await provider.addCategory(Category(name: 'Burgers'));
      final productId = await provider.addProduct(Product(name: 'Mayo Burger', price: 20.0, categoryId: categoryId));
      
      // Recipe: 20ml Mayo + 1 Bread (direct raw)
      final breadId = await provider.addMaterial(MaterialModel(name: 'Bread', type: 'raw', unit: 'piece', quantity: 10, costPrice: 2.0));
      await provider.updateRecipe('product', productId, [
        RecipeModel(parentType: 'product', parentId: productId, materialId: mayoId, quantity: 20.0, unit: 'ml'),
        RecipeModel(parentType: 'product', parentId: productId, materialId: breadId, quantity: 1.0, unit: 'piece'),
      ]);

      // 5. Action: Sell 2 Mayo Burgers
      // Expected Mayo OUT: 40ml
      // Expected Bread OUT: 2 pieces
      // Expected COGS per Burger: (20 * 0.025) + (1 * 2.0) = 0.5 + 2.0 = 2.5
      // Expected Total COGS: 5.0
      
      final invoiceNumber = await provider.getNextInvoiceNumber();
      final cart = [CartItem(productId: productId, productName: 'Mayo Burger', price: 20.0, quantity: 2)];
      final invoice = Invoice(
        invoiceNumber: invoiceNumber,
        totalAmount: 40.0,
        subtotalAmount: 40.0,
        discountAmount: 0.0,
        paymentMethod: 'cash',
        paidAmount: 40.0,
        changeAmount: 0.0,
      );

      final invoiceId = await provider.createInvoice(invoice, cart);

      // 6. Verification
      final finalMaterials = await provider.getMaterials();
      expect(finalMaterials.firstWhere((m) => m.id == mayoId).quantity, 160.0, reason: 'Mayo should decrease by 40ml');
      expect(finalMaterials.firstWhere((m) => m.id == breadId).quantity, 8.0, reason: 'Bread should decrease by 2 pieces');
      expect(finalMaterials.firstWhere((m) => m.id == eggId).quantity, 98.0, reason: 'Eggs should NOT decrease again (Double consumption check)');
      
      final savedInvoice = await provider.getInvoiceById(invoiceId);
      expect(savedInvoice!.items!.first.costSnapshot, 2.5);
      
      final summary = await provider.getProfitAndLossSummary();
      expect(summary['cogs'], 5.0);
      expect(summary['grossProfit'], 35.0);
    });
  });
}
