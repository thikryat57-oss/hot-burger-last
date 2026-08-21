import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/utils/recipe_engine.dart';
import '../models/models.dart';

class AppProvider with ChangeNotifier {
  Database? _db;
  User? _currentUser;
  bool _isLoggedIn = false;
  Shift? _currentShift;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  Shift? get currentShift => _currentShift;

  bool get isManager => _currentUser?.role == 'manager';

  AppProvider() {
    initDatabase();
  }

  Future<void> initDatabase() async {
    _db = await DatabaseHelper.database;
    notifyListeners();
  }

  // Auth
  Future<bool> login(String password, {int? userId}) async {
    _db ??= await DatabaseHelper.database;
    final results = await _db!.query(
      'users',
      where: userId != null ? 'id = ? AND password = ?' : 'password = ?',
      whereArgs: userId != null ? [userId, password] : [password],
    );

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

  bool canManageCatalog() => isManager;
  bool canManageFinance() => isManager;
  bool canManageUsers() => isManager;
  bool canVoidInvoice() => isManager;

  // Shift Management
  Future<void> openShift(double openingBalance) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    final now = DateTime.now().toIso8601String();
    final id = await _db!.insert('shifts', {
      'user_id': _currentUser!.id,
      'opened_at': now,
      'opening_balance': openingBalance,
      'status': 'open',
    });
    _currentShift = Shift(
      id: id,
      userId: _currentUser!.id!,
      userName: _currentUser!.name,
      openedAt: now,
      openingBalance: openingBalance,
      status: 'open',
    );
    notifyListeners();
  }

  Future<void> closeShift(double closingBalance, {String? notes}) async {
    if (_currentShift == null) return;
    final now = DateTime.now().toIso8601String();
    await _db!.update('shifts', {
      'closed_at': now,
      'closing_balance': closingBalance,
      'status': 'closed',
      'notes': notes,
    }, where: 'id = ?', whereArgs: [_currentShift!.id]);
    _currentShift = null;
    notifyListeners();
  }

