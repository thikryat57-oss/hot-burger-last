// Minimal SQLite integration test fixtures (Phase 2.3).
//
// No framework, no mock objects: each helper is a tiny wrapper around raw SQL
// so tests read exactly like the schema they exercise.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hot_burger_last/core/database/database_helper.dart';
import 'package:hot_burger_last/providers/app_provider.dart';

/// Opens a fresh, isolated in-memory database with the PRODUCTION schema and
/// runs the full migration ladder (same as every real device boot).
Future<Database> openIntegrationTestDatabase() =>
    DatabaseHelper.openTestDatabase();

/// Seeds a manager user and opens an AppProvider wired to the test database.
/// The returned provider is owned by the caller and closed in tearDown via
/// [disposeAppProvider].
Future<AppProvider> openTestProvider(Database db) async {
  final provider = AppProvider(db);
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
