import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/constants.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, Constants.dbFileName);
    return await openDatabase(
      path,
      version: Constants.dbVersion,
      onConfigure: (db) async {
        // Enforce all declared SQLite foreign keys consistently.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        password TEXT NOT NULL DEFAULT '',
        password_hash TEXT,
        password_salt TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        role TEXT NOT NULL DEFAULT 'manager',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        price REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        description TEXT,
        image_path TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // Raw materials table (legacy - kept for backward compatibility)
    await db.execute('''
      CREATE TABLE raw_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        supplier TEXT,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Inventory table (new ingredient model)
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'حبة',
        min_quantity REAL NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Product-Ingredients relation table (recipe linking)
    await db.execute('''
      CREATE TABLE product_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES inventory(id) ON DELETE CASCADE,
        UNIQUE (product_id, ingredient_id)
      )
    ''');

    // Invoices (sales) table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'completed',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        kitchen_status TEXT NOT NULL DEFAULT 'done',
        subtotal_amount REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Invoice items table
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        price REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        cost_snapshot REAL NOT NULL DEFAULT 0,
        unit_profit REAL NOT NULL DEFAULT 0,
        total_profit REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    // Pending POS orders (parked carts) - do not affect inventory until completed
    await db.execute('''
      CREATE TABLE pending_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT,
        discount_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pending_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (pending_order_id) REFERENCES pending_orders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_pending_orders_updated ON pending_orders(updated_at)');
    await db.execute('CREATE INDEX idx_pending_items_order ON pending_order_items(pending_order_id)');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert the default manager without persisting a plaintext password.
    final salt = _generateSalt(Constants.managerName);
    await db.insert('users', {
      'name': Constants.managerName,
      'password': '',
      'password_hash': _hashPassword(Constants.defaultPassword, salt),
      'password_salt': salt,
      'is_active': 1,
      'role': 'manager',
    });

    // Version 4 tables
    await _createVersion4Tables(db);
    await _createVersion6Tables(db);
    await _createVersion7Indexes(db);
    await _createVersion8Tables(db);
    await _createVersion9Tables(db);
    await _createVersion12Tables(db);
    await _createVersion13Tables(db);
    await _createVersion14Security(db);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_points_invoice ON customer_points_log(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_invoice_action ON invoice_audit_log(invoice_id, action_type)');
  }

  static Future<void> _createVersion4Tables(Database db) async {
    // Suppliers table
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Purchase Invoices table
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL, -- paid, partial, unpaid
        notes TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT
      )
    ''');

    // Purchase Items table
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL DEFAULT 0,
        total_cost REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES inventory(id) ON DELETE RESTRICT
      )
    ''');

    // Supplier Payments table
    await db.execute('''
      CREATE TABLE supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        purchase_invoice_id INTEGER,
        amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id) ON DELETE SET NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration from v1 to v2: Add inventory and product_ingredients tables
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          quantity REAL NOT NULL DEFAULT 0,
          unit TEXT NOT NULL DEFAULT 'حبة',
          min_quantity REAL NOT NULL DEFAULT 0,
          cost_price REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_ingredients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          ingredient_id INTEGER NOT NULL,
          quantity REAL NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
          FOREIGN KEY (ingredient_id) REFERENCES inventory(id) ON DELETE CASCADE,
          UNIQUE (product_id, ingredient_id)
        )
      ''');
    }

    // Migration from v2 to v3: Add payment_method column to invoices
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE invoices ADD COLUMN payment_method TEXT NOT NULL DEFAULT "cash"');
    }

    // Migration from v3 to v4: Add purchases and suppliers
    if (oldVersion < 4) {
      await _createVersion4Tables(db);
    }

    // Migration from v4 to v5: Add cost snapshot columns to invoice_items
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE invoice_items ADD COLUMN cost_snapshot REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE invoice_items ADD COLUMN unit_profit REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE invoice_items ADD COLUMN total_profit REAL NOT NULL DEFAULT 0');
    }

    // Migration from v5 to v6: Add inventory audit trail table
    if (oldVersion < 6) {
      await _createVersion6Tables(db);
    }

    // Migration from v6 to v7: performance indexes for reporting and POS lookups
    if (oldVersion < 7) {
      await _createVersion7Indexes(db);
    }

    // Migration from v7 to v8: invoice audit trail and unique invoice numbers
    if (oldVersion < 8) {
      await _createVersion8Tables(db);
    }

    // Migration from v8 to v9: secure user authentication and cashier shifts.
    if (oldVersion < 9) {
      await _createVersion9Tables(db);
    }

    // Migration from v9 to v10: professional POS payment and discount fields.
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE invoices ADD COLUMN subtotal_amount REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE invoices ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE invoices ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE invoices ADD COLUMN change_amount REAL NOT NULL DEFAULT 0');
      await db.execute("UPDATE invoices SET subtotal_amount = total_amount WHERE subtotal_amount = 0");
    }

    // Migration from v10 to v11: parked POS orders and safer invoice returns.
    if (oldVersion < 11) {
      await _createVersion11Tables(db);
    }
    // Migration from v11 to v12: Kitchen Display System workflow.
    if (oldVersion < 12) {
      await _createVersion12Tables(db);
    }
    // Migration from v12 to v13: customers and loyalty program.
    if (oldVersion < 13) {
      await _createVersion13Tables(db);
    }
    if (oldVersion < 14) {
      await _createVersion14Security(db);
    }
    // Migration from v14 to v15: production hardening metadata/indexes.
    if (oldVersion < 15) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_points_invoice ON customer_points_log(invoice_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_invoice_action ON invoice_audit_log(invoice_id, action_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_product_ingredients_ingredient ON product_ingredients(ingredient_id)');
    }
  }

  static Future<void> _createVersion13Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        points INTEGER NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        visit_count INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    final invoiceColumns = await db.rawQuery('PRAGMA table_info(invoices)');
    if (!invoiceColumns.any((c) => c['name'] == 'customer_id')) {
      await db.execute('ALTER TABLE invoices ADD COLUMN customer_id INTEGER');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_points_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        invoice_id INTEGER,
        points_change INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_points_log_customer ON customer_points_log(customer_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id, created_at)');
  }

  static Future<void> _createVersion12Tables(Database db) async {
    // Existing invoices are considered completed in the kitchen.
    final columns = await db.rawQuery('PRAGMA table_info(invoices)');
    final hasKitchenStatus = columns.any((c) => c['name'] == 'kitchen_status');
    if (!hasKitchenStatus) {
      await db.execute("ALTER TABLE invoices ADD COLUMN kitchen_status TEXT NOT NULL DEFAULT 'done'");
    }
    await db.execute("CREATE INDEX IF NOT EXISTS idx_invoices_kitchen_status_created ON invoices(kitchen_status, created_at)");
  }

  static Future<void> _createVersion11Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT,
        discount_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pending_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (pending_order_id) REFERENCES pending_orders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_orders_updated ON pending_orders(updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_items_order ON pending_order_items(pending_order_id)');
  }

  // Creates v9 authentication and cashier-shift tables.
  static Future<void> _createVersion9Tables(Database db) async {
    final userColumns = await db.rawQuery('PRAGMA table_info(users)');
    final names = userColumns.map((c) => c['name']).whereType<String>().toSet();
    if (!names.contains('password_hash')) {
      await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
    }
    if (!names.contains('is_active')) {
      await db.execute('ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
    }
    if (!names.contains('password_salt')) {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    }
    final users = await db.query('users', columns: ['id', 'password', 'password_hash']);
    for (final user in users) {
      final hash = user['password_hash']?.toString();
      final password = user['password']?.toString();
      if ((hash == null || hash.isEmpty) && password != null && password.isNotEmpty) {
        final salt = _generateSalt('${user['id']}-${password.length}');
        await db.update('users', {
          'password_hash': _hashPassword(password, salt),
          'password_salt': salt,
          'password': '',
        }, where: 'id = ?', whereArgs: [user['id']]);
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash REAL NOT NULL DEFAULT 0,
        expected_cash REAL,
        actual_cash REAL,
        difference REAL,
        status TEXT NOT NULL DEFAULT 'open',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_status_opened ON shifts(status, opened_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_user_opened ON shifts(user_id, opened_at)');
  }

  static String _generateSalt(String seed) {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode('$seed:$now:${Constants.appName}')).toString().substring(0, 32);
  }

  static String _hashPassword(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    // A small key-stretching loop is appropriate for short offline PINs while
    // remaining lightweight enough for a POS login screen.
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(utf8.encode('$salt:${digest.toString()}'));
    }
    return digest.toString();
  }

  static Future<void> _createVersion14Security(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(users)');
    final names = columns.map((c) => c['name']).whereType<String>().toSet();
    if (!names.contains('password_salt')) {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    }
    final users = await db.query('users', columns: ['id', 'password', 'password_hash', 'password_salt']);
    // Existing v9-v13 hashes remain valid until the next successful login,
    // where AppProvider upgrades them to a salted hash.
    for (final user in users) {
      final legacyPassword = user['password']?.toString() ?? '';
      final hash = user['password_hash']?.toString() ?? '';
      final salt = user['password_salt']?.toString() ?? '';
      if (legacyPassword.isNotEmpty && hash.isEmpty) {
        final newSalt = _generateSalt('${user['id']}');
        await db.update('users', {
          'password_hash': _hashPassword(legacyPassword, newSalt),
          'password_salt': newSalt,
          'password': '',
        }, where: 'id = ?', whereArgs: [user['id']]);
      } else if (hash.isNotEmpty && salt.isEmpty) {
        // Keep the old unsalted hash for compatibility; it will be upgraded
        // after the user proves knowledge of the password during login.
      }
    }
  }

  // Creates v8 audit trail for financial actions.
  static Future<void> _createVersion8Tables(Database db) async {
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_status_created ON invoices(status, created_at)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_number_unique ON invoices(invoice_number)');
  }

  // Creates v7 indexes used by the dashboard, POS, inventory and reports.
  static Future<void> _createVersion7Indexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_payment_method ON invoices(payment_method)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id ON invoice_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_quantity ON inventory(quantity, min_quantity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_audit_ingredient_date ON inventory_audit_log(ingredient_id, action_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_product_ingredients_product ON product_ingredients(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_product_ingredients_ingredient ON product_ingredients(ingredient_id)');
  }

  // Creates v6 tables: inventory audit trail log
  static Future<void> _createVersion6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_date TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now', 'localtime')),
        action_type TEXT NOT NULL,
        ingredient_id INTEGER,
        ingredient_name TEXT,
        quantity_before REAL NOT NULL DEFAULT 0,
        quantity_change REAL NOT NULL DEFAULT 0,
        quantity_after REAL NOT NULL DEFAULT 0,
        cost_price_at_action REAL NOT NULL DEFAULT 0,
        reference_type TEXT,
        reference_id INTEGER,
        note TEXT
      )
    ''');
  }

  // ==================== INVENTORY AUDIT TRAIL ====================

  // Central audit logging: every inventory movement goes through this function
  static Future<void> logInventoryAudit({
    required String actionType,
    int? ingredientId,
    String? ingredientName,
    required double quantityBefore,
    required double quantityChange,
    required double quantityAfter,
    required double costPriceAtAction,
    String? referenceType,
    int? referenceId,
    String? note,
  }) async {
    final db = await database;
    await db.insert('inventory_audit_log', {
      'action_date': DateTime.now().toIso8601String(),
      'action_type': actionType,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity_before': quantityBefore,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'cost_price_at_action': costPriceAtAction,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'note': note,
    });
  }

  static Future<List<Map<String, dynamic>>> getInventoryAuditLogs({
    String? query,
    String? actionType,
    int? ingredientId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final args = <dynamic>[];
    if (query != null && query.isNotEmpty) {
      whereClauses.add('(ingredient_name LIKE ? OR action_type LIKE ? OR note LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    if (actionType != null) {
      whereClauses.add('action_type = ?');
      args.add(actionType);
    }
    if (ingredientId != null) {
      whereClauses.add('ingredient_id = ?');
      args.add(ingredientId);
    }
    if (dateFrom != null) {
      whereClauses.add('action_date >= ?');
      args.add(dateFrom);
    }
    if (dateTo != null) {
      whereClauses.add('action_date <= ?');
      args.add('$dateTo 23:59:59');
    }
    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final results = await db.query(
      'inventory_audit_log',
      where: where,
      whereArgs: args,
      orderBy: 'action_date DESC',
    );
    return results;
  }

  static Future<int> getInventoryAuditLogCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM inventory_audit_log');
    return (result.first['count'] as num).toInt();
  }

  // ==================== INVENTORY CRUD ====================

  static Future<int> insertIngredient(Map<String, dynamic> ingredient) async {
    final db = await database;
    ingredient['updated_at'] = DateTime.now().toIso8601String();
    ingredient['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('inventory', ingredient);
  }

  static Future<List<Map<String, dynamic>>> getIngredients() async {
    final db = await database;
    return await db.query('inventory', orderBy: 'name ASC');
  }

  static Future<List<Map<String, dynamic>>> getLowStockIngredients() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM inventory WHERE quantity <= min_quantity ORDER BY (min_quantity - quantity) DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getIngredientById(int id) async {
    final db = await database;
    return await db.query('inventory', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> updateIngredient(int id, Map<String, dynamic> ingredient) async {
    final db = await database;
    ingredient['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('inventory', ingredient, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteIngredient(int id) async {
    final db = await database;
    return await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  /// Update ingredient quantity and atomically log the movement in the audit trail.
  /// Every quantity change (sale deduction, purchase, manual adjust, restoration)
  /// goes through this function so no movement is ever recorded without a reason.
  static Future<int> updateIngredientQuantity(
    int id, {
    required double delta,
    required String actionType,
    int? referenceId,
    String? referenceType,
    String? note,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Read current state
      final current = await txn.query('inventory',
          columns: ['quantity', 'cost_price', 'name'], where: 'id = ?', whereArgs: [id]);
      final beforeQty = current.isNotEmpty ? (current.first['quantity'] as num).toDouble() : 0;
      final costPrice = current.isNotEmpty ? (current.first['cost_price'] as num).toDouble() : 0;
      final name = current.isNotEmpty ? current.first['name'] as String? : null;

      // 2. Apply the change
      final result = await txn.rawUpdate(
        'UPDATE inventory SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
        [delta, DateTime.now().toIso8601String(), id],
      );

      // 3. Log the movement together with the update (single unit of work)
      await txn.insert('inventory_audit_log', {
        'action_date': DateTime.now().toIso8601String(),
        'action_type': actionType,
        'ingredient_id': id,
        'ingredient_name': name,
        'quantity_before': beforeQty,
        'quantity_change': delta,
        'quantity_after': beforeQty + delta,
        'cost_price_at_action': costPrice,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'note': note,
      });
      return result;
    });
  }

  // ==================== PRODUCT-INGREDIENTS (RECIPE) CRUD ====================

  static Future<int> insertProductIngredient(Map<String, dynamic> link) async {
    final db = await database;
    final quantity = (link['quantity'] as num?)?.toDouble() ?? 0;
    if (quantity <= 0) {
      throw ArgumentError('Recipe ingredient quantity must be greater than zero');
    }
    final productId = link['product_id'];
    final ingredientId = link['ingredient_id'];
    if (productId == null || ingredientId == null) {
      throw ArgumentError('Recipe product and ingredient are required');
    }
    link['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('product_ingredients', link,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getProductIngredients(int productId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pi.id, pi.product_id, pi.ingredient_id, pi.quantity,
             inv.name AS ingredient_name, inv.unit, inv.quantity AS current_stock
      FROM product_ingredients pi
      INNER JOIN inventory inv ON pi.ingredient_id = inv.id
      WHERE pi.product_id = ?
      ORDER BY inv.name ASC
    ''', [productId]);
  }

  static Future<List<Map<String, dynamic>>> getIngredientsByProduct(int productId) async {
    final db = await database;
    return await db.query(
      'product_ingredients',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'ingredient_id ASC',
    );
  }

  /// Get IDs of products that use a specific ingredient (for auto cost recalculation)
  static Future<List<int>> getProductIdsByIngredient(int ingredientId) async {
    final db = await database;
    final results = await db.query(
      'product_ingredients',
      columns: ['product_id'],
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
    );
    return results.map((r) => r['product_id'] as int).toList();
  }

  static Future<int> deleteProductIngredient(int productId, int ingredientId) async {
    final db = await database;
    return await db.delete(
      'product_ingredients',
      where: 'product_id = ? AND ingredient_id = ?',
      whereArgs: [productId, ingredientId],
    );
  }

  static Future<int> deleteAllProductIngredients(int productId) async {
    final db = await database;
    return await db.delete(
      'product_ingredients',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  // Deduct ingredients when a product is sold (logged as 'sale' movement).
  // Keep the recipe lookup, stock update, and audit log on the SAME transaction;
  // starting a second transaction from inside this transaction can break atomicity.
  static Future<void> deductProductIngredients(int productId, int soldQuantity, {int? invoiceId}) async {
    if (soldQuantity <= 0) {
      throw ArgumentError('Sold quantity must be greater than zero');
    }
    final db = await database;
    await db.transaction((txn) async {
      final links = await txn.rawQuery('''
        SELECT pi.ingredient_id, pi.quantity,
               inv.name AS ingredient_name, inv.quantity AS current_stock,
               inv.cost_price
        FROM product_ingredients pi
        INNER JOIN inventory inv ON pi.ingredient_id = inv.id
        WHERE pi.product_id = ?
      ''', [productId]);

      for (final link in links) {
        final ingredientId = link['ingredient_id'] as int;
        final perUnit = (link['quantity'] as num).toDouble();
        if (perUnit <= 0) {
          throw StateError('Invalid recipe quantity for ingredient $ingredientId');
        }

        final totalDeduct = perUnit * soldQuantity;
        final beforeQty = (link['current_stock'] as num).toDouble();
        final costPrice = (link['cost_price'] as num).toDouble();
        final name = link['ingredient_name'] as String?;

        final result = await txn.rawUpdate(
          'UPDATE inventory SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
          [totalDeduct, DateTime.now().toIso8601String(), ingredientId],
        );
        if (result != 1) {
          throw StateError('Failed to update inventory for ingredient $ingredientId');
        }

        await txn.insert('inventory_audit_log', {
          'action_date': DateTime.now().toIso8601String(),
          'action_type': 'sale',
          'ingredient_id': ingredientId,
          'ingredient_name': name,
          'quantity_before': beforeQty,
          'quantity_change': -totalDeduct,
          'quantity_after': beforeQty - totalDeduct,
          'cost_price_at_action': costPrice,
          'reference_type': 'invoice',
          'reference_id': invoiceId,
        });
      }
    });
  }

  // Helper method to get database path for backup
  static Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, Constants.dbFileName);
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ==================== SUPPLIERS CRUD ====================

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

  static Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final db = await database;
    final results = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<int> updateSupplier(int id, Map<String, dynamic> supplier) async {
    final db = await database;
    supplier['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('suppliers', supplier, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== PURCHASES CRUD & LOGIC ====================

  static Future<int> insertPurchaseInvoice(Map<String, dynamic> invoice, List<Map<String, dynamic>> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Insert Invoice
      invoice['created_at'] = DateTime.now().toIso8601String();
      final invoiceId = await txn.insert('purchase_invoices', invoice);

      // 2. Process Items
      for (var item in items) {
        final ingredientId = item['ingredient_id'] as int;
        final newQty = (item['quantity'] as num).toDouble();
        final newCost = (item['unit_cost'] as num).toDouble();

        if (newQty <= 0) {
          throw ArgumentError('Purchase quantity must be greater than zero');
        }
        if (newCost < 0) {
          throw ArgumentError('Purchase unit cost cannot be negative');
        }

        // Get old data for weighted average cost
        final oldData = await txn.query('inventory', columns: ['quantity', 'cost_price'], where: 'id = ?', whereArgs: [ingredientId]);
        if (oldData.isNotEmpty) {
          final oldQty = (oldData.first['quantity'] as num).toDouble();
          final oldCost = (oldData.first['cost_price'] as num).toDouble();

          // Calculate weighted average cost
          double averageCost = newCost;
          if (oldQty + newQty > 0) {
            averageCost = (oldQty * oldCost + newQty * newCost) / (oldQty + newQty);
          }

          // Update Inventory: Quantity and Cost Price
          await txn.rawUpdate(
            'UPDATE inventory SET quantity = quantity + ?, cost_price = ?, updated_at = ? WHERE id = ?',
            [newQty, averageCost, DateTime.now().toIso8601String(), ingredientId],
          );

          // Audit trail: log the purchase movement inside the transaction (atomic unit)
          await txn.insert('inventory_audit_log', {
            'action_date': DateTime.now().toIso8601String(),
            'action_type': 'purchase',
            'ingredient_id': ingredientId,
            'quantity_before': oldQty,
            'quantity_change': newQty,
            'quantity_after': oldQty + newQty,
            'cost_price_at_action': averageCost,
            'reference_type': 'purchase_invoice',
            'reference_id': invoiceId,
          });
        }

        // Insert Purchase Item
        item['purchase_invoice_id'] = invoiceId;
        await txn.insert('purchase_items', item);
      }

      // 3. Update Supplier Balance
      final totalAmount = (invoice['total_amount'] as num).toDouble();
      final paidAmount = (invoice['paid_amount'] as num).toDouble();
      final remaining = totalAmount - paidAmount;

      if (remaining != 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [remaining, DateTime.now().toIso8601String(), invoice['supplier_id']],
        );
      }

      return invoiceId;
    });
  }

  /// Recalculate product costs for all products using the given ingredient (called after a purchase updates cost_price)
  static Future<void> recalculateProductCostsForIngredient(int ingredientId) async {
    final db = await database;
    await db.transaction((txn) async {
      final productIds = await txn.query(
        'product_ingredients',
        columns: ['product_id'],
        where: 'ingredient_id = ?',
        whereArgs: [ingredientId],
      );
      final now = DateTime.now().toIso8601String();
      for (final row in productIds) {
        final productId = row['product_id'] as int;
        final links = await txn.rawQuery('''
          SELECT pi.quantity, inv.cost_price
          FROM product_ingredients pi
          INNER JOIN inventory inv ON pi.ingredient_id = inv.id
          WHERE pi.product_id = ?
        ''', [productId]);
        final newCost = links.fold<double>(0, (sum, link) {
          final quantity = (link['quantity'] as num).toDouble();
          final cost = (link['cost_price'] as num).toDouble();
          return sum + quantity * cost;
        });
        await txn.update(
          'products',
          {'cost': newCost, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getPurchaseInvoices({int? supplierId}) async {
    final db = await database;
    if (supplierId != null) {
      return await db.rawQuery('''
        SELECT pi.*, s.name as supplier_name 
        FROM purchase_invoices pi
        INNER JOIN suppliers s ON pi.supplier_id = s.id
        WHERE pi.supplier_id = ?
        ORDER BY pi.date DESC
      ''', [supplierId]);
    } else {
      return await db.rawQuery('''
        SELECT pi.*, s.name as supplier_name 
        FROM purchase_invoices pi
        INNER JOIN suppliers s ON pi.supplier_id = s.id
        ORDER BY pi.date DESC
      ''');
    }
  }

  static Future<List<Map<String, dynamic>>> getPurchaseItems(int invoiceId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pit.*, inv.name as ingredient_name
      FROM purchase_items pit
      INNER JOIN inventory inv ON pit.ingredient_id = inv.id
      WHERE pit.purchase_invoice_id = ?
    ''', [invoiceId]);
  }

  // ==================== PAYMENTS CRUD ====================

  static Future<int> insertSupplierPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.transaction((txn) async {
      payment['created_at'] = DateTime.now().toIso8601String();
      final paymentId = await txn.insert('supplier_payments', payment);

      // Deduct from supplier balance
      final amount = (payment['amount'] as num).toDouble();
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance - ?, updated_at = ? WHERE id = ?',
        [amount, DateTime.now().toIso8601String(), payment['supplier_id']],
      );

      return paymentId;
    });
  }

  static Future<List<Map<String, dynamic>>> getSupplierLedger(int supplierId) async {
    final db = await database;
    // Combined list of invoices (debit) and payments (credit)
    final invoices = await db.query('purchase_invoices', where: 'supplier_id = ?', whereArgs: [supplierId]);
    final payments = await db.query('supplier_payments', where: 'supplier_id = ?', whereArgs: [supplierId]);

    List<Map<String, dynamic>> ledger = [];
    for (var inv in invoices) {
      ledger.add({
        'type': 'invoice',
        'id': inv['id'],
        'number': inv['invoice_number'],
        'amount': inv['total_amount'],
        'date': inv['date'],
        'notes': inv['notes'],
      });
    }
    for (var pay in payments) {
      ledger.add({
        'type': 'payment',
        'id': pay['id'],
        'amount': pay['amount'],
        'date': pay['date'],
        'notes': pay['notes'],
      });
    }

    ledger.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return ledger;
  }
}