  Future<Shift?> getCurrentUserOpenShift() async {
    if (!isLoggedIn) return null;
    final rows = await _db!.query(
      'shifts',
      where: 'user_id = ? AND status = ?',
      whereArgs: [_currentUser!.id, 'open'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }

  // Category CRUD
  Future<int> addCategory(Category category) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final now = DateTime.now().toIso8601String();
    final result = await _db!.insert('categories', {
      'name': category.name,
      'description': category.description,
      'is_active': category.isActive ? 1 : 0,
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
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.update('categories', {
      'name': category.name,
      'description': category.description,
      'is_active': category.isActive ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [category.id]);
    notifyListeners();
    return result;
  }

  // Product CRUD
  Future<int> addProduct(Product product) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final now = DateTime.now().toIso8601String();
    final result = await _db!.insert('products', {
      'name': product.name,
      'category_id': product.categoryId,
      'price': product.price,
      'cost': product.cost,
      'description': product.description,
      'image_path': product.imagePath,
      'is_available': product.isAvailable ? 1 : 0,
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

  Future<int> deleteProduct(int id, {String? reason}) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteProductSafe(
      id,
      userId: _currentUser?.id,
      userName: _currentUser?.name,
      reason: reason,
    );
    notifyListeners();
    return result;
  }

  Future<int> deleteProductIngredient(int productId, int ingredientId, {String? reason}) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteProductIngredientSafe(
      productId,
      ingredientId,
      userId: _currentUser?.id,
      userName: _currentUser?.name,
      reason: reason,
    );
    notifyListeners();
    return result;
  }

  // ==================== MATERIALS & INVENTORY ====================

  Future<int> addMaterial(MaterialModel material) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final now = DateTime.now().toIso8601String();
    final data = material.toMap();
    data['created_at'] = now;
    data['updated_at'] = now;
    final id = await _db!.insert('materials', data);
    
    await _db!.insert('inventory_audit_log', {
      'action_date': now,
      'action_type': 'material_created',
      'ingredient_id': id,
      'ingredient_name': material.name,
      'quantity_before': 0,
      'quantity_change': material.quantity,
      'quantity_after': material.quantity,
      'cost_price_at_action': material.costPrice,
      'reference_type': 'manual',
      'note': jsonEncode(DatabaseHelper.actorNoteForInventory(_currentUser?.id, _currentUser?.name, noteText: 'إضافة مادة جديدة')),
    });
    
    notifyListeners();
    return id;
  }

  Future<List<MaterialModel>> getMaterials() async {
    final results = await _db!.query('materials', orderBy: 'name ASC');
    return results.map((e) => MaterialModel.fromMap(e)).toList();
  }

  Future<int> updateMaterial(MaterialModel material) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.update(
      'materials',
      {...material.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [material.id],
    );
    notifyListeners();
    return result;
  }

  Future<int> deleteMaterialSafe(int id, {bool force = false, String? reason}) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    try {
      final r = await DatabaseHelper.deleteMaterialSafe(
        id,
        force: force,
        userId: _currentUser?.id,
        userName: _currentUser?.name,
        reason: reason,
      );
      notifyListeners();
      return r;
    } on SafeDeleteBlockedException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Map<String, dynamic>> getMaterialImpact(int id) async {
    return await DatabaseHelper.getMaterialImpact(id);
  }

  Future<List<MaterialModel>> getLowStockMaterials() async {
    final results = await _db!.query('materials', where: 'quantity <= min_quantity');
    return results.map((e) => MaterialModel.fromMap(e)).toList();
  }

  // ==================== RECIPES ====================

  Future<void> updateRecipe(String parentType, int parentId, List<RecipeModel> items) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    await _db!.transaction((txn) async {
      await txn.delete('recipes', where: 'parent_type = ? AND parent_id = ?', whereArgs: [parentType, parentId]);
      for (var item in items) {
        await txn.insert('recipes', {
          'parent_type': parentType,
          'parent_id': parentId,
          'material_id': item.materialId,
          'quantity': item.quantity,
          'unit': item.unit,
        });
      }
      if (parentType == 'product') {
        await DatabaseHelper.recalculateProductCostsForIngredient(txn, -1, isFullProductRecalc: true, targetProductId: parentId);
      } else if (parentType == 'material') {
        await DatabaseHelper.recalculateProductCostsForIngredient(txn, parentId);
      }
    });
    notifyListeners();
  }

  Future<List<RecipeModel>> getRecipes(String parentType, int parentId) async {
    final results = await _db!.query('recipes', where: 'parent_type = ? AND parent_id = ?', whereArgs: [parentType, parentId]);
    return results.map((e) => RecipeModel.fromMap(e)).toList();
  }

  // ==================== PRODUCTION ====================

  Future<void> produceBatch(int materialId, double quantity, {String? notes}) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    final now = DateTime.now().toIso8601String();
    await _db!.transaction((txn) async {
      final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [materialId]);
      if (matRows.isEmpty) throw Exception('المادة غير موجودة');
      final material = MaterialModel.fromMap(matRows.first);
      
      final allMaterialsRows = await txn.query('materials');
      final allMaterials = {for (var m in allMaterialsRows) m['id'] as int: MaterialModel.fromMap(m)};
      final allRecipesRows = await txn.query('recipes');
      final allRecipes = <int, List<RecipeModel>>{};
      for (var r in allRecipesRows) {
        final pid = r['parent_id'] as int;
        allRecipes[pid] ??= [];
        allRecipes[pid]!.add(RecipeModel.fromMap(r));
      }

      final expanded = RecipeEngine.expandRecipe(
        parentType: 'material',
        parentId: materialId,
        allRecipes: allRecipes,
        allMaterials: allMaterials,
        multiplier: quantity,
      );

      for (var entry in expanded.entries) {
        final compId = entry.key;
        final compQty = entry.value;
        final comp = allMaterials[compId]!;
        if (comp.quantity < compQty) throw Exception('نقص في المكون: ${comp.name}');
        
        await txn.rawUpdate('UPDATE materials SET quantity = quantity - ? WHERE id = ?', [compQty, compId]);
        await txn.insert('inventory_audit_log', {
          'action_date': now,
          'action_type': 'production_consumption',
          'ingredient_id': compId,
          'ingredient_name': comp.name,
          'quantity_before': comp.quantity,
          'quantity_change': -compQty,
          'quantity_after': comp.quantity - compQty,
          'cost_price_at_action': comp.costPrice,
          'reference_type': 'production',
          'note': jsonEncode(DatabaseHelper.actorNoteForInventory(_currentUser?.id, _currentUser?.name, noteText: 'إنتاج ${material.name}')),
        });
      }

      final unitCost = RecipeEngine.calculatePreparedMaterialCost(materialId: materialId, allRecipes: allRecipes, allMaterials: allMaterials);
      final newQty = material.quantity + quantity;
      final newWac = RecipeEngine.calculateWAC(
        currentQty: material.quantity,
        currentAvgCost: material.costPrice,
        newQty: quantity,
        newBatchCost: unitCost,
      );

      await txn.update('materials', {'quantity': newQty, 'cost_price': newWac, 'updated_at': now}, where: 'id = ?', whereArgs: [materialId]);
      await txn.insert('production_batches', {
        'material_id': materialId,
        'quantity': quantity,
        'unit_cost': unitCost,
        'total_cost': unitCost * quantity,
        'notes': notes,
        'created_at': now,
      });
      
      await txn.insert('inventory_audit_log', {
        'action_date': now,
        'action_type': 'production_output',
        'ingredient_id': materialId,
        'ingredient_name': material.name,
        'quantity_before': material.quantity,
        'quantity_change': quantity,
        'quantity_after': newQty,
        'cost_price_at_action': newWac,
        'reference_type': 'production',
        'note': jsonEncode(DatabaseHelper.actorNoteForInventory(_currentUser?.id, _currentUser?.name, noteText: notes)),
      });
      
      await DatabaseHelper.recalculateProductCostsForIngredient(txn, materialId);
    });
    notifyListeners();
  }

  // ==================== PROCUREMENT ====================

  Future<int> addSupplier(Supplier supplier) async {
    final id = await _db!.insert('suppliers', supplier.toMap());
    notifyListeners();
    return id;
  }

