import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  Future<List<User>> getActiveUsers() async {
    final results = await _db!.query('users', where: 'is_active = 1', orderBy: 'name ASC');
    return results.map((e) => User.fromMap(e)).toList();
  }

  String _generateSalt() => sha256.convert(utf8.encode(
        '${DateTime.now().microsecondsSinceEpoch}:${_currentUser?.id ?? 'user'}:HotBurger',
      )).toString().substring(0, 32);

  String _hashPassword(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(utf8.encode('$salt:${digest.toString()}'));
    }
    return digest.toString();
  }

  Future<bool> login(String password, {int? userId}) async {
    final where = userId == null ? 'is_active = 1' : 'id = ? AND is_active = 1';
    final args = userId == null ? null : [userId];
    final results = await _db!.query('users', where: where, whereArgs: args);
    for (final row in results) {
      final storedHash = row['password_hash']?.toString() ?? '';
      final storedSalt = row['password_salt']?.toString() ?? '';
      final legacy = row['password']?.toString() ?? '';
      var valid = false;
      var needsUpgrade = false;
      if (storedHash.isNotEmpty && storedSalt.isNotEmpty) {
        valid = storedHash == _hashPassword(password, storedSalt);
      } else if (storedHash.isNotEmpty) {
        // v9-v13 compatibility: verify the old unsalted hash once, then upgrade.
        valid = storedHash == sha256.convert(utf8.encode(password)).toString();
        needsUpgrade = valid;
      } else {
        valid = legacy == password;
        needsUpgrade = valid;
      }
      if (valid) {
        if (needsUpgrade || storedSalt.isEmpty) {
          final salt = _generateSalt();
          await _db!.update('users', {
            'password_hash': _hashPassword(password, salt),
            'password_salt': salt,
            'password': '',
          }, where: 'id = ?', whereArgs: [row['id']]);
        }
        final refreshed = await _db!.query('users', where: 'id = ?', whereArgs: [row['id']], limit: 1);
        _currentUser = User.fromMap(refreshed.first);
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool get isManager => _currentUser?.role == 'manager';
  bool get isCashier => _currentUser?.role == 'cashier';
  bool canManageCatalog() => isManager;
  bool canManageFinance() => isManager;
  bool canManageUsers() => isManager;
  bool canVoidInvoice() => isManager;

  Future<int> addUser({required String name, required String password, required String role}) async {
    if (!isManager) throw Exception('هذه العملية متاحة للمدير فقط');
    if (!{'manager', 'cashier'}.contains(role)) throw Exception('دور المستخدم غير صالح');
    if (name.trim().isEmpty || password.length < 4) throw Exception('الاسم ورمز الدخول غير صالحين');
    final exists = await _db!.query('users', where: 'name = ?', whereArgs: [name.trim()], limit: 1);
    if (exists.isNotEmpty) throw Exception('اسم المستخدم موجود بالفعل');
    final salt = _generateSalt();
    final id = await _db!.insert('users', {
      'name': name.trim(),
      'password': '',
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
      'role': role,
      'is_active': 1,
    });
    notifyListeners();
    return id;
  }

  Future<int> updateUserPassword(int id, String password) async {
    if (!isManager) throw Exception('هذه العملية متاحة للمدير فقط');
    if (password.length < 4) throw Exception('رمز الدخول يجب أن يكون 4 أرقام على الأقل');
    final salt = _generateSalt();
    final result = await _db!.update('users', {
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
      'password': '',
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  Future<int> setUserActive(int id, bool active) async {
    if (!isManager) throw Exception('هذه العملية متاحة للمدير فقط');
    if (id == _currentUser?.id && !active) throw Exception('لا يمكنك تعطيل المستخدم الحالي');
    final result = await _db!.update('users', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // ==================== CASHIER SHIFTS ====================

  Future<Shift?> getOpenShift() async {
    final rows = await _db!.query('shifts', where: 'status = ?', whereArgs: ['open'], orderBy: 'opened_at DESC', limit: 1);
    return rows.isEmpty ? null : Shift.fromMap(rows.first);
  }

  Future<Shift?> getCurrentUserOpenShift() async {
    if (_currentUser?.id == null) return null;
    final rows = await _db!.query(
      'shifts',
      where: 'status = ? AND user_id = ?',
      whereArgs: ['open', _currentUser!.id],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Shift.fromMap(rows.first);
  }

  Future<int> openShift(double openingCash, {String? notes}) async {
    if (_currentUser?.id == null) throw Exception('يجب تسجيل الدخول أولاً');
    final existing = await getOpenShift();
    if (existing != null) throw Exception('توجد وردية مفتوحة حاليًا بواسطة ${existing.userName}');
    return _db!.insert('shifts', {
      'user_id': _currentUser!.id,
      'user_name': _currentUser!.name,
      'opened_at': DateTime.now().toIso8601String(),
      'opening_cash': openingCash,
      'status': 'open',
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> getCurrentShiftCashSummary() async {
    final shift = await getCurrentUserOpenShift();
    if (shift == null) throw Exception('لا توجد وردية مفتوحة');
    final result = await _db!.rawQuery(
      "SELECT COALESCE(SUM(total_amount),0) AS sales FROM invoices WHERE status NOT IN ('cancelled','returned') AND payment_method = 'cash' AND created_at >= ?",
      [shift.openedAt],
    );
    final sales = (result.first['sales'] as num?)?.toDouble() ?? 0;
    final expenses = await _db!.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS expenses FROM expenses WHERE created_at >= ?',
      [shift.openedAt],
    );
    final expenseTotal = (expenses.first['expenses'] as num?)?.toDouble() ?? 0;
    final expected = shift.openingCash + sales - expenseTotal;
    return {'shift': shift, 'cashSales': sales, 'expenses': expenseTotal, 'expectedCash': expected};
  }

  Future<int> closeShift(double actualCash, {String? notes}) async {
    final summary = await getCurrentShiftCashSummary();
    final shift = summary['shift'] as Shift;
    final expected = summary['expectedCash'] as double;
    final now = DateTime.now().toIso8601String();
    final difference = actualCash - expected;
    final result = await _db!.update('shifts', {
      'closed_at': now,
      'expected_cash': expected,
      'actual_cash': actualCash,
      'difference': difference,
      'status': 'closed',
      'notes': notes,
    }, where: 'id = ? AND status = ?', whereArgs: [shift.id, 'open']);
    notifyListeners();
    return result;
  }

  Future<List<Shift>> getShifts({int limit = 50}) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    final rows = await _db!.query(
      'shifts',
      where: isManager ? null : 'user_id = ?',
      whereArgs: isManager ? null : [_currentUser!.id],
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return rows.map((e) => Shift.fromMap(e)).toList();
  }


  // ==================== KITCHEN DISPLAY SYSTEM ====================

  /// Returns active kitchen tickets with their line items.
  Future<List<Map<String, dynamic>>> getKitchenOrders() async {
    final rows = await _db!.rawQuery('''
      SELECT i.id, i.invoice_number, i.kitchen_status, i.created_at,
             i.payment_method, i.total_amount, c.name AS customer_name,
             COUNT(ii.id) AS item_count
      FROM invoices i
      LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
      LEFT JOIN customers c ON c.id = i.customer_id
      WHERE i.status = 'completed' AND i.kitchen_status IN ('new','preparing','ready')
      GROUP BY i.id
      ORDER BY CASE i.kitchen_status
        WHEN 'new' THEN 1
        WHEN 'preparing' THEN 2
        WHEN 'ready' THEN 3
        ELSE 4 END,
        i.created_at ASC
    ''');

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final items = await _db!.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id ASC',
      );
      result.add({...row, 'items': items});
    }
    return result;
  }

  Future<int> updateKitchenStatus(int invoiceId, String status) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    const allowed = {'new', 'preparing', 'ready', 'delivered'};
    if (!allowed.contains(status)) throw Exception('حالة المطبخ غير صالحة');

    final current = await _db!.query(
      'invoices',
      columns: ['id', 'status', 'kitchen_status'],
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (current.isEmpty) throw Exception('الفاتورة غير موجودة');
    if (current.first['status'] != 'completed') {
      throw Exception('لا يمكن تغيير حالة فاتورة غير مكتملة');
    }
    final currentKitchen = current.first['kitchen_status']?.toString() ?? 'done';
    const transitions = {
      'new': {'preparing'},
      'preparing': {'ready'},
      'ready': {'delivered'},
      'delivered': <String>{},
    };
    if (currentKitchen != status && !(transitions[currentKitchen]?.contains(status) ?? false)) {
      throw Exception('لا يمكن الانتقال من "$currentKitchen" إلى "$status"');
    }

    final result = await _db!.transaction<int>((txn) async {
      final updated = await txn.update(
        'invoices',
        {'kitchen_status': status},
        where: 'id = ? AND status = ? AND kitchen_status = ?',
        whereArgs: [invoiceId, 'completed', currentKitchen],
      );
      if (updated > 0) {
        await txn.insert('invoice_audit_log', {
          'invoice_id': invoiceId,
          'action_type': 'kitchen_$status',
          'action_date': DateTime.now().toIso8601String(),
          'user_id': _currentUser?.id,
          'user_name': _currentUser?.name,
          'note': 'تحديث حالة طلب المطبخ إلى $status',
        });
      }
      return updated;
    });
    notifyListeners();
    return result;
  }

  Future<int> getKitchenPendingCount() async {
    final rows = await _db!.rawQuery(
      "SELECT COUNT(*) AS count FROM invoices WHERE status = 'completed' AND kitchen_status IN ('new','preparing','ready')",
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
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

  Future<int> deleteCategory(int id) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.delete('categories', where: 'id = ?', whereArgs: [id]);
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

  Future<int> updateProduct(Product product) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.update('products', {
      'name': product.name,
      'category_id': product.categoryId,
      'price': product.price,
      'cost': product.cost,
      'description': product.description,
      'image_path': product.imagePath,
      'is_available': product.isAvailable ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [product.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteProduct(int id) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.delete('products', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // ==================== PARKED POS ORDERS ====================

  Future<int> savePendingOrder(List<CartItem> items, {String? customerName, double discountAmount = 0, String paymentMethod = 'cash'}) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    if (items.isEmpty) throw Exception('السلة فارغة');
    return _db!.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('pending_orders', {
        'customer_name': customerName?.trim().isEmpty == true ? null : customerName?.trim(),
        'discount_amount': discountAmount,
        'payment_method': paymentMethod,
        'created_at': now,
        'updated_at': now,
      });
      for (final item in items) {
        await txn.insert('pending_order_items', {
          'pending_order_id': id,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    return _db!.rawQuery('''
      SELECT p.id, p.customer_name, p.discount_amount, p.payment_method, p.created_at, p.updated_at,
             COALESCE(SUM(i.quantity), 0) AS item_count,
             COALESCE(SUM(i.total), 0) AS subtotal
      FROM pending_orders p
      LEFT JOIN pending_order_items i ON i.pending_order_id = p.id
      GROUP BY p.id
      ORDER BY p.updated_at DESC
    ''');
  }

  Future<Map<String, dynamic>?> getPendingOrderById(int id) async {
    final orders = await _db!.query('pending_orders', where: 'id = ?', whereArgs: [id]);
    if (orders.isEmpty) return null;
    final items = await _db!.query('pending_order_items', where: 'pending_order_id = ?', whereArgs: [id], orderBy: 'id ASC');
    return {'order': orders.first, 'items': items};
  }

  Future<int> deletePendingOrder(int id) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    final result = await _db!.delete('pending_orders', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }


  // ==================== CUSTOMERS & LOYALTY ====================

  Future<List<Customer>> getCustomers({String query = ''}) async {
    final rows = await _db!.query(
      'customers',
      where: query.trim().isEmpty ? 'is_active = 1' : 'is_active = 1 AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: query.trim().isEmpty ? null : ['%${query.trim()}%', '%${query.trim()}%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final rows = await _db!.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<int> addCustomer({required String name, String? phone, String? email, String? notes}) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    if (name.trim().isEmpty) throw Exception('اسم العميل مطلوب');
    final existing = phone?.trim().isNotEmpty == true
        ? await _db!.query('customers', where: 'phone = ? AND is_active = 1', whereArgs: [phone!.trim()], limit: 1)
        : <Map<String, dynamic>>[];
    if (existing.isNotEmpty) throw Exception('رقم الهاتف مرتبط بعميل آخر');
    final id = await _db!.insert('customers', {
      'name': name.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    return id;
  }

  Future<int> updateCustomer(Customer customer) async {
    if (!isLoggedIn) throw Exception('يجب تسجيل الدخول أولاً');
    if (customer.name.trim().isEmpty) throw Exception('اسم العميل مطلوب');
    final result = await _db!.update('customers', {
      'name': customer.name,
      'phone': customer.phone,
      'email': customer.email,
      'points': customer.points,
      'total_spent': customer.totalSpent,
      'visit_count': customer.visitCount,
      'notes': customer.notes,
      'is_active': customer.isActive ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [customer.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteCustomer(int id) async {
    if (!isManager) throw Exception('حذف العملاء متاح للمدير فقط');
    final result = await _db!.update('customers', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  Future<List<Map<String, dynamic>>> getCustomerPurchases(int customerId) async {
    return _db!.rawQuery('''
      SELECT id, invoice_number, total_amount, payment_method, status, created_at
      FROM invoices
      WHERE customer_id = ? AND status NOT IN ('cancelled','returned')
      ORDER BY created_at DESC
      LIMIT 100
    ''', [customerId]);
  }

  Future<Map<String, dynamic>> getCustomerStats(int customerId) async {
    final rows = await _db!.rawQuery('''
      SELECT COUNT(*) AS visits, COALESCE(SUM(total_amount),0) AS spent
      FROM invoices WHERE customer_id = ? AND status NOT IN ('cancelled','returned')
    ''', [customerId]);
    final row = rows.first;
    return {'visits': (row['visits'] as num?)?.toInt() ?? 0, 'spent': (row['spent'] as num?)?.toDouble() ?? 0};
  }

  Future<int> getCustomerPoints(int customerId) async {
    final customer = await getCustomerById(customerId);
    return customer?.points ?? 0;
  }

  // Invoice CRUD
  Future<int> createInvoice(Invoice invoice, List<CartItem> items) async {
    if (await getCurrentUserOpenShift() == null) throw Exception('يجب فتح وردية قبل تسجيل المبيعات');
    if (items.isEmpty) throw Exception('السلة فارغة');
    // Financial integrity guard: never trust totals supplied by the UI.
    // This keeps invoice records internally consistent even if another caller
    // bypasses the checkout screen.
    const epsilon = 0.01;
    final calculatedSubtotal = items.fold<double>(0.0, (sum, item) {
      if (item.quantity <= 0) {
        throw Exception('كمية المنتج غير صالحة');
      }
      if (item.price < 0) {
        throw Exception('سعر المنتج غير صالح');
      }
      return sum + item.total;
    });

    if ((invoice.subtotalAmount - calculatedSubtotal).abs() > epsilon) {
      throw Exception('إجمالي الفاتورة الفرعي غير متطابق مع عناصر الفاتورة');
    }
    if (invoice.discountAmount < -epsilon ||
        invoice.discountAmount - invoice.subtotalAmount > epsilon) {
      throw Exception('قيمة الخصم غير صالحة');
    }

    final expectedTotal =
        (invoice.subtotalAmount - invoice.discountAmount).clamp(0, double.infinity).toDouble();
    if ((invoice.totalAmount - expectedTotal).abs() > epsilon) {
      throw Exception('إجمالي الفاتورة غير متطابق مع الخصم');
    }
    if (invoice.paidAmount < -epsilon) {
      throw Exception('المبلغ المدفوع غير صالح');
    }

    final paymentMethod = invoice.paymentMethod.trim().toLowerCase();
    if (!{'cash', 'card', 'bank'}.contains(paymentMethod)) {
      throw Exception('طريقة الدفع غير صالحة');
    }

    if (paymentMethod == 'cash') {
      if (invoice.paidAmount + epsilon < invoice.totalAmount) {
        throw Exception('المبلغ المدفوع أقل من إجمالي الفاتورة');
      }
      final expectedChange = invoice.paidAmount - invoice.totalAmount;
      if ((invoice.changeAmount - expectedChange).abs() > epsilon) {
        throw Exception('قيمة الباقي غير متطابقة مع المبلغ المدفوع');
      }
    } else {
      if ((invoice.paidAmount - invoice.totalAmount).abs() > epsilon ||
          invoice.changeAmount.abs() > epsilon) {
        throw Exception('مبلغ الدفع لا يتطابق مع إجمالي الفاتورة');
      }
    }

    final Map<int, double> requiredIngredients = {};
    final Map<int, String> ingredientNames = {};
    for (final item in items) {
      final links = await DatabaseHelper.getProductIngredients(item.productId);
      for (final link in links) {
        final ingredientId = link['ingredient_id'] as int;
        final perUnit = (link['quantity'] as num).toDouble();
        requiredIngredients[ingredientId] = (requiredIngredients[ingredientId] ?? 0) + perUnit * item.quantity;
        ingredientNames[ingredientId] = link['ingredient_name'] as String;
      }
    }
    for (final entry in requiredIngredients.entries) {
      final stock = await DatabaseHelper.getIngredientById(entry.key);
      if (stock.isEmpty) throw Exception('المادة الخام "${ingredientNames[entry.key] ?? 'غير معروفة'}" غير موجودة في المخزون');
      final available = (stock.first['quantity'] as num).toDouble();
      if (available < entry.value) throw Exception('المادة الخام "${ingredientNames[entry.key]}" غير كافية لإتمام الطلب (متوفر: $available، مطلوب: ${entry.value})');
    }
    final costSnapshots = <int, double>{};
    for (final item in items) {
      costSnapshots[item.productId] = await calculateProductCost(item.productId);
    }
    final now = DateTime.now().toIso8601String();
    final invoiceId = await _db!.transaction<int>((txn) async {
      final id = await txn.insert('invoices', {
        'invoice_number': invoice.invoiceNumber,
        'total_amount': invoice.totalAmount,
        'status': invoice.status,
        'payment_method': paymentMethod,
        'customer_id': invoice.customerId,
        'kitchen_status': 'new',
        'subtotal_amount': invoice.subtotalAmount,
        'discount_amount': invoice.discountAmount,
        'paid_amount': invoice.paidAmount,
        'change_amount': invoice.changeAmount,
        'notes': invoice.notes,
        'created_at': now,
      });
      for (final item in items) {
        final productCostAtSale = costSnapshots[item.productId] ?? 0.0;
        final unitProfit = item.price - productCostAtSale;
        await txn.insert('invoice_items', {
          'invoice_id': id, 'product_id': item.productId, 'product_name': item.productName,
          'quantity': item.quantity, 'price': item.price, 'total': item.total,
          'cost_snapshot': productCostAtSale, 'unit_profit': unitProfit,
          'total_profit': unitProfit * item.quantity,
        });
      }
      for (final entry in requiredIngredients.entries) {
        final ingredientId = entry.key; final delta = entry.value;
        final current = await txn.query('inventory', columns: ['quantity', 'cost_price', 'name'], where: 'id = ?', whereArgs: [ingredientId]);
        if (current.isEmpty) throw Exception('تعذر الوصول إلى مادة المخزون');
        final before = (current.first['quantity'] as num).toDouble();
        final cost = (current.first['cost_price'] as num).toDouble();
        final after = before - delta;
        if (after < -0.000001) throw Exception('لا يمكن أن يصبح المخزون سالبًا');
        await txn.update('inventory', {'quantity': after, 'updated_at': now}, where: 'id = ?', whereArgs: [ingredientId]);
        await txn.insert('inventory_audit_log', {
          'action_date': now, 'action_type': 'sale', 'ingredient_id': ingredientId,
          'ingredient_name': current.first['name'], 'quantity_before': before,
          'quantity_change': -delta, 'quantity_after': after, 'cost_price_at_action': cost,
          'reference_type': 'invoice', 'reference_id': id,
        });
      }
      await txn.insert('invoice_audit_log', {
        'invoice_id': id, 'action_type': 'created', 'action_date': now,
        'user_id': _currentUser?.id, 'user_name': _currentUser?.name, 'note': 'تم إنشاء الفاتورة',
      });
      if (invoice.customerId != null) {
        final customerRows = await txn.query('customers', where: 'id = ? AND is_active = 1', whereArgs: [invoice.customerId], limit: 1);
        if (customerRows.isNotEmpty) {
          // One point for every 10 currency units, based on the completed invoice total.
          final earned = (invoice.totalAmount / 10).floor();
          final currentPoints = (customerRows.first['points'] as num?)?.toInt() ?? 0;
          final visits = (customerRows.first['visit_count'] as num?)?.toInt() ?? 0;
          final spent = (customerRows.first['total_spent'] as num?)?.toDouble() ?? 0;
          await txn.update('customers', {
            'points': currentPoints + earned,
            'visit_count': visits + 1,
            'total_spent': spent + invoice.totalAmount,
            'updated_at': now,
          }, where: 'id = ?', whereArgs: [invoice.customerId]);
          if (earned > 0) {
            await txn.insert('customer_points_log', {
              'customer_id': invoice.customerId,
              'invoice_id': id,
              'points_change': earned,
              'reason': 'نقاط من شراء الفاتورة ${invoice.invoiceNumber}',
              'created_at': now,
            });
          }
        }
      }
      return id;
    });
    final lowStockIngredients = await DatabaseHelper.getLowStockIngredients();
    if (lowStockIngredients.isNotEmpty) {
      final names = lowStockIngredients.map((e) => e['name'] as String).toList();
      final warning = 'تحذير: ${names.join('، ')}';
      final notes = invoice.notes?.trim();
      await _db!.update('invoices', {
        'notes': notes == null || notes.isEmpty ? warning : '$notes\n$warning',
      }, where: 'id = ?', whereArgs: [invoiceId]);
    }
    notifyListeners();
    return invoiceId;
  }

  /// Returns the next human-friendly invoice number without relying on row count.
  /// Using MAX(existing suffix) prevents duplicate numbers after invoice deletion.
  Future<String> getNextInvoiceNumber() async {
    final rows = await _db!.rawQuery(
      "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 5) AS INTEGER)), 0) AS max_number FROM invoices WHERE invoice_number GLOB 'INV-[0-9]*'",
    );
    final maxNumber = (rows.first['max_number'] as num?)?.toInt() ?? 0;
    return 'INV-${(maxNumber + 1).toString().padLeft(5, '0')}';
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
      subtotalAmount: invoice.subtotalAmount,
      discountAmount: invoice.discountAmount,
      paidAmount: invoice.paidAmount,
      changeAmount: invoice.changeAmount,
      status: invoice.status,
      paymentMethod: invoice.paymentMethod,
      customerId: invoice.customerId,
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

  /// Fully returns a completed invoice, restoring recipe ingredients exactly once.
  Future<int> returnInvoice(int id) async {
    if (!canVoidInvoice()) throw Exception('استرجاع الفواتير متاح للمدير فقط');
    final result = await _db!.transaction<int>((txn) async {
      final rows = await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return 0;
      final status = rows.first['status']?.toString();
      if (status == 'returned') return 0;
      if (status == 'cancelled') throw Exception('الفاتورة ملغاة بالفعل');
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final productId = item['product_id'] as int;
        final soldQty = (item['quantity'] as num).toDouble();
        final links = await txn.rawQuery(
          'SELECT pi.ingredient_id, pi.quantity, inv.name, inv.quantity AS current_quantity, inv.cost_price '
          'FROM product_ingredients pi INNER JOIN inventory inv ON pi.ingredient_id = inv.id WHERE pi.product_id = ?', [productId]);
        for (final link in links) {
          final ingredientId = link['ingredient_id'] as int;
          final restore = (link['quantity'] as num).toDouble() * soldQty;
          final before = (link['current_quantity'] as num).toDouble();
          final after = before + restore;
          await txn.update('inventory', {'quantity': after, 'updated_at': now}, where: 'id = ?', whereArgs: [ingredientId]);
          await txn.insert('inventory_audit_log', {
            'action_date': now, 'action_type': 'sale_returned', 'ingredient_id': ingredientId,
            'ingredient_name': link['name'], 'quantity_before': before, 'quantity_change': restore,
            'quantity_after': after, 'cost_price_at_action': link['cost_price'], 'reference_type': 'invoice', 'reference_id': id,
          });
        }
      }
      final customerId = rows.first['customer_id'] as int?;
      if (customerId != null) {
        final customerRows = await txn.query('customers', where: 'id = ?', whereArgs: [customerId], limit: 1);
        if (customerRows.isNotEmpty) {
          // Reverse the points actually awarded to this invoice instead of
          // recalculating from the current loyalty rule.
          final pointLogs = await txn.query(
            'customer_points_log',
            columns: ['points_change'],
            where: 'invoice_id = ? AND points_change > 0',
            whereArgs: [id],
          );
          final points = pointLogs.fold<int>(
            0,
            (sum, row) => sum + ((row['points_change'] as num?)?.toInt() ?? 0),
          );
          final currentPoints = (customerRows.first['points'] as num?)?.toInt() ?? 0;
          final visits = (customerRows.first['visit_count'] as num?)?.toInt() ?? 0;
          final spent = (customerRows.first['total_spent'] as num?)?.toDouble() ?? 0;
          await txn.update('customers', {
            'points': (currentPoints - points).clamp(0, 1 << 30),
            'visit_count': (visits - 1).clamp(0, 1 << 30),
            'total_spent': (spent - ((rows.first['total_amount'] as num?)?.toDouble() ?? 0)).clamp(0, double.infinity),
            'updated_at': now,
          }, where: 'id = ?', whereArgs: [customerId]);
          if (points > 0) {
            await txn.insert('customer_points_log', {
              'customer_id': customerId, 'invoice_id': id, 'points_change': -points,
              'reason': 'خصم نقاط العميل بسبب استرجاع الفاتورة', 'created_at': now,
            });
          }
        }
      }
      final existingNotes = rows.first['notes']?.toString().trim();
      await txn.update('invoices', {
        'status': 'returned',
        'kitchen_status': 'done',
        'notes': existingNotes == null || existingNotes.isEmpty
            ? 'تم استرجاع الفاتورة'
            : '$existingNotes\nتم استرجاع الفاتورة',
      }, where: 'id = ?', whereArgs: [id]);
      await txn.insert('invoice_audit_log', {
        'invoice_id': id, 'action_type': 'returned', 'action_date': now,
        'user_id': _currentUser?.id, 'user_name': _currentUser?.name, 'note': 'استرجاع كامل للفاتورة',
      });
      return 1;
    });
    notifyListeners();
    return result;
  }

  /// Cancels an invoice instead of physically deleting it, preserving the audit trail.
  Future<int> voidInvoice(int id) async {
    if (!canVoidInvoice()) throw Exception('إلغاء الفواتير متاح للمدير فقط');
    final result = await _db!.transaction<int>((txn) async {
      final rows = await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty || rows.first['status'] == 'cancelled' || rows.first['status'] == 'returned') return 0;
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final productId = item['product_id'] as int;
        final soldQty = (item['quantity'] as num).toDouble();
        final links = await txn.rawQuery(
          'SELECT pi.ingredient_id, pi.quantity, inv.name, inv.quantity AS current_quantity, inv.cost_price '
          'FROM product_ingredients pi INNER JOIN inventory inv ON pi.ingredient_id = inv.id WHERE pi.product_id = ?', [productId]);
        for (final link in links) {
          final ingredientId = link['ingredient_id'] as int;
          final restore = (link['quantity'] as num).toDouble() * soldQty;
          final before = (link['current_quantity'] as num).toDouble();
          final cost = (link['cost_price'] as num).toDouble();
          final after = before + restore;
          await txn.update('inventory', {'quantity': after, 'updated_at': now}, where: 'id = ?', whereArgs: [ingredientId]);
          await txn.insert('inventory_audit_log', {
            'action_date': now, 'action_type': 'sale_cancelled', 'ingredient_id': ingredientId,
            'ingredient_name': link['name'], 'quantity_before': before, 'quantity_change': restore,
            'quantity_after': after, 'cost_price_at_action': cost, 'reference_type': 'invoice', 'reference_id': id,
          });
        }
      }
      final customerId = rows.first['customer_id'] as int?;
      if (customerId != null) {
        final customerRows = await txn.query('customers', where: 'id = ?', whereArgs: [customerId], limit: 1);
        if (customerRows.isNotEmpty) {
          // Reverse the points actually awarded to this invoice instead of
          // recalculating from the current loyalty rule.
          final pointLogs = await txn.query(
            'customer_points_log',
            columns: ['points_change'],
            where: 'invoice_id = ? AND points_change > 0',
            whereArgs: [id],
          );
          final points = pointLogs.fold<int>(
            0,
            (sum, row) => sum + ((row['points_change'] as num?)?.toInt() ?? 0),
          );
          final currentPoints = (customerRows.first['points'] as num?)?.toInt() ?? 0;
          final visits = (customerRows.first['visit_count'] as num?)?.toInt() ?? 0;
          final spent = (customerRows.first['total_spent'] as num?)?.toDouble() ?? 0;
          await txn.update('customers', {
            'points': (currentPoints - points).clamp(0, 1 << 30),
            'visit_count': (visits - 1).clamp(0, 1 << 30),
            'total_spent': (spent - ((rows.first['total_amount'] as num?)?.toDouble() ?? 0)).clamp(0, double.infinity),
            'updated_at': now,
          }, where: 'id = ?', whereArgs: [customerId]);
          if (points > 0) {
            await txn.insert('customer_points_log', {
              'customer_id': customerId, 'invoice_id': id, 'points_change': -points,
              'reason': 'خصم نقاط العميل بسبب إلغاء الفاتورة', 'created_at': now,
            });
          }
        }
      }
      final existingNotes = rows.first['notes']?.toString().trim();
      final updated = await txn.update('invoices', {
        'status': 'cancelled',
        'kitchen_status': 'done',
        'notes': existingNotes == null || existingNotes.isEmpty
            ? 'تم إلغاء الفاتورة'
            : '$existingNotes\nتم إلغاء الفاتورة',
      }, where: 'id = ? AND status != ?', whereArgs: [id, 'cancelled']);
      if (updated > 0) {
        await txn.insert('invoice_audit_log', {
          'invoice_id': id, 'action_type': 'cancelled', 'action_date': now,
          'user_id': _currentUser?.id, 'user_name': _currentUser?.name,
          'note': 'تم إلغاء الفاتورة وإرجاع المخزون',
        });
      }
      return updated;
    });
    notifyListeners();
    return result;
  }

  Future<int> deleteInvoice(int id) => voidInvoice(id);

  // Expense CRUD
  Future<int> addExpense(Expense expense) async {
    if (!canManageFinance()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.insert('expenses', {
      'name': expense.name,
      'amount': expense.amount,
      'date': expense.date,
      'notes': expense.notes,
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    return result;
  }

  Future<List<Expense>> getExpenses() async {
    if (!canManageFinance()) throw Exception('هذه البيانات متاحة للمدير فقط');
    final results = await _db!.query('expenses', orderBy: 'date DESC');
    return results.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    if (!canManageFinance()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.update('expenses', {
      'name': expense.name,
      'amount': expense.amount,
      'date': expense.date,
      'notes': expense.notes,
    }, where: 'id = ?', whereArgs: [expense.id]);
    notifyListeners();
    return result;
  }

  Future<int> deleteExpense(int id) async {
    if (!canManageFinance()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await _db!.delete('expenses', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // Reports
  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final salesResult = await _db!.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE DATE(created_at) = ? AND status NOT IN ('cancelled','returned')",
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
      "SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE strftime('%Y', created_at) = ? AND strftime('%m', created_at) = ? AND status NOT IN ('cancelled','returned')",
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
      "SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')",
      [startStr, endStr],
    );
    final totalSales = (totalResult.first['total'] is num) ? (totalResult.first['total'] as num).toDouble() : 0.0;
    final invoiceCount = (totalResult.first['count'] is num) ? totalResult.first['count'] as int : 0;

    // Cash
    final cashResult = await _db!.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')",
      ['cash', startStr, endStr],
    );
    final cashTotal = (cashResult.first['total'] is num) ? (cashResult.first['total'] as num).toDouble() : 0.0;

    // Bank
    final bankResult = await _db!.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')",
      ['bank', startStr, endStr],
    );
    final bankTotal = (bankResult.first['total'] is num) ? (bankResult.first['total'] as num).toDouble() : 0.0;

    // Card
    final cardResult = await _db!.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE payment_method = ? AND DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')",
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
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')",
      [startStr, endStr],
    );
    final totalRevenue = (revenueResult.first['total'] is num) ? (revenueResult.first['total'] as num).toDouble() : 0.0;

    // COGS: based on frozen cost_snapshot at time of sale (historical data never changes)
    // Fallback: older invoices (before snapshot existed) fall back to current cost calculation
    final cogsResult = await _db!.rawQuery('''
      SELECT COALESCE(
        SUM(
          CASE WHEN ii.cost_snapshot > 0
            THEN ii.quantity * ii.cost_snapshot
            ELSE ii.quantity * (
              SELECT COALESCE(SUM(pi.quantity * inv.cost_price), 0)
              FROM product_ingredients pi
              INNER JOIN inventory inv ON pi.ingredient_id = inv.id
              WHERE pi.product_id = ii.product_id
            )
          END
        ), 0
      ) as cogs,
      COALESCE(SUM(ii.total_profit), 0) as total_profit
      FROM invoice_items ii
      INNER JOIN invoices inv_t ON ii.invoice_id = inv_t.id
      WHERE DATE(inv_t.created_at) BETWEEN ? AND ? AND inv_t.status NOT IN ('cancelled','returned')
    ''', [startStr, endStr]);
    final cogs = (cogsResult.first['cogs'] is num) ? (cogsResult.first['cogs'] as num).toDouble() : 0.0;
    final grossProfitFromItems = (cogsResult.first['total_profit'] is num) ? (cogsResult.first['total_profit'] as num).toDouble() : 0.0;

    final grossProfit = totalRevenue - cogs;
    final profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    // Total Expenses
    final expenseResult = await _db!.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date BETWEEN ? AND ?',
      [startStr, endStr],
    );
    final totalExpenses = (expenseResult.first['total'] is num) ? (expenseResult.first['total'] as num).toDouble() : 0.0;

    final netProfit = grossProfit - totalExpenses;

    return {
      'totalRevenue': totalRevenue,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'grossProfitFromSnapshot': grossProfitFromItems,
      'profitMargin': profitMargin,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }

  // ==================== DASHBOARD (read-only analytics queries) ====================

  /// Daily sales series, grouped by DATE(created_at).
  Future<List<Map<String, dynamic>>> getDashboardDailySales({required DateTime start, required DateTime end}) async {
    _db ??= await DatabaseHelper.database;
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final result = await _db!.rawQuery(
      'SELECT DATE(created_at) as d, COALESCE(SUM(total_amount),0) as total, COUNT(*) as count '
      "FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned') GROUP BY DATE(created_at) ORDER BY d ASC",
      [startStr, endStr],
    );
    return result;
  }

  /// Top N best-selling products by quantity sold.
  Future<List<Map<String, dynamic>>> getTopProductsByQuantity({required DateTime start, required DateTime end, int limit = 5}) async {
    _db ??= await DatabaseHelper.database;
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    return await _db!.rawQuery(
      'SELECT product_name, SUM(quantity) as qty, COALESCE(SUM(total),0) as total '
      "FROM invoice_items ii INNER JOIN invoices inv ON inv.id = ii.invoice_id WHERE DATE(ii.created_at) BETWEEN ? AND ? AND inv.status NOT IN ('cancelled','returned') "
      'GROUP BY product_id ORDER BY qty DESC LIMIT ?',
      [startStr, endStr, limit],
    );
  }

  /// Top N most profitable products based on saved total_profit (historical).
  Future<List<Map<String, dynamic>>> getTopProductsByProfit({required DateTime start, required DateTime end, int limit = 5}) async {
    _db ??= await DatabaseHelper.database;
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    return await _db!.rawQuery(
      'SELECT product_name, SUM(quantity) as qty, COALESCE(SUM(total_profit),0) as profit '
      "FROM invoice_items ii INNER JOIN invoices inv ON inv.id = ii.invoice_id WHERE DATE(ii.created_at) BETWEEN ? AND ? AND inv.status NOT IN ('cancelled','returned') "
      'GROUP BY product_id ORDER BY profit DESC LIMIT ?',
      [startStr, endStr, limit],
    );
  }

  /// Total expenses in the period, grouped by expense name (reuse Expense.name as category).
  Future<List<Map<String, dynamic>>> getExpenseSummary({required DateTime start, required DateTime end}) async {
    _db ??= await DatabaseHelper.database;
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final result = await _db!.rawQuery(
      'SELECT name, COALESCE(SUM(amount),0) as amount FROM expenses WHERE date BETWEEN ? AND ? '
      'GROUP BY name ORDER BY amount DESC',
      [startStr, endStr],
    );
    return result;
  }

  /// Count of ingredients below their min_quantity (reuse existing logic).
  Future<int> getLowStockCount() async {
    final list = await getLowStockIngredients();
    return list.length;
  }


  // ==================== BUSINESS INTELLIGENCE ====================

  Future<Map<String, dynamic>> getBusinessIntelligence({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!canManageFinance()) throw Exception('هذه البيانات متاحة للمدير فقط');
    _db ??= await DatabaseHelper.database;
    final s = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final e = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    final sales = await _db!.rawQuery('''
      SELECT COALESCE(SUM(total_amount),0) AS sales,
             COALESCE(SUM(subtotal_amount),0) AS subtotal,
             COALESCE(SUM(discount_amount),0) AS discounts,
             COUNT(*) AS invoices,
             COALESCE(SUM(CASE WHEN payment_method='cash' THEN total_amount ELSE 0 END),0) AS cash,
             COALESCE(SUM(CASE WHEN payment_method='card' THEN total_amount ELSE 0 END),0) AS card,
             COALESCE(SUM(CASE WHEN payment_method='bank' THEN total_amount ELSE 0 END),0) AS transfer
      FROM invoices
      WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')
    ''', [s, e]);

    final profit = await _db!.rawQuery('''
      SELECT COALESCE(SUM(ii.total_profit),0) AS gross_profit
      FROM invoice_items ii INNER JOIN invoices i ON i.id = ii.invoice_id
      WHERE DATE(ii.created_at) BETWEEN ? AND ? AND i.status NOT IN ('cancelled','returned')
    ''', [s, e]);

    final expenses = await _db!.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE date BETWEEN ? AND ?',
      [s, e],
    );

    final hourly = await _db!.rawQuery('''
      SELECT CAST(strftime('%H', created_at) AS INTEGER) AS hour,
             COUNT(*) AS orders, COALESCE(SUM(total_amount),0) AS sales
      FROM invoices
      WHERE DATE(created_at) BETWEEN ? AND ? AND status NOT IN ('cancelled','returned')
      GROUP BY CAST(strftime('%H', created_at) AS INTEGER)
      ORDER BY sales DESC
    ''', [s, e]);

    final payment = [
      {'name': 'نقدًا', 'amount': (sales.first['cash'] as num?)?.toDouble() ?? 0},
      {'name': 'بطاقة', 'amount': (sales.first['card'] as num?)?.toDouble() ?? 0},
      {'name': 'تحويل', 'amount': (sales.first['transfer'] as num?)?.toDouble() ?? 0},
    ];

    final customers = await _db!.rawQuery('''
      SELECT c.name, c.phone, COUNT(i.id) AS visits,
             COALESCE(SUM(i.total_amount),0) AS spent
      FROM customers c INNER JOIN invoices i ON i.customer_id = c.id
      WHERE DATE(i.created_at) BETWEEN ? AND ? AND i.status NOT IN ('cancelled','returned')
      GROUP BY c.id ORDER BY spent DESC LIMIT 8
    ''', [s, e]);

    final lowStock = await _db!.rawQuery('''
      SELECT id, name, quantity, unit, min_quantity, cost_price
      FROM inventory WHERE quantity <= min_quantity
      ORDER BY (min_quantity - quantity) DESC, name ASC LIMIT 12
    ''');

    final salesValue = (sales.first['sales'] as num?)?.toDouble() ?? 0;
    final grossProfit = (profit.first['gross_profit'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (expenses.first['total'] as num?)?.toDouble() ?? 0;
    final invoiceCount = (sales.first['invoices'] as num?)?.toInt() ?? 0;

    return {
      'sales': salesValue,
      'subtotal': (sales.first['subtotal'] as num?)?.toDouble() ?? 0,
      'discounts': (sales.first['discounts'] as num?)?.toDouble() ?? 0,
      'invoices': invoiceCount,
      'averageTicket': invoiceCount == 0 ? 0.0 : salesValue / invoiceCount,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'netProfit': grossProfit - totalExpenses,
      'margin': salesValue == 0 ? 0.0 : (grossProfit / salesValue) * 100,
      'payment': payment,
      'hourly': hourly,
      'customers': customers,
      'lowStock': lowStock,
    };
  }

  // Navigation
  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // ==================== INVENTORY CRUD ====================

  Future<int> addIngredient(IngredientModel ingredient) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.insertIngredient(ingredient.toMap());
    // Audit trail: log the new ingredient creation
    await DatabaseHelper.logInventoryAudit(
      actionType: 'added',
      ingredientId: result,
      ingredientName: ingredient.name,
      quantityBefore: 0,
      quantityChange: ingredient.quantity,
      quantityAfter: ingredient.quantity,
      costPriceAtAction: ingredient.costPrice,
      referenceType: 'ingredient',
      referenceId: result,
    );
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
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    // Audit trail: log quantity and/or price changes before applying them
    final old = await DatabaseHelper.getIngredientById(ingredient.id!);
    if (old.isNotEmpty) {
      final oldQty = (old.first['quantity'] as num).toDouble();
      final oldCost = (old.first['cost_price'] as num).toDouble();
      final newQty = ingredient.quantity;
      final newCost = ingredient.costPrice;
      final qtyDelta = newQty - oldQty;
      if (qtyDelta != 0 || newCost != oldCost) {
        await DatabaseHelper.logInventoryAudit(
          actionType: qtyDelta != 0 ? 'manual_adjust' : 'price_changed',
          ingredientId: ingredient.id!,
          ingredientName: ingredient.name,
          quantityBefore: oldQty,
          quantityChange: qtyDelta,
          quantityAfter: newQty,
          costPriceAtAction: newCost,
          referenceType: 'ingredient',
          referenceId: ingredient.id,
        );
      }
    }
    final result = await DatabaseHelper.updateIngredient(ingredient.id!, {
      'name': ingredient.name,
      'quantity': ingredient.quantity,
      'unit': ingredient.unit,
      'min_quantity': ingredient.minQuantity,
      'cost_price': ingredient.costPrice,
      'updated_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    // Auto recalculate costs of products affected by this ingredient's price change
    await updateAffectedProductsCost(ingredient.id!);
    return result;
  }

  Future<int> deleteIngredient(int id) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteIngredient(id);
    notifyListeners();
    return result;
  }

  Future<void> recordPurchase(int ingredientId, double quantity, double cost) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final ingredient = await DatabaseHelper.getIngredientById(ingredientId);
    if (ingredient.isNotEmpty) {
      final oldQty = (ingredient.first['quantity'] as num).toDouble();
      final oldCost = (ingredient.first['cost_price'] as num).toDouble();
      
      double newCost = oldCost;
      if (cost > 0) {
        newCost = (oldQty * oldCost + quantity * cost) / (oldQty + quantity);
      }
      
      final ingredientName = ingredient.first['name'] as String?;
      await DatabaseHelper.updateIngredient(ingredientId, {
        'quantity': oldQty + quantity,
        'cost_price': newCost,
      });
      // Audit trail: log the purchase movement (increase in stock)
      await DatabaseHelper.logInventoryAudit(
        actionType: 'purchase',
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        quantityBefore: oldQty,
        quantityChange: quantity,
        quantityAfter: oldQty + quantity,
        costPriceAtAction: newCost,
        referenceType: 'purchase',
        referenceId: null,
      );
      notifyListeners();
      // Auto recalculate costs of products affected by this ingredient's price change
      await updateAffectedProductsCost(ingredientId);
    }
  }

  // ==================== SUPPLIERS CRUD ====================

  Future<int> addSupplier(Supplier supplier) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.insertSupplier({
      'name': supplier.name,
      'phone': supplier.phone,
      'address': supplier.address,
      'notes': supplier.notes,
      'balance': supplier.balance,
      'created_at': supplier.createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': supplier.updatedAt ?? DateTime.now().toIso8601String(),
    });
    notifyListeners();
    return result;
  }

  Future<List<Supplier>> getSuppliers() async {
    final results = await DatabaseHelper.getSuppliers();
    return results.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final result = await DatabaseHelper.getSupplierById(id);
    return result != null ? Supplier.fromMap(result) : null;
  }

  Future<int> updateSupplier(Supplier supplier) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.updateSupplier(supplier.id!, {
      'name': supplier.name,
      'phone': supplier.phone,
      'address': supplier.address,
      'notes': supplier.notes,
      'balance': supplier.balance,
      'updated_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    return result;
  }

  Future<int> deleteSupplier(int id) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteSupplier(id);
    notifyListeners();
    return result;
  }

  // ==================== PURCHASES ====================

  Future<int> createPurchaseInvoice(PurchaseInvoice invoice, List<PurchaseItem> items) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.insertPurchaseInvoice(
      invoice.toMap(),
      items.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
    // Auto recalculate costs of products affected by purchased ingredients' new cost_price
    final uniqueIngredients = items.map((e) => e.ingredientId).toSet();
    for (final ingredientId in uniqueIngredients) {
      await updateAffectedProductsCost(ingredientId);
    }
    return result;
  }

  Future<List<PurchaseInvoice>> getPurchaseInvoices({int? supplierId}) async {
    final results = await DatabaseHelper.getPurchaseInvoices(supplierId: supplierId);
    return results.map((e) => PurchaseInvoice.fromMap(e)).toList();
  }

  Future<List<PurchaseItem>> getPurchaseItems(int invoiceId) async {
    final results = await DatabaseHelper.getPurchaseItems(invoiceId);
    return results.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  // ==================== PAYMENTS & LEDGER ====================

  Future<int> addSupplierPayment(SupplierPayment payment) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.insertSupplierPayment(payment.toMap());
    notifyListeners();
    return result;
  }

  Future<List<Map<String, dynamic>>> getSupplierLedger(int supplierId) async {
    return await DatabaseHelper.getSupplierLedger(supplierId);
  }

  /// Centralized recalculation: update cost of products affected by an ingredient price change only
  Future<void> updateAffectedProductsCost(int ingredientId) async {
    final affectedProductIds = await DatabaseHelper.getProductIdsByIngredient(ingredientId);
    for (final productId in affectedProductIds) {
      await updateProductCostFromRecipe(productId, notify: false);
    }
    // Callers notify once after the complete recalculation batch finishes.
  }

  // ==================== RECIPE MANAGEMENT ====================

  Future<double> calculateProductCost(int productId) async {
    final ingredients = await DatabaseHelper.getProductIngredients(productId);
    return ingredients.fold<double>(
      0,
      (total, item) => total +
          (item['quantity'] as num).toDouble() *
          ((item['cost_price'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<void> updateProductCostFromRecipe(int productId, {bool notify = true}) async {
    final newCost = await calculateProductCost(productId);
    await _db!.rawUpdate(
      'UPDATE products SET cost = ?, updated_at = ? WHERE id = ?',
      [newCost, DateTime.now().toIso8601String(), productId],
    );
    if (notify) notifyListeners();
  }

  Future<int> addProductIngredient(ProductIngredient link) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    if (link.quantity <= 0) {
      throw ArgumentError('كمية الوصفة يجب أن تكون أكبر من صفر');
    }
    final result = await DatabaseHelper.insertProductIngredient(link.toMap());
    await updateProductCostFromRecipe(link.productId);
    return result;
  }

  Future<List<Map<String, dynamic>>> getProductIngredients(int productId) async {
    return await DatabaseHelper.getProductIngredients(productId);
  }

  Future<int> deleteProductIngredient(int productId, int ingredientId) async {
    if (!canManageCatalog()) throw Exception('هذه العملية متاحة للمدير فقط');
    final result = await DatabaseHelper.deleteProductIngredient(productId, ingredientId);
    await updateProductCostFromRecipe(productId);
    return result;
  }
}
