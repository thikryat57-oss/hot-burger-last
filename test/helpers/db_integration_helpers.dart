// Minimal SQLite integration test fixtures (Phase 2.3).
//
// No framework, no mock objects: each helper is a tiny wrapper around raw SQL
// so tests read exactly like the schema they exercise.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'package:hot_burger_last/providers/app_provider.dart';

/// Opens a fresh, isolated in-memory database with the PRODUCTION schema and
/// runs the full migration ladder (same as every real device boot).
Future<Database> openIntegrationTestDatabase() =>
    DatabaseHelper.openTestDatabase();

/// Opens a RAW in-memory database WITHOUT production handlers and seeds it
/// with the v1 baseline schema: exactly the tables a v1 device had, using
/// the production CREATE statements verbatim (guarded with IF NOT EXISTS so
/// the migration ladder can re-run them safely) and `user_version = 1`.
/// This simulates a real device running its first app upgrade.
Future<Database> openRawV1Database() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  for (final ddl in _v1SchemaDdl) {
    await db.execute(ddl);
  }
  await db.execute('PRAGMA user_version = 1');
  return db;
}

/// v1 baseline DDL — extracted verbatim from production _onCreate so the
/// migration ladder (production code) exercises the exact same statements
/// a real device would on first upgrade. Only the v1-era tables are
/// included; the ladder adds every later table/column itself.
const List<String> _v1SchemaDdl = [
  '''CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    password TEXT NOT NULL DEFAULT '',
    password_hash TEXT,
    password_salt TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    role TEXT NOT NULL DEFAULT 'manager',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''CREATE TABLE IF NOT EXISTS products (
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
  )''',
  '''CREATE TABLE IF NOT EXISTS raw_materials (
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
  )''',
  // NOTE: these are the v1-era columns only. payment_method (v3),
  // subtotal/discount/paid/change (v6), kitchen_status (v9), customer_id
  // (v10) are added to invoices by the migration ladder — adding them here
  // would duplicate them and fail the upgrade on a real device.
  '''CREATE TABLE IF NOT EXISTS invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number TEXT NOT NULL,
    total_amount REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'completed',
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  // NOTE: cost_snapshot/unit_profit/total_profit (v5) and recipe_snapshot
  // (v16) are added to invoice_items by the migration ladder.
  '''CREATE TABLE IF NOT EXISTS invoice_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    price REAL NOT NULL DEFAULT 0,
    total REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  // NOTE: these v4 tables MUST be present in the v1 baseline because
  // production _createVersion4Tables (called by the ladder at oldVersion < 4)
  // creates them WITHOUT an IF NOT EXISTS guard. A real v1-to-v4+ device
  // would hit the same "table already exists" failure — this baseline
  // therefore documents the only shape a pre-v4 device could have survived
  // the upgrade path from, while the baseline's guarded CREATE statements
  // verify that everything the ladder adds later lands correctly.
  '''CREATE TABLE IF NOT EXISTS pending_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT,
    discount_amount REAL NOT NULL DEFAULT 0,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''CREATE TABLE IF NOT EXISTS pending_order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pending_order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    product_name TEXT NOT NULL,
    price REAL NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1,
    total REAL NOT NULL DEFAULT 0,
    FOREIGN KEY (pending_order_id) REFERENCES pending_orders(id) ON DELETE CASCADE
  )''',
  '''CREATE TABLE IF NOT EXISTS expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    amount REAL NOT NULL DEFAULT 0,
    date TEXT NOT NULL,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''CREATE TABLE IF NOT EXISTS suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    notes TEXT,
    balance REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''CREATE TABLE IF NOT EXISTS purchase_invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id INTEGER NOT NULL,
    invoice_number TEXT NOT NULL,
    total_amount REAL NOT NULL DEFAULT 0,
    paid_amount REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    notes TEXT,
    date TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT
  )''',
  '''CREATE TABLE IF NOT EXISTS purchase_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_invoice_id INTEGER NOT NULL,
    ingredient_id INTEGER NOT NULL,
    quantity REAL NOT NULL DEFAULT 0,
    unit_cost REAL NOT NULL DEFAULT 0,
    total_cost REAL NOT NULL DEFAULT 0,
    FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id) ON DELETE CASCADE,
    FOREIGN KEY (ingredient_id) REFERENCES inventory(id) ON DELETE RESTRICT
  )''',
  '''CREATE TABLE IF NOT EXISTS supplier_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id INTEGER NOT NULL,
    purchase_invoice_id INTEGER,
    amount REAL NOT NULL DEFAULT 0,
    date TEXT NOT NULL,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id) ON DELETE SET NULL
  )''',
];

