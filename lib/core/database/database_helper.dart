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
        password TEXT NOT NULL,
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
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

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

    // Insert default manager user
    await db.insert('users', {
      'name': Constants.managerName,
      'password': Constants.defaultPassword,
      'role': 'manager',
    });
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

  static Future<int> updateIngredientQuantity(int id, double delta) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE inventory SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
      [delta, DateTime.now().toIso8601String(), id],
    );
  }

  // ==================== PRODUCT-INGREDIENTS (RECIPE) CRUD ====================

  static Future<int> insertProductIngredient(Map<String, dynamic> link) async {
    final db = await database;
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

  // Deduct ingredients when a product is sold
  static Future<void> deductProductIngredients(int productId, int soldQuantity) async {
    final db = await database;
    final links = await getProductIngredients(productId);
    for (final link in links) {
      final ingredientId = link['ingredient_id'] as int;
      final perUnit = (link['quantity'] as num).toDouble();
      final totalDeduct = perUnit * soldQuantity;
      await updateIngredientQuantity(ingredientId, -totalDeduct);
    }
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
}
