import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Unit test: verify that changing raw material prices does NOT affect
/// historical profits saved in old invoices (cost snapshot immutability).
///
/// Test flow:
/// 1. Sale at time T1 → invoice saved with cost_snapshot frozen
/// 2. Ingredient price changed at time T2
/// 3. Product cost recalculated at time T3
/// 4. Old invoice rows must still show the same cost & profit as at T1
void main() {
  late Database db;

  setUp(() {
    sqfliteFfiInit();
  });

  tearDown(() async {
    await db.close();
  });

  test('historical profits remain unchanged after ingredient price changes',
      () async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // ---------- Schema (subset) ----------
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cost REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost_snapshot REAL NOT NULL DEFAULT 0,
        unit_profit REAL NOT NULL DEFAULT 0,
        total_profit REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE product_ingredients (
        product_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 0
      )
    ''');

    // ---------- Data ----------
    // Burger = 2 bread + 100g beef. Bread 2/unit, beef 0.1/unit → cost = 14
    await db.insert('inventory', {'name': 'bread', 'quantity': 100, 'unit': 'pcs', 'cost_price': 2.0});
    await db.insert('inventory', {'name': 'beef', 'quantity': 10, 'unit': 'kg', 'cost_price': 0.1});
    await db.insert('products', {'name': 'Burger', 'cost': 14.0});
    await db.insert('product_ingredients', {'product_id': 1, 'ingredient_id': 1, 'quantity': 2});
    await db.insert('product_ingredients', {'product_id': 1, 'ingredient_id': 2, 'quantity': 100});

    Future<double> calculateProductCost(int productId) async {
      final links = await db.query('product_ingredients',
          where: 'product_id = ?', whereArgs: [productId]);
      double total = 0;
      for (final link in links) {
        final rows = await db.query('inventory',
            where: 'id = ?', whereArgs: [link['ingredient_id']]);
        if (rows.isEmpty) continue;
        total += (link['quantity'] as num).toDouble() *
            (rows.first['cost_price'] as num).toDouble();
      }
      return total;
    }

    // ---------- T1: sale ----------
    final costAtSale = await calculateProductCost(1);
    expect(costAtSale, 14.0);
    const sellPrice = 25.0;
    const qty = 3;
    final unitProfitAtSale = sellPrice - costAtSale; // 11
    final totalProfitAtSale = unitProfitAtSale * qty; // 33
    await db.insert('invoices', {'total_amount': sellPrice * qty, 'created_at': '2026-08-01'});
    await db.insert('invoice_items', {
      'invoice_id': 1,
      'product_id': 1,
      'quantity': qty,
      'price': sellPrice,
      'cost_snapshot': costAtSale,
      'unit_profit': unitProfitAtSale,
      'total_profit': totalProfitAtSale,
    });

    // Remember T1 snapshots
    final rowT1 = (await db.query('invoice_items', where: 'id = ?', whereArgs: [1])).first;
    final snapshotT1 = (rowT1['cost_snapshot'] as num).toDouble();
    final profitT1 = (rowT1['total_profit'] as num).toDouble();

    // ---------- T2: ingredient price changes ----------
    await db.update('inventory', {'cost_price': 5.0}, where: 'name = ?', whereArgs: ['bread']);
    await db.update('inventory', {'cost_price': 0.3}, where: 'name = ?', whereArgs: ['beef']);

    // ---------- T3: cost recalculation ----------
    final newCost = await calculateProductCost(1);
    // Current cost DID change: 2*5 + 100*0.3 = 40 (was 14)
    expect(newCost, 40.0);
    expect(newCost, isNot(equals(snapshotT1)));
    await db.update('products', {'cost': newCost}, where: 'id = ?', whereArgs: [1]);

    // ---------- Verify historical row unchanged ----------
    final rowAfter = (await db.query('invoice_items', where: 'id = ?', whereArgs: [1])).first;
    expect((rowAfter['cost_snapshot'] as num).toDouble(), snapshotT1);
    expect((rowAfter['unit_profit'] as num).toDouble(), unitProfitAtSale);
    expect((rowAfter['total_profit'] as num).toDouble(), profitT1);

    // Reports aggregate over frozen snapshots (not product.cost)
    final reportRow = (await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * cost_snapshot), 0) AS cogs,
             COALESCE(SUM(total_profit), 0) AS total_profit
      FROM invoice_items
    ''')).first;
    expect((reportRow['cogs'] as num).toDouble(), 14.0 * qty);
    expect((reportRow['total_profit'] as num).toDouble(), profitT1);
  });
}