/// Seeds a manager user and opens an AppProvider wired to the test database.
/// The returned provider is owned by the caller and closed in tearDown via
/// [disposeAppProvider].
Future<AppProvider> openTestProvider(Database db) async {
  final provider = AppProvider();
  await provider.initDatabase();
  // A completed sale requires an open shift, and opening a shift requires a
  // logged-in manager user. Sign in with a legacy-plaintext row (login() also
  // accepts empty salt+hash and a matching `password` column).
  await db.insert('users', {
    'name': 'Manager Test',
    'password': 'integration_test_pw',
    'password_hash': '',
    'password_salt': '',
    'is_active': 1,
    'role': 'manager',
  });
  final ok = await provider.login('integration_test_pw');
  if (!ok) {
    throw StateError('integration test login failed');
  }
  await provider.openShift(0);
  return provider;
}

void disposeAppProvider(AppProvider provider) {
  // Provider has no public close; nothing to do beyond clearing the hook.
  provider.dispose();
}

/// Seeds a raw material with initial stock.
Future<int> seedIngredient(Database db, String name, double stock,
    {double costPrice = 1.0, String unit = 'حبة'}) {
  return db.insert('inventory', {
    'name': name,
    'quantity': stock,
    'unit': unit,
    'cost_price': costPrice,
  });
}

/// Seeds a product (skip cost; snapshot-based finance reads it anyway).
Future<int> seedProduct(Database db, String name, double price) =>
    db.insert('products', {'name': name, 'price': price, 'cost': 0});

/// Seeds the recipe for [productId]: map of ingredient_id → per-unit quantity.
Future<void> seedRecipe(Database db, int productId,
    Map<int, double> perUnit) async {
  for (final entry in perUnit.entries) {
    await db.insert('product_ingredients', {
      'product_id': productId,
      'ingredient_id': entry.key,
      'quantity': entry.value,
    });
  }
}

/// Reads the per-ingredient deltas recorded in inventory_audit_log for the
/// given invoice (all reference types).
Future<List<Map<String, dynamic>>> auditRowsForInvoice(
    Database db, int invoiceId) {
  return db.query('inventory_audit_log',
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: ['invoice', invoiceId]);
}

/// Total quantity delta per ingredient across all audit rows for the invoice.
Future<Map<int, double>> auditDeltaPerIngredient(
    Database db, int invoiceId) async {
  final rows = await auditRowsForInvoice(db, invoiceId);
  final out = <int, double>{};
  for (final row in rows) {
    final id = row['ingredient_id'] as int;
    final change = (row['quantity_change'] as num).toDouble();
    out[id] = (out[id] ?? 0) + change;
  }
  return out;
}

/// Invoice status after mutations.
Future<String> invoiceStatus(Database db, int invoiceId) async {
  final rows = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId], limit: 1);
  return rows.first['status'].toString();
}

/// Inventory level for one ingredient (or null if the row was deleted).
Future<double?> inventoryLevel(Database db, int ingredientId) async {
  final rows = await db.query('inventory',
      where: 'id = ?', whereArgs: [ingredientId], limit: 1);
  if (rows.isEmpty) return null;
  return (rows.first['quantity'] as num).toDouble();
}

/// Reads the stored recipe snapshot JSON for one invoice line.
Future<String?> recipeSnapshotFor(Database db, int itemId) async {
  final rows = await db.query('invoice_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
  return rows.first['recipe_snapshot']?.toString();
}
