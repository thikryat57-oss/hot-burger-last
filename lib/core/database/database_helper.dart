import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../../models/models.dart';
import '../utils/recipe_engine.dart';

class SafeDeleteBlockedException implements Exception {
  final String message;
  const SafeDeleteBlockedException(this.message);
  @override
  String toString() => message;
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hot_burger.db');
    return await openDatabase(
      path,
      version: 19,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createVersion6Tables(db);
    await _createVersion7Indexes(db);
    await _createVersion8Tables(db);
    await _createVersion17Tables(db);
    await _createVersion18Tables(db);
    await _createVersion19Tables(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) await _createVersion6Tables(db);
    if (oldVersion < 7) await _createVersion7Indexes(db);
    if (oldVersion < 8) await _createVersion8Tables(db);
    if (oldVersion < 17) await _createVersion17Tables(db);
    if (oldVersion < 18) await _createVersion18Tables(db);
    if (oldVersion < 19) await _migrateToVersion19(db);
  }

  static Future<void> _createVersion6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'manager',
        password TEXT NOT NULL,
        password_hash TEXT,
        password_salt TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        price REAL NOT NULL,
        cost REAL DEFAULT 0,
        description TEXT,
        image_path TEXT,
        is_available INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity REAL DEFAULT 0,
        unit TEXT,
        min_quantity REAL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        ingredient_id INTEGER,
        quantity REAL NOT NULL,
        unit TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (ingredient_id) REFERENCES inventory (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        total_amount REAL NOT NULL,
        subtotal_amount REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        change_amount REAL DEFAULT 0,
        payment_method TEXT,
        status TEXT DEFAULT 'completed',
        kitchen_status TEXT DEFAULT 'new',
        customer_id INTEGER,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        product_id INTEGER,
        product_name TEXT,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        cost_snapshot REAL DEFAULT 0,
        unit_profit REAL DEFAULT 0,
        total_profit REAL DEFAULT 0,
        recipe_snapshot TEXT,
        created_at TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER,
        ingredient_name TEXT,
        action_type TEXT NOT NULL,
        quantity_before REAL,
        quantity_change REAL,
        quantity_after REAL,
        cost_price_at_action REAL,
        reference_type TEXT,
        reference_id INTEGER,
        action_date TEXT,
        note TEXT
      )
    ''');
  }

  static Future<void> _createVersion7Indexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_ingredient ON inventory_audit_log(ingredient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_date ON inventory_audit_log(action_date)');
  }

  static Future<void> _createVersion8Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        opened_at TEXT,
        closed_at TEXT,
        opening_balance REAL,
        closing_balance REAL,
        status TEXT,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        action_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        user_id INTEGER,
        user_name TEXT,
        note TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_audit_invoice ON invoice_audit_log(invoice_id, action_date)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT,
        notes TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        points INTEGER DEFAULT 0,
        total_spent REAL DEFAULT 0,
        visit_count INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  static Future<void> _createVersion17Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        unit TEXT,
        quantity REAL DEFAULT 0,
        min_quantity REAL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        category TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_type TEXT NOT NULL,
        parent_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT,
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        notes TEXT,
        created_at TEXT,
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');
  }

  static Future<void> _createVersion18Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocktake_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT,
        finalized_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocktake_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        expected_quantity REAL NOT NULL,
        actual_quantity REAL,
        cost_price REAL,
        FOREIGN KEY (session_id) REFERENCES stocktake_sessions (id),
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT,
        created_at TEXT,
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');
  }

  static Future<void> _createVersion19Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        balance REAL DEFAULT 0,
        tax_number TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        supplier_id INTEGER,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        status TEXT,
        notes TEXT,
        date TEXT,
        created_at TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        ingredient_id INTEGER,
        material_id INTEGER,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        unit TEXT,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        purchase_invoice_id INTEGER,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id)
      )
    ''');
  }

  static Future<void> _migrateToVersion19(Database db) async {
    await _createVersion19Tables(db);
    
    // Ensure invoice_audit_log exists (Phase 7.0 porting safety)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        action_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        user_id INTEGER,
        user_name TEXT,
        note TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_audit_invoice ON invoice_audit_log(invoice_id, action_date)');

    final columns = await db.rawQuery('PRAGMA table_info(purchase_items)');
    if (!columns.any((c) => c['name'] == 'material_id')) {
      await db.execute('ALTER TABLE purchase_items ADD COLUMN material_id INTEGER');
      await db.execute('UPDATE purchase_items SET material_id = ingredient_id WHERE material_id IS NULL');
    }
  }

  // Actor attribution helpers
  static Map<String, dynamic> _auditActor(int? userId, String? userName) {
    return {'user_id': userId, 'user_name': userName};
  }

  static Map<String, dynamic> _auditReason(String? reason) {
    final trimmed = reason?.trim();
    return (trimmed == null || trimmed.isEmpty) ? const {} : {'deletion_reason': trimmed};
  }

  static Map<String, dynamic> actorNoteForInventory(int? userId, String? userName, {String? noteText}) {
    final map = <String, dynamic>{..._auditActor(userId, userName)};
    final trimmed = noteText?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      map['note'] = trimmed;
      map['deletion_reason'] = trimmed;
    }
    return map;
  }

  // Suppliers CRUD
  static Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;
    supplier['created_at'] = DateTime.now().toIso8601String();
    supplier['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('suppliers', supplier);
  }

  static Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    return await db.query('suppliers', orderBy: 'name ASC');
  }

  static Future<int> deleteSupplierSafe(int supplierId, {int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final supplier = await txn.query('suppliers', columns: ['id', 'name'], where: 'id = ?', whereArgs: [supplierId]);
      if (supplier.isEmpty) return 0;
      final name = supplier.first['name'] as String?;

      final payments = await txn.rawQuery('SELECT COUNT(*) AS c FROM supplier_payments WHERE supplier_id = ?', [supplierId]);
      final paymentCount = (payments.first['c'] as num).toInt();
      if (paymentCount > 0) throw SafeDeleteBlockedException('لا يمكن حذف المورد: لديه سجل مدفوعات مالي');

      final invoices = await txn.rawQuery('SELECT COUNT(*) AS c FROM purchase_invoices WHERE supplier_id = ?', [supplierId]);
      final invoiceCount = (invoices.first['c'] as num).toInt();
      if (invoiceCount > 0) throw SafeDeleteBlockedException('لا يمكن حذف المورد: مرتبط بفواتير شراء');

      final note = {
        'audit_type': 'supplier_deleted',
        'supplier_id': supplierId,
        'supplier_name': name,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };
      
      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');
      
      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'supplier_deleted',
        'ingredient_id': 0,
        'ingredient_name': name,
        'quantity_before': 0.0,
        'quantity_change': 0.0,
        'quantity_after': 0.0,
        'cost_price_at_action': 0.0,
        'reference_type': 'supplier',
        'reference_id': supplierId,
        'note': jsonEncode(note),
      });
      
      return await txn.delete('suppliers', where: 'id = ?', whereArgs: [supplierId]);
    });
  }

  static Future<int> deleteProductIngredientSafe(int productId, int ingredientId, {int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final link = await txn.query('product_ingredients', where: 'product_id = ? AND ingredient_id = ?', whereArgs: [productId, ingredientId]);
      if (link.isEmpty) return 0;
      final previousQty = (link.first['quantity'] as num).toDouble();
      
      final invRows = await txn.query('inventory', columns: ['name'], where: 'id = ?', whereArgs: [ingredientId]);
      final name = invRows.isNotEmpty ? invRows.first['name'] as String? : null;
      
      final result = await txn.delete('product_ingredients', where: 'product_id = ? AND ingredient_id = ?', whereArgs: [productId, ingredientId]);
      
      final note = {
        'audit_type': 'recipe_link_deleted',
        'product_id': productId,
        'ingredient_id': ingredientId,
        'previous_quantity': previousQty,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };

      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');

      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'recipe_link_deleted',
        'ingredient_id': ingredientId,
        'ingredient_name': name,
        'quantity_before': previousQty,
        'quantity_change': -previousQty,
        'quantity_after': 0.0,
        'cost_price_at_action': 0.0,
        'reference_type': 'recipe',
        'reference_id': productId,
        'note': jsonEncode(note),
      });
      
      return result;
    });
  }

  // Procurement Engine
  static Future<int> insertPurchaseInvoice(PurchaseInvoice invoice, List<PurchaseItem> items, {int? userId, String? userName}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final invoiceId = await txn.insert('purchase_invoices', {
        'invoice_number': invoice.invoiceNumber,
        'supplier_id': invoice.supplierId,
        'total_amount': invoice.totalAmount,
        'paid_amount': invoice.paidAmount,
        'status': invoice.status,
        'notes': invoice.notes,
        'date': invoice.date,
        'created_at': now,
      });

      for (final item in items) {
        final materialId = item.materialId ?? item.ingredientId;
        if (materialId == null) continue;
        
        await txn.insert('purchase_items', {
          'purchase_invoice_id': invoiceId,
          'material_id': materialId,
          'quantity': item.quantity,
          'unit_cost': item.unitCost,
          'total_cost': item.totalCost,
          'unit': item.unit,
        });

        final matRows = await txn.query('materials', where: 'id = ?', whereArgs: [materialId]);
        if (matRows.isNotEmpty) {
          final current = MaterialModel.fromMap(matRows.first);
          final newWac = RecipeEngine.calculateWAC(
            currentQty: current.quantity,
            currentAvgCost: current.costPrice,
            newQty: item.quantity,
            newBatchCost: item.unitCost,
          );
          await txn.rawUpdate('UPDATE materials SET quantity = quantity + ?, cost_price = ?, updated_at = ? WHERE id = ?', [item.quantity, newWac, now, materialId]);
          await txn.insert('inventory_audit_log', {
            'action_date': now, 'action_type': 'purchase', 'ingredient_id': materialId, 'ingredient_name': current.name,
            'quantity_before': current.quantity, 'quantity_change': item.quantity, 'quantity_after': current.quantity + item.quantity,
            'cost_price_at_action': newWac, 'reference_type': 'purchase_invoice', 'reference_id': invoiceId,
            'note': jsonEncode(actorNoteForInventory(userId, userName, noteText: 'شراء من مورد')),
          });
          await recalculateProductCostsForIngredient(txn, materialId);
        } else {
          // Legacy Fallback
          final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [materialId]);
          if (invRows.isNotEmpty) {
            final oldQty = (invRows.first['quantity'] as num).toDouble();
            final oldCost = (invRows.first['cost_price'] as num).toDouble();
            final newWac = RecipeEngine.calculateWAC(
              currentQty: oldQty,
              currentAvgCost: oldCost,
              newQty: item.quantity,
              newBatchCost: item.unitCost,
            );
            await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ?, cost_price = ?, updated_at = ? WHERE id = ?', [item.quantity, newWac, now, materialId]);
          await txn.insert('inventory_audit_log', {
            'action_date': now, 'action_type': 'purchase', 'ingredient_id': materialId, 'ingredient_name': invRows.first['name'] as String?,
            'quantity_before': oldQty, 'quantity_change': item.quantity, 'quantity_after': oldQty + item.quantity,
            'cost_price_at_action': newWac, 'reference_type': 'purchase_invoice', 'reference_id': invoiceId,
            'note': jsonEncode(actorNoteForInventory(userId, userName, noteText: 'شراء من مورد (Legacy)')),
          });
          }
        }
      }
      return invoiceId;
    });
  }

  static Future<void> recalculateProductCostsForIngredient(Transaction txn, int ingredientId, {bool isFullProductRecalc = false, int? targetProductId}) async {
    final allMaterialsRows = await txn.query('materials');
    final allMaterials = {for (var m in allMaterialsRows) m['id'] as int: MaterialModel.fromMap(m)};
    
    // Legacy support: also load inventory into allMaterials map for calculation
    final allInventoryRows = await txn.query('inventory');
    for (final row in allInventoryRows) {
      final id = row['id'] as int;
      if (!allMaterials.containsKey(id)) {
        allMaterials[id] = MaterialModel(
          id: id,
          name: row['name'] as String,
          type: 'raw', // inventory table is raw materials
          quantity: (row['quantity'] as num).toDouble(),
          costPrice: (row['cost_price'] as num).toDouble(),
          unit: row['unit'] as String? ?? 'unit',
          minQuantity: (row['min_quantity'] as num).toDouble(),
        );
      }
    }

    final allRecipesRows = await txn.query('recipes');
    final allRecipes = <int, List<RecipeModel>>{};
    for (var r in allRecipesRows) {
      final pid = r['parent_id'] as int;
      allRecipes[pid] ??= [];
      allRecipes[pid]!.add(RecipeModel.fromMap(r));
    }
    
    // Legacy support: also load product_ingredients into allRecipes
    final allLegacyRecipesRows = await txn.query('product_ingredients');
    for (var r in allLegacyRecipesRows) {
      final pid = r['product_id'] as int;
      allRecipes[pid] ??= [];
      allRecipes[pid]!.add(RecipeModel(
        parentType: 'product',
        parentId: pid,
        materialId: r['ingredient_id'] as int,
        quantity: (r['quantity'] as num).toDouble(),
        unit: r['unit'] as String? ?? 'unit',
      ));
    }

    final List<int> productIds = [];
    if (isFullProductRecalc && targetProductId != null) {
      productIds.add(targetProductId);
    } else {
      // Check recipes
      final results = await txn.query('recipes', columns: ['parent_id'], where: 'material_id = ? AND parent_type = ?', whereArgs: [ingredientId, 'product']);
      productIds.addAll(results.map((e) => e['parent_id'] as int));
      // Check product_ingredients
      final legacyResults = await txn.query('product_ingredients', columns: ['product_id'], where: 'ingredient_id = ?', whereArgs: [ingredientId]);
      productIds.addAll(legacyResults.map((e) => e['product_id'] as int));
    }

    final uniqueProductIds = productIds.toSet();
    for (final pid in uniqueProductIds) {
      final cost = RecipeEngine.calculateProductCost(productId: pid, allRecipes: allRecipes, allMaterials: allMaterials);
      await txn.update('products', {'cost': cost}, where: 'id = ?', whereArgs: [pid]);
    }
  }

  // Safe Deletes
  static Future<Map<String, dynamic>> getMaterialImpact(int id) async {
    final db = await database;
    final recipeLinks = await db.rawQuery('''
      SELECT r.parent_type, r.parent_id, CASE WHEN r.parent_type = 'product' THEN p.name ELSE m.name END as parent_name
      FROM recipes r LEFT JOIN products p ON r.parent_type = 'product' AND r.parent_id = p.id
      LEFT JOIN materials m ON r.parent_type = 'material' AND r.parent_id = m.id WHERE r.material_id = ?
    ''', [id]);
    final purchaseRefs = await db.rawQuery("SELECT COUNT(*) AS c FROM purchase_items WHERE material_id = ?", [id]);
    final productionRefs = await db.rawQuery('SELECT COUNT(*) AS c FROM production_batches WHERE material_id = ?', [id]);
    final adjustmentRefs = await db.rawQuery('SELECT COUNT(*) AS c FROM inventory_adjustments WHERE material_id = ?', [id]);
    final linkedProducts = recipeLinks.where((r) => r['parent_type'] == 'product').map((r) => {'product_id': r['parent_id'], 'product_name': r['parent_name']}).toList();
    
    // Legacy support: also check product_ingredients
    final legacyLinks = await db.rawQuery('''
      SELECT pi.product_id, p.name as product_name 
      FROM product_ingredients pi 
      INNER JOIN products p ON pi.product_id = p.id 
      WHERE pi.ingredient_id = ?
    ''', [id]);
    for (final link in legacyLinks) {
      if (!linkedProducts.any((p) => p['product_id'] == link['product_id'])) {
        linkedProducts.add({'product_id': link['product_id'], 'product_name': link['product_name']});
      }
    }

    return {
      'recipe_links': recipeLinks,
      'linked_products': linkedProducts,
      'purchase_count': (purchaseRefs.first['c'] as num).toInt(),
      'production_count': (productionRefs.first['c'] as num).toInt(),
      'adjustment_count': (adjustmentRefs.first['c'] as num).toInt(),
      'is_safe': (purchaseRefs.first['c'] as num).toInt() == 0 && (productionRefs.first['c'] as num).toInt() == 0 && (adjustmentRefs.first['c'] as num).toInt() == 0 && recipeLinks.isEmpty && legacyLinks.isEmpty,
    };
  }

    static Future<int> deleteIngredientSafe(int id, {bool force = false, int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await _deleteIngredientSafeInternal(txn, id, force: force, userId: userId, userName: userName, reason: reason);
    });
  }

  static Future<int> _deleteIngredientSafeInternal(Transaction txn, int id, {bool force = false, int? userId, String? userName, String? reason}) async {
    final current = await txn.query('inventory', columns: ['id', 'name', 'quantity', 'cost_price'], where: 'id = ?', whereArgs: [id]);
    if (current.isEmpty) return 0;
    final name = current.first['name'] as String?;
    final beforeQty = (current.first['quantity'] as num).toDouble();
    final costPrice = (current.first['cost_price'] as num).toDouble();

    final purchaseRefs = await txn.rawQuery('SELECT COUNT(*) AS c FROM purchase_items WHERE ingredient_id = ?', [id]);
    if ((purchaseRefs.first['c'] as num).toInt() > 0) throw const SafeDeleteBlockedException('لا يمكن حذف المادة الخام: مستخدمة في فواتير شراء سابقة');

    final links = await txn.rawQuery('SELECT pi.product_id, p.name AS product_name FROM product_ingredients pi INNER JOIN products p ON pi.product_id = p.id WHERE pi.ingredient_id = ?', [id]);
    if (links.isNotEmpty) {
      if (!force) throw SafeDeleteBlockedException('المادة الخام مرتبطة بوصفة منتج؛ يجب حذف الروابط أولاً');
      await txn.delete('product_ingredients', where: 'ingredient_id = ?', whereArgs: [id]);
    }

    final note = {
      'audit_type': 'ingredient_deleted',
      'ingredient_id': id,
      'quantity_at_delete': beforeQty,
      'override': force,
      'links_explicitly_removed': links.isNotEmpty && force,
      'affected_product_ids': links.map((l) => l['product_id']).toList(),
      ..._auditActor(userId, userName),
      ..._auditReason(reason),
    };

    if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');

    await txn.insert('inventory_audit_log', {
      'action_date': DateTime.now().toIso8601String(),
      'action_type': 'ingredient_deleted',
      'ingredient_id': id,
      'ingredient_name': name,
      'quantity_before': beforeQty,
      'quantity_change': -beforeQty,
      'quantity_after': 0.0,
      'cost_price_at_action': costPrice,
      'reference_type': 'manual',
      'note': jsonEncode(note),
    });
    
    return await txn.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteMaterialSafe(int id, {bool force = false, int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final current = await txn.query('materials', where: 'id = ?', whereArgs: [id]);
      if (current.isEmpty) return await _deleteIngredientSafeInternal(txn, id, force: force, userId: userId, userName: userName, reason: reason);
      
      // Impact check within transaction to avoid deadlocks
      final recipeLinks = await txn.rawQuery('''
        SELECT r.parent_type, r.parent_id, CASE WHEN r.parent_type = 'product' THEN p.name ELSE m.name END as parent_name
        FROM recipes r LEFT JOIN products p ON r.parent_type = 'product' AND r.parent_id = p.id
        LEFT JOIN materials m ON r.parent_type = 'material' AND r.parent_id = m.id WHERE r.material_id = ?
      ''', [id]);
      final purchaseRefs = await txn.rawQuery("SELECT COUNT(*) AS c FROM purchase_items WHERE material_id = ?", [id]);
      final productionRefs = await txn.rawQuery('SELECT COUNT(*) AS c FROM production_batches WHERE material_id = ?', [id]);
      final adjustmentRefs = await txn.rawQuery('SELECT COUNT(*) AS c FROM inventory_adjustments WHERE material_id = ?', [id]);
      
      final isSafe = (purchaseRefs.first['c'] as num).toInt() == 0 && (productionRefs.first['c'] as num).toInt() == 0 && (adjustmentRefs.first['c'] as num).toInt() == 0 && recipeLinks.isEmpty;
      
      if (!isSafe && !force) throw const SafeDeleteBlockedException('لا يمكن حذف المادة لوجود ارتباطات مالية أو إنتاجية');
      if (recipeLinks.isNotEmpty && !force) throw const SafeDeleteBlockedException('المادة مستخدمة في وصفات؛ احذف الروابط أولاً');
      
      await txn.delete('recipes', where: 'material_id = ?', whereArgs: [id]);
      await txn.delete('materials', where: 'id = ?', whereArgs: [id]);
      
      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');
      
      final note = {
        'audit_type': 'material_deleted',
        'material_id': id,
        'quantity_at_delete': (current.first['quantity'] as num).toDouble(),
        'override': force,
        'links_explicitly_removed': recipeLinks.isNotEmpty && force,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };
      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'material_deleted',
        'material_id': id,
        'ingredient_name': current.first['name'],
        'quantity_before': (current.first['quantity'] as num).toDouble(),
        'quantity_change': -(current.first['quantity'] as num).toDouble(),
        'quantity_after': 0.0,
        'cost_price_at_action': (current.first['cost_price'] as num).toDouble(),
        'reference_type': 'manual',
        'note': jsonEncode(note),
      });
      return 1;
    });
  }

  static Future<int> deleteProductSafe(int productId, {int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final product = await txn.query('products', columns: ['id', 'name'], where: 'id = ?', whereArgs: [productId]);
      if (product.isEmpty) return 0;
      final name = product.first['name'] as String?;

      final sales = await txn.rawQuery('SELECT COUNT(*) AS c FROM invoice_items WHERE product_id = ?', [productId]);
      if ((sales.first['c'] as num).toInt() > 0) throw SafeDeleteBlockedException('لا يمكن حذف المنتج: مرتبط بعمليات بيع سابقة');

      final recipeLinks = await txn.query('product_ingredients', columns: ['ingredient_id'], where: 'product_id = ?', whereArgs: [productId]);
      final ingredientIds = recipeLinks.map((r) => r['ingredient_id']).toList();

      final note = {
        'audit_type': 'product_deleted',
        'product_id': productId,
        'product_name': name,
        'affected_ingredient_ids': ingredientIds,
        'link_count': ingredientIds.length,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };

      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');

      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'product_deleted',
        'ingredient_id': null,
        'ingredient_name': name,
        'quantity_before': 0.0,
        'quantity_change': 0.0,
        'quantity_after': 0.0,
        'cost_price_at_action': 0.0,
        'reference_type': 'recipe',
        'reference_id': productId,
        'note': jsonEncode(note),
      });
      
      return await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
    });
  }

  // Audit Logs
  static Future<List<Map<String, dynamic>>> getInventoryAuditLogs({String? query, String? actionType, int? ingredientId, String? dateFrom, String? dateTo}) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> args = [];
    if (query != null && query.isNotEmpty) {
      where += ' AND (ingredient_name LIKE ? OR note LIKE ?)';
      args.addAll(['%$query%', '%$query%']);
    }
    if (actionType != null) {
      where += ' AND action_type = ?';
      args.add(actionType);
    }
    if (ingredientId != null) {
      where += ' AND ingredient_id = ?';
      args.add(ingredientId);
    }
    if (dateFrom != null) {
      where += ' AND DATE(action_date) >= ?';
      args.add(dateFrom);
    }
    if (dateTo != null) {
      where += ' AND DATE(action_date) <= ?';
      args.add(dateTo);
    }
    return await db.query('inventory_audit_log', where: where, whereArgs: args, orderBy: 'action_date DESC');
  }

  // Test Hooks
  static bool _testFailAudit = false;
  static void setTestAuditFailure(bool value) => _testFailAudit = value;
  static void resetTestAuditFailure() => _testFailAudit = false;
  static bool isTestAuditFailure() => _testFailAudit;

  static Future<int> deleteRecipeLinkSafe(int productId, int materialId, {int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final matRows = await txn.query('materials', columns: ['name', 'quantity', 'cost_price'], where: 'id = ?', whereArgs: [materialId]);
      final name = matRows.isNotEmpty ? matRows.first['name'] as String? : 'Recipe Item';
      final qty = matRows.isNotEmpty ? (matRows.first['quantity'] as num).toDouble() : 0.0;
      final cost = matRows.isNotEmpty ? (matRows.first['cost_price'] as num).toDouble() : 0.0;
      
      final result = await txn.delete('recipes', where: 'parent_type = ? AND parent_id = ? AND material_id = ?', whereArgs: ['product', productId, materialId]);
      
      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');
      
      final note = {
        'audit_type': 'recipe_link_deleted',
        'product_id': productId,
        'material_id': materialId,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };
      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'recipe_link_deleted',
        'ingredient_id': materialId,
        'ingredient_name': name,
        'quantity_before': qty,
        'quantity_change': 0.0,
        'quantity_after': qty,
        'cost_price_at_action': cost,
        'reference_type': 'recipe',
        'reference_id': productId,
        'note': jsonEncode(note),
      });
      
      return result;
    });
  }

  static Future<void> resetForTest() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _testFailAudit = false;
  }

  static Future<Database> openTestDatabase({int version = 19}) async {
    // Phase 7.0: Ensure FFI is initialized for unit/integration tests on Linux
    databaseFactory = databaseFactoryFfi;
    return await openDatabase(inMemoryDatabasePath, version: version, onCreate: _onCreate);
  }

  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    await _onUpgrade(db, oldVersion, newVersion);
  }

  static Future<String> getDatabasePath() async {
    final path = await getDatabasesPath();
    return join(path, 'hot_burger.db');
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static void useTestDatabase(Database? db) {
    _database = db;
  }

  static Future<void> logInventoryAudit({
    DatabaseExecutor? db,
    required int ingredientId,
    String? ingredientName,
    required String actionType,
    required double quantityBefore,
    required double quantityChange,
    required double quantityAfter,
    required double costPriceAtAction,
    String? referenceType,
    int? referenceId,
    int? userId,
    String? userName,
    String? note,
  }) async {
    final executor = db ?? await database;
    final now = DateTime.now().toIso8601String();
    
    String? name = ingredientName;
    if (name == null) {
      final rows = await executor.query('materials', columns: ['name'], where: 'id = ?', whereArgs: [ingredientId]);
      if (rows.isNotEmpty) name = rows.first['name'] as String?;
    }

    if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');

    await executor.insert('inventory_audit_log', {
      'action_date': now,
      'action_type': actionType,
      'ingredient_id': ingredientId,
      'ingredient_name': name,
      'quantity_before': quantityBefore,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'cost_price_at_action': costPriceAtAction,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'note': jsonEncode(actorNoteForInventory(userId, userName, noteText: note)),
    });
  }

  static Future<int> insertSupplierPayment(Map<String, dynamic> payment, {int? userId, String? userName}) async {
    final db = await database;
    return await db.transaction((txn) async {
      payment['created_at'] = DateTime.now().toIso8601String();
      final paymentId = await txn.insert('supplier_payments', payment);
      
      final amount = (payment['amount'] as num).toDouble();
      final supplierId = payment['supplier_id'] as int;
      
      await txn.rawUpdate('UPDATE suppliers SET balance = balance - ?, updated_at = ? WHERE id = ?', [amount, payment['created_at'], supplierId]);
      
      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');
      
      final note = actorNoteForInventory(userId, userName, noteText: 'amount=$amount supplier_id=$supplierId');
      note['audit_type'] = 'supplier_payment';
      note['supplier_id'] = supplierId;
      note['amount'] = amount;
      
      await txn.insert('inventory_audit_log', {
        'action_date': payment['created_at'],
        'action_type': 'supplier_payment',
        'ingredient_id': 0,
        'ingredient_name': 'Supplier Payment',
        'quantity_before': 0.0,
        'quantity_change': 0.0,
        'quantity_after': 0.0,
        'cost_price_at_action': 0.0,
        'reference_type': 'supplier_payment',
        'reference_id': paymentId,
        'note': jsonEncode(note),
      });
      
      return paymentId;
    });
  }



  static Future<Map<String, dynamic>?> getShiftById(int id) async {
    final db = await database;
    final results = await db.query('shifts', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<int> deleteExpenseSafe(int id, {int? userId, String? userName, String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final expense = await txn.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (expense.isEmpty) return 0;
      final name = expense.first['name'] as String?;
      final amount = (expense.first['amount'] as num).toDouble();

      final note = {
        'audit_type': 'expense_deleted',
        'expense_id': id,
        'expense_name': name,
        'amount': amount,
        ..._auditActor(userId, userName),
        ..._auditReason(reason),
      };

      if (_testFailAudit) throw StateError('TEST HOOK: injected audit write failure');

      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': 'expense_deleted',
        'ingredient_id': 0,
        'ingredient_name': 'Expense',
        'quantity_before': amount,
        'quantity_change': -amount,
        'quantity_after': 0.0,
        'cost_price_at_action': 0.0,
        'reference_type': 'expense',
        'reference_id': id,
        'note': jsonEncode(note),
      });
      
      return await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }
}
