import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  Database? _db;
  User? _currentUser;
  bool _isLoggedIn = false;
  int _currentIndex = 0;

  bool get isLoggedIn => _isLoggedIn;
  User? get currentUser => _currentUser;
  int get currentIndex => _currentIndex;

  Future<void> initDatabase() async {
    _db = await DatabaseHelper.database;
  }

  // Authentication
  Future<bool> login(String password) async {
    final results = await _db!.query('users', where: 'password = ?', whereArgs: [password]);
    if (results.isNotEmpty) {
      _currentUser = User.fromMap(results.first);
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // Category CRUD
  Future<int> addCategory(Category category) async {
    final now = DateTime.now().toIso8601String();
    final result = await _db!.insert('categories', {
      ...category.toMap(),
      'created_at': now,
      'updated_at': now,
    });
    notifyListeners();
    return result;
  }

  Future<List<Category>> getCategories() async {
    final results = await _db!.query('categories', orderBy: 'created_at DESC');
    return results.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final result = await _db!.update('categories', {
      ...category.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [category.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteCategory(int id) async {
    final result = await _db!.delete('categories', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // Product CRUD
  Future<int> addProduct(Product product) async {
    final now = DateTime.now().toIso8601String();
    final result = await _db!.insert('products', {
      ...product.toMap(),
      'created_at': now,
      'updated_at': now,
    });
    notifyListeners();
    return result;
  }

  Future<List<Product>> getProducts() async {
    final results = await _db!.rawQuery(
      'SELECT p.*, c.name as category_name FROM products p LEFT JOIN categories c ON p.category_id = c.id ORDER BY p.created_at DESC'
    );
    return results.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final result = await _db!.update('products', {
      ...product.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [product.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteProduct(int id) async {
    final result = await _db!.delete('products', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // Invoice CRUD
  Future<int> createInvoice(Invoice invoice, List<CartItem> items) async {
    // Step 1: Gather required raw materials and check stock
    final Map<int, double> requiredIngredients = {}; // ingredientId -> total needed
    final Map<int, String> ingredientNames = {}; // ingredientId -> name

    for (var item in items) {
      final links = await DatabaseHelper.getProductIngredients(item.productId);
      for (var link in links) {
        final ingId = link['ingredient_id'] as int;
        final perUnit = (link['quantity'] as num).toDouble();
        final totalNeeded = perUnit * item.quantity;
        ingredientNames[ingId] = link['ingredient_name'] as String;
        requiredIngredients[ingId] = (requiredIngredients[ingId] ?? 0) + totalNeeded;
      }
    }

    // Step 2: Verify stock sufficiency
    for (var entry in requiredIngredients.entries) {
      final ingredientId = entry.key;
      final needed = entry.value;
      final stock = await DatabaseHelper.getIngredientById(ingredientId);
      if (stock.isEmpty) {
        throw Exception('المادة الخام "${ingredientNames[ingredientId] ?? 'غير معروفة'}" غير موجودة في المخزون');
      }
      final available = (stock.first['quantity'] as num).toDouble();
      if (available < needed) {
        throw Exception('المادة الخام "${ingredientNames[ingredientId]}" غير كافية لإتمام الطلب (متوفر: $available، مطلوب: $needed)');
      }
    }

    // Step 3: Save invoice
    final now = DateTime.now().toIso8601String();
    final invoiceId = await _db!.insert('invoices', {
      'invoice_number': invoice.invoiceNumber,
      'total_amount': invoice.totalAmount,
      'status': invoice.status,
      'payment_method': invoice.paymentMethod,
      'notes': invoice.notes,
      'created_at': now,
    });

    for (var item in items) {
      await _db!.insert('invoice_items', {
        'invoice_id': invoiceId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'price': item.price,
        'total': item.total,
      });
    }

    // Step 4: Deduct raw materials from inventory
    for (var entry in requiredIngredients.entries) {
      final ingredientId = entry.key;
      final needed = entry.value;
      await DatabaseHelper.updateIngredientQuantity(ingredientId, -needed);
    }

    // Step 5: Check for low stock alerts
    final lowStockIngredients = await DatabaseHelper.getLowStockIngredients();
    final lowStockNames = lowStockIngredients.map((e) => e['name'] as String).toList();

    notifyListeners();

    // Return invoiceId and low stock names (stored in invoice notes)
    if (lowStockNames.isNotEmpty) {
      await _db!.update('invoices', {
        'notes': 'تحذير: ${lowStockNames.join('، ')}',
      }, where: 'id = ?', whereArgs: [invoiceId]);
    }

    return invoiceId;
  }

  Future<List<Invoice>> getInvoices() async {
    final results = await _db!.query('invoices', orderBy: 'created_at DESC');
    return results.map((e) => Invoice.fromMap(e)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final results = await _db!.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    final invoice = Invoice.fromMap(results.first);

    final items = await _db!.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    final invoiceItems = items.map((e) => InvoiceItem.fromMap(e)).toList();
    return Invoice(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      totalAmount: invoice.totalAmount,
      status: invoice.status,
      notes: invoice.notes,
      createdAt: invoice.createdAt,
      items: invoiceItems,
    );
  }

  Future<List<Invoice>> searchInvoices(String query) async {
    final results = await _db!.query(
      'invoices',
      where: 'invoice_number LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return results.map((e) => Invoice.fromMap(e)).toList();
  }

  Future<int> deleteInvoice(int id) async {
    // Restore stock: re-add deducted quantities before deleting
    final items = await _db!.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    for (var item in items) {
      final productId = item['product_id'] as int;
      final soldQty = item['quantity'] as int;
      final links = await DatabaseHelper.getProductIngredients(productId);
      for (var link in links) {
        final ingredientId = link['ingredient_id'] as int;
        final perUnit = (link['quantity'] as num).toDouble();
        await DatabaseHelper.updateIngredientQuantity(ingredientId, perUnit * soldQty);
      }
    }
    await _db!.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    final result = await _db!.delete('invoices', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // Expense CRUD
  Future<int> addExpense(Expense expense) async {
    final result = await _db!.insert('expenses', {
      ...expense.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    return result;
  }

  Future<List<Expense>> getExpenses() async {
    final results = await _db!.query('expenses', orderBy: 'date DESC');
    return results.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final result = await _db!.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteExpense(int id) async {
    final result = await _db!.delete('expenses', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // Reports
  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final salesResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE DATE(created_at) = ?',
      [date],
    );
    final expenseResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date = ?',
      [date],
    );

    final totalSales = (salesResult.first['total'] is num) ? (salesResult.first['total'] as num).toDouble() : 0.0;
    final invoiceCount = (salesResult.first['count'] is num) ? salesResult.first['count'] as int : 0;
    final totalExpenses = (expenseResult.first['total'] is num) ? (expenseResult.first['total'] as num).toDouble() : 0.0;

    return {
      'totalSales': totalSales,
      'invoiceCount': invoiceCount,
      'totalExpenses': totalExpenses,
      'netProfit': totalSales - totalExpenses,
    };
  }

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    final salesResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE strftime(\'%Y\', created_at) = ? AND strftime(\'%m\', created_at) = ?',
      ['${year}', month.toString().padLeft(2, '0')],
    );
    final expenseResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE strftime(\'%Y\', date) = ? AND strftime(\'%m\', date) = ?',
      ['${year}', month.toString().padLeft(2, '0')],
    );

    final totalSales = (salesResult.first['total'] is num) ? (salesResult.first['total'] as num).toDouble() : 0.0;
    final invoiceCount = (salesResult.first['count'] is num) ? salesResult.first['count'] as int : 0;
    final totalExpenses = (expenseResult.first['total'] is num) ? (expenseResult.first['total'] as num).toDouble() : 0.0;

    return {
      'totalSales': totalSales,
      'invoiceCount': invoiceCount,
      'totalExpenses': totalExpenses,
      'netProfit': totalSales - totalExpenses,
    };
  }

  // ==================== SHIFT SUMMARY ====================

  Future<Map<String, dynamic>> getShiftSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    // Total sales & count
    final totalResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE DATE(created_at) BETWEEN ? AND ?',
      [startStr, endStr],
    );
    final totalSales = (totalResult.first['total'] is num) ? (totalResult.first['total'] as num).toDouble() : 0.0;
    final invoiceCount = (totalResult.first['count'] is num) ? totalResult.first['count'] as int : 0;

    // Cash
    final cashResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ?',
      ['cash', startStr, endStr],
    );
    final cashTotal = (cashResult.first['total'] is num) ? (cashResult.first['total'] as num).toDouble() : 0.0;

    // Bank
    final bankResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ?',
      ['bank', startStr, endStr],
    );
    final bankTotal = (bankResult.first['total'] is num) ? (bankResult.first['total'] as num).toDouble() : 0.0;

    // Card
    final cardResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ?',
      ['card', startStr, endStr],
    );
    final cardTotal = (cardResult.first['total'] is num) ? (cardResult.first['total'] as num).toDouble() : 0.0;

    return {
      'totalSales': totalSales,
      'cashTotal': cashTotal,
      'bankTotal': bankTotal,
      'cardTotal': cardTotal,
      'invoiceCount': invoiceCount,
    };
  }

  // ==================== PROFIT & LOSS ====================

  Future<Map<String, dynamic>> getProfitAndLossSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    // Total Revenue
    final revenueResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE DATE(created_at) BETWEEN ? AND ?',
      [startStr, endStr],
    );
    final totalRevenue = (revenueResult.first['total'] is num) ? (revenueResult.first['total'] as num).toDouble() : 0.0;

    // COGS: sum of (invoice_items.quantity * product_ingredients.quantity * inventory.cost_price)
    final cogsResult = await _db!.rawQuery('''
      SELECT COALESCE(SUM(ii.quantity * pi.quantity * inv.cost_price), 0) as cogs
      FROM invoice_items ii
      INNER JOIN invoices inv_t ON ii.invoice_id = inv_t.id
      INNER JOIN product_ingredients pi ON ii.product_id = pi.product_id
      INNER JOIN inventory inv ON pi.ingredient_id = inv.id
      WHERE DATE(inv_t.created_at) BETWEEN ? AND ?
    ''', [startStr, endStr]);
    final cogs = (cogsResult.first['cogs'] is num) ? (cogsResult.first['cogs'] as num).toDouble() : 0.0;

    final grossProfit = totalRevenue - cogs;
    final profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
    };
  }

  // Navigation
  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // ==================== INVENTORY CRUD ====================

  Future<int> addIngredient(IngredientModel ingredient) async {
    final result = await DatabaseHelper.insertIngredient(ingredient.toMap());
    notifyListeners();
    return result;
  }

  Future<List<IngredientModel>> getIngredients() async {
    final results = await DatabaseHelper.getIngredients();
    return results.map((e) => IngredientModel.fromMap(e)).toList();
  }

  Future<List<IngredientModel>> getLowStockIngredients() async {
    final results = await DatabaseHelper.getLowStockIngredients();
    return results.map((e) => IngredientModel.fromMap(e)).toList();
  }

  Future<int> updateIngredient(IngredientModel ingredient) async {
    final result = await DatabaseHelper.updateIngredient(ingredient.id!, ingredient.toMap());
    notifyListeners();
    return result;
  }

  Future<int> deleteIngredient(int id) async {
    final result = await DatabaseHelper.deleteIngredient(id);
    notifyListeners();
    return result;
  }

  // Record a purchase: increase ingredient quantity
  Future<void> recordPurchase(int ingredientId, double purchasedQuantity, double cost) async {
    await DatabaseHelper.updateIngredient(ingredientId, {
      'quantity': null, // will be incremented via rawUpdate
    });
    await DatabaseHelper.updateIngredientQuantity(ingredientId, purchasedQuantity);
    // Update cost price if provided
    if (cost > 0) {
      await DatabaseHelper.updateIngredient(ingredientId, {'cost_price': cost});
    }
    notifyListeners();
  }

  // ==================== PRODUCT-INGREDIENTS (RECIPE) ====================

  Future<int> addProductIngredient(ProductIngredient link) async {
    final result = await DatabaseHelper.insertProductIngredient(link.toMap());
    await updateProductCost(link.productId);
    notifyListeners();
    return result;
  }

  Future<List<Map<String, dynamic>>> getProductIngredients(int productId) async {
    return await DatabaseHelper.getProductIngredients(productId);
  }

  Future<int> deleteProductIngredient(int productId, int ingredientId) async {
    final result = await DatabaseHelper.deleteProductIngredient(productId, ingredientId);
    await updateProductCost(productId);
    notifyListeners();
    return result;
  }

  Future<int> deleteAllProductIngredients(int productId) async {
    final result = await DatabaseHelper.deleteAllProductIngredients(productId);
    await updateProductCost(productId);
    notifyListeners();
    return result;
  }

  Future<void> deductProductIngredients(int productId, int soldQuantity) async {
    await DatabaseHelper.deductProductIngredients(productId, soldQuantity);
    notifyListeners();
  }

  Future<void> updateProductCost(int productId) async {
    final ingredients = await DatabaseHelper.getProductIngredients(productId);
    double totalCost = 0;
    for (var item in ingredients) {
      final qty = (item['quantity'] as num).toDouble();
      final costPrice = await _db!.query('inventory',
          columns: ['cost_price'], where: 'id = ?', whereArgs: [item['ingredient_id']]);
      if (costPrice.isNotEmpty) {
        totalCost += qty * (costPrice.first['cost_price'] as num).toDouble();
      }
    }
    await _db!.update('products', {'cost': totalCost},
        where: 'id = ?', whereArgs: [productId]);
  }
}