  Future<List<Supplier>> getSuppliers() async {
    final results = await _db!.query('suppliers', orderBy: 'name ASC');
    return results.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<int> createPurchaseInvoice(PurchaseInvoice invoice, List<PurchaseItem> items) async {
    final id = await DatabaseHelper.insertPurchaseInvoice(invoice, items, userId: _currentUser?.id, userName: _currentUser?.name);
    notifyListeners();
    return id;
  }

  // ==================== SALES ====================

  static String encodeRecipeSnapshot(List<Map<String, dynamic>>? rows) {
    if (rows == null || rows.isEmpty) return '[]';
    final safe = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id'] as int?;
      final qty = (row['qty'] as num?)?.toDouble() ?? 0.0;
      if (id == null || !qty.isFinite || qty < 0) continue;
      final cost = (row['cost'] as num?)?.toDouble() ?? 0.0;
      if (!cost.isFinite || cost < 0) continue;
      safe.add({'id': id, 'name': (row['name'] as String?) ?? '', 'qty': qty, 'cost': cost});
    }
    safe.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return jsonEncode({'v': 1, 'ingredients': safe});
  }

  static List<Map<String, dynamic>>? readRecipeSnapshot(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final ingredients = decoded['ingredients'];
      if (ingredients is! List) return null;
      final out = <Map<String, dynamic>>[];
      for (final entry in ingredients) {
        if (entry is! Map) continue;
        final id = entry['id'] is int ? entry['id'] as int : int.tryParse(entry['id'].toString());
        final qty = (entry['qty'] is num) ? (entry['qty'] as num).toDouble() : double.tryParse(entry['qty'].toString());
        if (id == null || qty == null || !qty.isFinite || qty < 0) continue;
        out.add({
          'id': id, 'name': entry['name']?.toString() ?? '', 'qty': qty,
          'cost': (entry['cost'] is num) ? (entry['cost'] as num).toDouble().clamp(0, double.infinity) : 0.0
        });
      }
      return out;
    } catch (_) { return null; }
  }

  Future<int> createInvoice(Invoice invoice, List<CartItem> items) async {
    if (await getCurrentUserOpenShift() == null) throw Exception('يجب فتح وردية قبل تسجيل المبيعات');
    if (items.isEmpty) throw Exception('السلة فارغة');
    
    // Bad totals guard: Phase 4.3.1.1 atomicity proof
    final actualSubtotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
    if ((invoice.subtotalAmount - actualSubtotal).abs() > 0.001) {
      throw Exception('فشل التحقق من الإجمالي: إجمالي السطور لا يطابق إجمالي الفاتورة');
    }
    
    if (invoice.discountAmount > invoice.subtotalAmount) {
      throw Exception('قيمة الخصم لا يمكن أن تتجاوز إجمالي الفاتورة');
    }

    final now = DateTime.now().toIso8601String();
    final result = await _db!.transaction<int>((txn) async {
      final allMaterialsRows = await txn.query('materials');
      final allMaterials = {for (var m in allMaterialsRows) m['id'] as int: MaterialModel.fromMap(m)};
      final allRecipesRows = await txn.query('recipes');
      final allRecipes = <int, List<RecipeModel>>{};
      for (var r in allRecipesRows) {
        final pid = r['parent_id'] as int;
        allRecipes[pid] ??= [];
        allRecipes[pid]!.add(RecipeModel.fromMap(r));
      }

      final Map<int, double> totalRequirements = {};
      final Map<int, double> legacyRequirements = {};
      for (final item in items) {
        if (allRecipes.containsKey(item.productId)) {
          final expanded = RecipeEngine.expandRecipe(
            parentType: 'product', parentId: item.productId, allRecipes: allRecipes, allMaterials: allMaterials, multiplier: item.quantity.toDouble(), deductPreparedStock: true,
          );
          for (final entry in expanded.entries) {
            totalRequirements[entry.key] = (totalRequirements[entry.key] ?? 0) + entry.value;
          }
        } else {
          // Legacy path
          final links = await txn.rawQuery('''
            SELECT pi.ingredient_id, pi.quantity, inv.name, inv.quantity as current_stock
            FROM product_ingredients pi
            INNER JOIN inventory inv ON pi.ingredient_id = inv.id
            WHERE pi.product_id = ?
          ''', [item.productId]);
          for (final link in links) {
            final ingredientId = link['ingredient_id'] as int;
            final required = (link['quantity'] as num).toDouble() * item.quantity;
            final currentStock = (link['current_stock'] as num).toDouble();
            if (currentStock < required) {
              throw Exception('المخزون غير كافٍ (Legacy): ${link['name']}');
            }
            legacyRequirements[ingredientId] = (legacyRequirements[ingredientId] ?? 0) + required;
          }
        }
      }

      for (final entry in totalRequirements.entries) {
        final mat = allMaterials[entry.key];
        if (mat == null || mat.quantity < entry.value) {
          throw Exception('المخزون غير كافٍ: ${mat?.name ?? entry.key}');
        }
      }
      for (final entry in legacyRequirements.entries) {
        final rows = await txn.query('inventory', columns: ['name', 'quantity'], where: 'id = ?', whereArgs: [entry.key]);
        if (rows.isEmpty) throw Exception('المكون #${entry.key} غير موجود');
        final current = (rows.first['quantity'] as num).toDouble();
        if (current < entry.value) {
          throw Exception('المكون "${rows.first['name']}" غير كافٍ (متوفر: $current، مطلوب: ${entry.value})');
        }
      }

      final invoiceId = await txn.insert('invoices', {
        'invoice_number': invoice.invoiceNumber,
        'total_amount': invoice.totalAmount,
        'status': invoice.status,
        'payment_method': invoice.paymentMethod,
        'customer_id': invoice.customerId,
        'kitchen_status': 'new',
        'subtotal_amount': invoice.subtotalAmount,
        'discount_amount': invoice.discountAmount,
        'paid_amount': invoice.paidAmount,
        'change_amount': invoice.changeAmount,
        'notes': invoice.notes,
        'created_at': invoice.createdAt ?? now,
      });

      for (final item in items) {
        if (allRecipes.containsKey(item.productId)) {
          final productCostAtSale = RecipeEngine.calculateProductCost(productId: item.productId, allRecipes: allRecipes, allMaterials: allMaterials);
          final unitProfit = item.price - productCostAtSale;
          final expanded = RecipeEngine.expandRecipe(
            parentType: 'product', parentId: item.productId, allRecipes: allRecipes, allMaterials: allMaterials, multiplier: 1.0, deductPreparedStock: true,
          );
          final snapshotRows = expanded.entries.map((e) => {
            'id': e.key, 'name': allMaterials[e.key]?.name ?? 'Unknown', 'qty': e.value, 'cost': allMaterials[e.key]?.costPrice ?? 0.0,
          }).toList();
          await txn.insert('invoice_items', {
            'invoice_id': invoiceId, 'product_id': item.productId, 'product_name': item.productName, 'quantity': item.quantity, 'price': item.price, 'total': item.total,
            'cost_snapshot': productCostAtSale, 'unit_profit': unitProfit, 'total_profit': unitProfit * item.quantity, 'recipe_snapshot': encodeRecipeSnapshot(snapshotRows), 'created_at': invoice.createdAt ?? now,
          });
          for (final entry in expanded.entries) {
            final matId = entry.key;
            final deduct = entry.value * item.quantity;
            final mat = allMaterials[matId]!;
            await txn.rawUpdate('UPDATE materials SET quantity = quantity - ?, updated_at = ? WHERE id = ?', [deduct, now, matId]);
            await txn.insert('inventory_audit_log', {
              'action_date': now, 'action_type': 'sale', 'ingredient_id': matId, 'ingredient_name': mat.name,
              'quantity_before': mat.quantity, 'quantity_change': -deduct, 'quantity_after': mat.quantity - deduct,
              'cost_price_at_action': mat.costPrice, 'reference_type': 'invoice', 'reference_id': invoiceId,
              'note': jsonEncode(DatabaseHelper.actorNoteForInventory(_currentUser?.id, _currentUser?.name)),
            });
            allMaterials[matId] = mat.copyWith(quantity: mat.quantity - deduct);
          }
        } else {
          // Legacy Path
          final links = await txn.rawQuery('''
            SELECT pi.ingredient_id, pi.quantity, inv.name, inv.quantity as current_stock, inv.cost_price
            FROM product_ingredients pi
            INNER JOIN inventory inv ON pi.ingredient_id = inv.id
            WHERE pi.product_id = ?
          ''', [item.productId]);
          double legacyCost = 0;
          final snapshotRows = <Map<String, dynamic>>[];
          for (final link in links) {
            final q = (link['quantity'] as num).toDouble();
            final c = (link['cost_price'] as num).toDouble();
            legacyCost += q * c;
            snapshotRows.add({'id': link['ingredient_id'], 'name': link['name'], 'qty': q, 'cost': c});
          }
          final unitProfit = item.price - legacyCost;
          await txn.insert('invoice_items', {
            'invoice_id': invoiceId, 'product_id': item.productId, 'product_name': item.productName, 'quantity': item.quantity, 'price': item.price, 'total': item.total,
            'cost_snapshot': legacyCost, 'unit_profit': unitProfit, 'total_profit': unitProfit * item.quantity, 'recipe_snapshot': encodeRecipeSnapshot(snapshotRows), 'created_at': invoice.createdAt ?? now,
          });
          for (final link in links) {
            final ingredientId = link['ingredient_id'] as int;
            final deduct = (link['quantity'] as num).toDouble() * item.quantity;
            final before = (link['current_stock'] as num).toDouble();
            
            await txn.rawUpdate(
              'UPDATE inventory SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
              [deduct, now, ingredientId]
            );

            await txn.insert('inventory_audit_log', {
              'action_date': now,
              'action_type': 'sale',
              'ingredient_id': ingredientId,
              'ingredient_name': link['name'],
              'quantity_before': before,
              'quantity_change': -deduct,
              'quantity_after': before - deduct,
              'cost_price_at_action': link['cost_price'],
              'reference_type': 'invoice',
              'reference_id': invoiceId,
              'note': jsonEncode(DatabaseHelper.actorNoteForInventory(
                _currentUser?.id, _currentUser?.name
              )),
            });
          }
        }
      }
      return invoiceId;
    });
    notifyListeners();
    return result;
  }

  Future<String> getNextInvoiceNumber() async {
    final rows = await _db!.rawQuery("SELECT MAX(id) as max_id FROM invoices");
    final maxId = (rows.first['max_id'] as num?)?.toInt() ?? 0;
    return 'INV-${(maxId + 1).toString().padLeft(5, '0')}';
  }

  Future<List<Invoice>> getInvoices() async {
    final results = await _db!.query('invoices', orderBy: 'created_at DESC');
    return results.map((e) => Invoice.fromMap(e)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final results = await _db!.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    final items = await _db!.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    final invoice = Invoice.fromMap(results.first);
    return invoice.copyWith(items: items.map((e) => InvoiceItem.fromMap(e)).toList());
  }

  Future<int> returnInvoice(int id) async {
    if (!canVoidInvoice()) throw Exception('استرجاع الفواتير متاح للمدير فقط');
    final result = await _db!.transaction<int>((txn) async {
      final rows = await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty || rows.first['status'] == 'cancelled' || rows.first['status'] == 'returned') return 0;
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final now = DateTime.now().toIso8601String();

      for (var item in items) {
        final snapshot = readRecipeSnapshot(item['recipe_snapshot']?.toString());
        if (snapshot != null) {
          for (var row in snapshot) {
            final matId = row['id'] as int;
            final restore = (row['qty'] as double) * (item['quantity'] as num).toDouble();
            
            // Try Materials path
            final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [matId]);
            if (matRows.isNotEmpty) {
              final mat = MaterialModel.fromMap(matRows.first);
              await txn.rawUpdate('UPDATE materials SET quantity = quantity + ? WHERE id = ?', [restore, matId]);
              await DatabaseHelper.logInventoryAudit(
                db: txn, ingredientId: matId, ingredientName: mat.name, actionType: 'sale_returned',
                quantityBefore: mat.quantity, quantityChange: restore, quantityAfter: mat.quantity + restore,
                costPriceAtAction: mat.costPrice, referenceType: 'invoice', referenceId: id,
                userId: _currentUser?.id, userName: _currentUser?.name, note: 'HISTORICAL_SNAPSHOT',
              );
            } else {
              // Legacy Fallback
              final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [matId]);
              if (invRows.isNotEmpty) {
                final oldQty = (invRows.first['quantity'] as num).toDouble();
                await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ? WHERE id = ?', [restore, matId]);
                await DatabaseHelper.logInventoryAudit(
                  db: txn, ingredientId: matId, ingredientName: invRows.first['name'] as String?, actionType: 'sale_returned',
                  quantityBefore: oldQty, quantityChange: restore, quantityAfter: oldQty + restore,
                  costPriceAtAction: (invRows.first['cost_price'] as num).toDouble(), referenceType: 'invoice', referenceId: id,
                  userId: _currentUser?.id, userName: _currentUser?.name, note: 'HISTORICAL_SNAPSHOT',
                );
              }
            }
          }
        } else {
          // Fallback to current recipe links (Phase 2.2 fallback)
          final productId = item['product_id'] as int;
          final qty = (item['quantity'] as num).toDouble();
          
          final links = await txn.rawQuery('''
            SELECT pi.ingredient_id, pi.quantity, inv.name, inv.quantity as current_stock, inv.cost_price
            FROM product_ingredients pi
            INNER JOIN inventory inv ON pi.ingredient_id = inv.id
            WHERE pi.product_id = ?
          ''', [productId]);
          
          if (links.isEmpty) {
            // Diagnostic row for empty legacy restoration (L-1)
            await DatabaseHelper.logInventoryAudit(
              db: txn, ingredientId: 0, ingredientName: 'PRODUCT_WITHOUT_LINKS', actionType: 'sale_returned',
              quantityBefore: 0, quantityChange: 0, quantityAfter: 0,
              costPriceAtAction: 0, referenceType: 'invoice', referenceId: id,
              userId: _currentUser?.id, userName: _currentUser?.name, note: 'LEGACY_FALLBACK_NO_RECIPE_LINKS',
            );
          } else {
            for (final link in links) {
              final ingredientId = link['ingredient_id'] as int;
              final restore = (link['quantity'] as num).toDouble() * qty;
              final before = (link['current_stock'] as num).toDouble();
              await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ? WHERE id = ?', [restore, ingredientId]);
              await DatabaseHelper.logInventoryAudit(
                db: txn, ingredientId: ingredientId, ingredientName: link['name'] as String?, actionType: 'sale_returned',
                quantityBefore: before, quantityChange: restore, quantityAfter: before + restore,
                costPriceAtAction: (link['cost_price'] as num).toDouble(), referenceType: 'invoice', referenceId: id,
                userId: _currentUser?.id, userName: _currentUser?.name, note: 'LEGACY_FALLBACK',
              );
            }
          }
        }
      }
      
      return await txn.update('invoices', {'status': 'returned', 'notes': 'تم استرجاع الفاتورة'}, where: 'id = ?', whereArgs: [id]);
    });
    notifyListeners();
    return result;
  }

  Future<int> voidInvoice(int id) async {
    if (!canVoidInvoice()) throw Exception('إلغاء الفواتير متاح للمدير فقط');
    final result = await _db!.transaction<int>((txn) async {
      final rows = await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty || rows.first['status'] == 'cancelled' || rows.first['status'] == 'returned') return 0;
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final now = DateTime.now().toIso8601String();

      for (var item in items) {
        final snapshot = readRecipeSnapshot(item['recipe_snapshot']?.toString());
        if (snapshot != null) {
          for (var row in snapshot) {
            final matId = row['id'] as int;
            final restore = (row['qty'] as double) * (item['quantity'] as num).toDouble();
            
            // Try Materials path
            final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [matId]);
            if (matRows.isNotEmpty) {
              final mat = MaterialModel.fromMap(matRows.first);
              await txn.rawUpdate('UPDATE materials SET quantity = quantity + ? WHERE id = ?', [restore, matId]);
              await DatabaseHelper.logInventoryAudit(
                db: txn, ingredientId: matId, ingredientName: mat.name, actionType: 'sale_cancelled',
                quantityBefore: mat.quantity, quantityChange: restore, quantityAfter: mat.quantity + restore,
                costPriceAtAction: mat.costPrice, referenceType: 'invoice', referenceId: id,
                userId: _currentUser?.id, userName: _currentUser?.name, note: 'HISTORICAL_SNAPSHOT',
              );
            } else {
              // Legacy Fallback
              final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [matId]);
              if (invRows.isNotEmpty) {
                final oldQty = (invRows.first['quantity'] as num).toDouble();
                await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ? WHERE id = ?', [restore, matId]);
                await DatabaseHelper.logInventoryAudit(
                  db: txn, ingredientId: matId, ingredientName: invRows.first['name'] as String?, actionType: 'sale_cancelled',
                  quantityBefore: oldQty, quantityChange: restore, quantityAfter: oldQty + restore,
                  costPriceAtAction: (invRows.first['cost_price'] as num).toDouble(), referenceType: 'invoice', referenceId: id,
                  userId: _currentUser?.id, userName: _currentUser?.name, note: 'HISTORICAL_SNAPSHOT',
                );
              }
            }
          }
        }
      }
      
      return await txn.update('invoices', {'status': 'cancelled', 'notes': 'تم إلغاء الفاتورة'}, where: 'id = ?', whereArgs: [id]);
    });
    notifyListeners();
    return result;
  }

  // Legacy Aliases for Audit Tests
  Future<int> addIngredient(dynamic ingredientData) async {
    final ingr = ingredientData as IngredientModel;
    final now = DateTime.now().toIso8601String();
    return await _db!.transaction((txn) async {
      final id = await txn.insert('inventory', {
        'name': ingr.name,
        'quantity': ingr.quantity,
        'unit': ingr.unit,
        'cost_price': ingr.costPrice,
        'min_quantity': ingr.minQuantity,
        'created_at': now,
        'updated_at': now,
      });
      await DatabaseHelper.logInventoryAudit(
        db: txn,
        actionType: 'added',
        ingredientId: id,
        ingredientName: ingr.name,
        quantityBefore: 0,
        quantityChange: ingr.quantity,
        quantityAfter: ingr.quantity,
        costPriceAtAction: ingr.costPrice,
        userId: _currentUser?.id,
        userName: _currentUser?.name,
      );
      return id;
    });
  }

  Future<int> updateIngredient(dynamic ingredientData) async {
    final ingr = ingredientData as IngredientModel;
    final now = DateTime.now().toIso8601String();
    return await _db!.transaction((txn) async {
      // Try Materials path first
      final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [ingr.id]);
      if (matRows.isNotEmpty) {
        final oldMat = MaterialModel.fromMap(matRows.first);
        final qtyDelta = ingr.quantity - oldMat.quantity;
        final result = await txn.update(
          'materials',
          {'name': ingr.name, 'quantity': ingr.quantity, 'unit': ingr.unit, 'cost_price': ingr.costPrice, 'min_quantity': ingr.minQuantity, 'updated_at': now},
          where: 'id = ?', whereArgs: [ingr.id],
        );
        if (qtyDelta != 0) {
          await DatabaseHelper.logInventoryAudit(
            db: txn, actionType: 'manual_adjust', ingredientId: ingr.id!, ingredientName: ingr.name,
            quantityBefore: oldMat.quantity, quantityChange: qtyDelta, quantityAfter: ingr.quantity,
            costPriceAtAction: ingr.costPrice, userId: _currentUser?.id, userName: _currentUser?.name, note: 'تعديل يدوي',
          );
        }
        return result;
      }
      
      // Legacy Fallback
      final oldRows = await txn.query('inventory', where: 'id = ?', whereArgs: [ingr.id]);
      if (oldRows.isEmpty) throw Exception('المادة غير موجودة');
      final oldQty = (oldRows.first['quantity'] as num).toDouble();
      final qtyDelta = ingr.quantity - oldQty;
      final result = await txn.update(
        'inventory',
        {'name': ingr.name, 'quantity': ingr.quantity, 'unit': ingr.unit, 'cost_price': ingr.costPrice, 'updated_at': now},
        where: 'id = ?', whereArgs: [ingr.id],
      );
      if (qtyDelta != 0) {
        await DatabaseHelper.logInventoryAudit(
          db: txn, actionType: 'manual_adjust', ingredientId: ingr.id!, ingredientName: ingr.name,
          quantityBefore: oldQty, quantityChange: qtyDelta, quantityAfter: ingr.quantity,
          costPriceAtAction: ingr.costPrice, userId: _currentUser?.id, userName: _currentUser?.name, note: 'تعديل يدوي',
        );
      }
      return result;
    });
  }
  
  Future<void> recordPurchase(int materialId, double quantity, double unitCost) async {
    final now = DateTime.now().toIso8601String();
    await _db!.transaction((txn) async {
      // Try Materials path first
      final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [materialId]);
      if (matRows.isNotEmpty) {
        final mat = MaterialModel.fromMap(matRows.first);
        final newWac = RecipeEngine.calculateWAC(currentQty: mat.quantity, currentAvgCost: mat.costPrice, newQty: quantity, newBatchCost: unitCost);
        await txn.rawUpdate('UPDATE materials SET quantity = quantity + ?, cost_price = ?, updated_at = ? WHERE id = ?', [quantity, newWac, now, materialId]);
        await DatabaseHelper.logInventoryAudit(
          db: txn, actionType: 'purchase', ingredientId: materialId, ingredientName: mat.name,
          quantityBefore: mat.quantity, quantityChange: quantity, quantityAfter: mat.quantity + quantity,
          costPriceAtAction: newWac, userId: _currentUser?.id, userName: _currentUser?.name,
        );
        return;
      }

      // Legacy Fallback
      final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [materialId]);
      if (invRows.isEmpty) throw Exception('المادة غير موجودة');
      final oldQty = (invRows.first['quantity'] as num).toDouble();
      final oldCost = (invRows.first['cost_price'] as num).toDouble();
      final newWac = RecipeEngine.calculateWAC(currentQty: oldQty, currentAvgCost: oldCost, newQty: quantity, newBatchCost: unitCost);
      await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ?, cost_price = ?, updated_at = ? WHERE id = ?', [quantity, newWac, now, materialId]);
      await DatabaseHelper.logInventoryAudit(
        db: txn, actionType: 'purchase', ingredientId: materialId, ingredientName: invRows.first['name'] as String?,
        quantityBefore: oldQty, quantityChange: quantity, quantityAfter: oldQty + quantity,
        costPriceAtAction: newWac, userId: _currentUser?.id, userName: _currentUser?.name,
      );
    });
    notifyListeners();
  }

  // ==================== REPORTS ====================

  Future<Map<String, dynamic>> getProfitAndLossSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    final s = start.toIso8601String().substring(0, 10);
    final e = end.toIso8601String().substring(0, 10);

    final sales = await _db!.rawQuery(
      "SELECT SUM(total_amount) as rev, SUM(discount_amount) as disc, COUNT(*) as cnt FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled', 'returned')", [s, e]
    );
    final items = await _db!.rawQuery(
      "SELECT ii.cost_snapshot, ii.quantity, ii.product_id "
      "FROM invoice_items ii "
      "JOIN invoices i ON ii.invoice_id = i.id "
      "WHERE DATE(i.created_at) BETWEEN ? AND ? "
      "AND i.status NOT IN ('cancelled', 'returned')", [s, e]
    );
    double totalCogsPnL = 0.0;
    for (var row in items) {
      double cost = (row['cost_snapshot'] as num).toDouble();
      double qty = (row['quantity'] as num).toDouble();
      if (cost <= 0) {
        final productId = row['product_id'] as int;
        final links = await _db!.rawQuery('''
          SELECT pi.quantity as link_qty, inv.cost_price 
          FROM product_ingredients pi 
          INNER JOIN inventory inv ON pi.ingredient_id = inv.id 
          WHERE pi.product_id = ?
        ''', [productId]);
        double calcCost = 0.0;
        for (var link in links) {
          calcCost += (link['link_qty'] as num).toDouble() * (link['cost_price'] as num).toDouble();
        }
        cost = calcCost;
      }
      totalCogsPnL += cost * qty;
    }
    final expenses = await _db!.rawQuery(
      "SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ?", [s, e]
    );
    
    final payments = await _db!.rawQuery(
      "SELECT payment_method, SUM(total_amount) as total "
      "FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? "
      "AND status NOT IN ('cancelled', 'returned') "
      "GROUP BY payment_method", [s, e]
    );

    final rev = (sales.first['rev'] as num?)?.toDouble() ?? 0.0;
    final disc = (sales.first['disc'] as num?)?.toDouble() ?? 0.0;
    final cnt = (sales.first['cnt'] as num?)?.toInt() ?? 0;
    final cogs = totalCogsPnL;
    final ex = (expenses.first['total'] as num?)?.toDouble() ?? 0.0;

    final payMap = <String, double>{'cash': 0.0, 'card': 0.0, 'transfer': 0.0};
    for (final p in payments) {
      String method = p['payment_method'] as String;
      if (method == 'bank') method = 'transfer';
      if (payMap.containsKey(method)) {
        payMap[method] = (payMap[method] ?? 0.0) + ((p['total'] as num?)?.toDouble() ?? 0.0);
      }
    }

    return {
      'totalRevenue': rev,
      'totalSales': rev,
      'sales': rev,
      'subtotal': rev + disc,
      'discounts': disc,
      'grossSales': rev + disc,
      'discountTotal': disc,
      'cogs': cogs,
      'grossProfit': rev - cogs,
      'totalExpenses': ex,
      'expenses': ex,
      'netProfit': rev - cogs - ex,
      'invoices': cnt,
      'invoiceCount': cnt,
      'payment': [
        {'name': 'نقدًا', 'amount': payMap['cash']},
        {'name': 'بطاقة', 'amount': payMap['card']},
        {'name': 'تحويل', 'amount': payMap['transfer']},
      ],
    };
  }

  Future<Map<String, dynamic>> getDailyReport(String date) async => getProfitAndLossSummary(startDate: DateTime.parse(date), endDate: DateTime.parse(date));
  Future<Map<String, dynamic>> getBusinessIntelligence({required DateTime start, required DateTime end}) async => getProfitAndLossSummary(startDate: start, endDate: end);

  Future<int> addExpense(Expense expense) async {
    final data = expense.toMap();
    data['created_at'] ??= DateTime.now().toIso8601String();
    final id = await _db!.insert('expenses', data);
    notifyListeners();
    return id;
  }

  Future<int> deleteExpense(int id, {String? reason}) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteExpenseSafe(id, userId: _currentUser?.id, userName: _currentUser?.name, reason: reason);
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> getShiftSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    final s = start.toIso8601String().substring(0, 10);
    final e = end.toIso8601String().substring(0, 10);
    
    final sales = await _db!.rawQuery(
      "SELECT SUM(total_amount) as total, SUM(discount_amount) as disc, COUNT(*) as cnt FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled', 'returned')", [s, e]
    );
    final items = await _db!.rawQuery(
      "SELECT ii.cost_snapshot, ii.quantity, ii.product_id "
      "FROM invoice_items ii "
      "JOIN invoices i ON ii.invoice_id = i.id "
      "WHERE DATE(i.created_at) BETWEEN ? AND ? "
      "AND i.status NOT IN ('cancelled', 'returned')", [s, e]
    );
    double totalCogsShift = 0.0;
    for (var row in items) {
      double cost = (row['cost_snapshot'] as num).toDouble();
      double qty = (row['quantity'] as num).toDouble();
      if (cost <= 0) {
        final productId = row['product_id'] as int;
        final links = await _db!.rawQuery('''
          SELECT pi.quantity as link_qty, inv.cost_price 
          FROM product_ingredients pi 
          INNER JOIN inventory inv ON pi.ingredient_id = inv.id 
          WHERE pi.product_id = ?
        ''', [productId]);
        double calcCost = 0.0;
        for (var link in links) {
          calcCost += (link['link_qty'] as num).toDouble() * (link['cost_price'] as num).toDouble();
        }
        cost = calcCost;
      }
      totalCogsShift += cost * qty;
    }
    final expenses = await _db!.rawQuery(
      "SELECT SUM(amount) as total FROM expenses WHERE DATE(created_at) BETWEEN ? AND ?", [s, e]
    );
    final payments = await _db!.rawQuery(
      "SELECT payment_method, SUM(total_amount) as total "
      "FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? "
      "AND status NOT IN ('cancelled', 'returned') "
      "GROUP BY payment_method", [s, e]
    );
    
    final rev = (sales.first['total'] as num?)?.toDouble() ?? 0.0;
    final disc = (sales.first['disc'] as num?)?.toDouble() ?? 0.0;
    final cnt = (sales.first['cnt'] as num?)?.toInt() ?? 0;
    final cogs = totalCogsShift;
    final ex = (expenses.first['total'] as num?)?.toDouble() ?? 0.0;
    
    final payMap = <String, double>{'cash': 0.0, 'card': 0.0, 'transfer': 0.0};
    for (final p in payments) {
      String method = p['payment_method'] as String;
      if (method == 'bank') method = 'transfer';
      if (payMap.containsKey(method)) {
        payMap[method] = (payMap[method] ?? 0.0) + ((p['total'] as num?)?.toDouble() ?? 0.0);
      }
    }
    
    return {
      'grossSales': rev + disc,
      'discountTotal': disc,
      'totalSales': rev,
      'cogs': cogs,
      'grossProfit': rev - cogs,
      'totalExpenses': ex,
      'netProfit': rev - cogs - ex,
      'invoiceCount': cnt,
      'cashTotal': payMap['cash'] ?? 0.0,
      'bankTotal': payMap['transfer'] ?? 0.0,
      'cardTotal': payMap['card'] ?? 0.0,
      'payment': [
        {'name': 'نقدًا', 'amount': payMap['cash']},
        {'name': 'بطاقة', 'amount': payMap['card']},
        {'name': 'تحويل', 'amount': payMap['transfer']},
      ],
    };
  }

  // More Legacy Aliases
  Future<Map<String, dynamic>> getIngredientImpact(int id) async {
    final impact = await DatabaseHelper.getMaterialImpact(id);
    return {
      ...impact,
      'purchase_reference_count': impact['purchase_count'], // Test compatibility
    };
  }

  Future<int> deleteIngredient(int id, {bool force = false, String? reason}) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final r = await DatabaseHelper.deleteIngredientSafe(
      id,
      force: force,
      userId: _currentUser?.id,
      userName: _currentUser?.name,
      reason: reason,
    );
    notifyListeners();
    return r;
  }
  Future<int> deleteSupplier(int id, {String? reason}) => DatabaseHelper.deleteSupplierSafe(id, userId: _currentUser?.id, userName: _currentUser?.name, reason: reason);

}
