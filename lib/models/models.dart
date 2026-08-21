class User {
  final int? id;
  final String name;
  final String password;
  final String role;
  final String? createdAt;

  User({
    this.id,
    required this.name,
    required this.password,
    this.role = 'manager',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'role': role,
      'created_at': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      password: map['password'],
      role: map['role'],
      createdAt: map['created_at'],
    );
  }
}

class Category {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Category({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class Product {
  final int? id;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final double price;
  final double cost;
  final String? description;
  final String? imagePath;
  final bool isAvailable;
  final String? createdAt;
  final String? updatedAt;

  Product({
    this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.price,
    this.cost = 0,
    this.description,
    this.imagePath,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'price': price,
      'cost': cost,
      'description': description,
      'image_path': imagePath,
      'is_available': isAvailable ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      categoryId: map['category_id'],
      categoryName: map['category_name'],
      price: map['price']?.toDouble() ?? 0,
      cost: map['cost']?.toDouble() ?? 0,
      description: map['description'],
      imagePath: map['image_path'],
      isAvailable: map['is_available'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class RawMaterial {
  final int? id;
  final String name;
  final String? unit;
  final double quantity;
  final double cost;
  final String? supplier;
  final String? notes;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  RawMaterial({
    this.id,
    required this.name,
    this.unit,
    this.quantity = 0,
    this.cost = 0,
    this.supplier,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'cost': cost,
      'supplier': supplier,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      id: map['id'],
      name: map['name'],
      unit: map['unit'],
      quantity: map['quantity']?.toDouble() ?? 0,
      cost: map['cost']?.toDouble() ?? 0,
      supplier: map['supplier'],
      notes: map['notes'],
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final int points;
  final double totalSpent;
  final int visitCount;
  final String? notes;
  final bool isActive;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.points = 0,
    this.totalSpent = 0,
    this.visitCount = 0,
    this.notes,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'points': points, 'total_spent': totalSpent, 'visit_count': visitCount,
    'notes': notes, 'is_active': isActive ? 1 : 0,
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'],
    name: map['name']?.toString() ?? '',
    phone: map['phone']?.toString(),
    email: map['email']?.toString(),
    points: (map['points'] as num?)?.toInt() ?? 0,
    totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
    visitCount: (map['visit_count'] as num?)?.toInt() ?? 0,
    notes: map['notes']?.toString(),
    isActive: map['is_active'] == 1,
  );
}

class Invoice {
  final int? id;
  final String invoiceNumber;
  final double totalAmount;
  final double subtotalAmount;
  final double discountAmount;
  final double paidAmount;
  final double changeAmount;
  final String status;
  final String paymentMethod;
  final int? customerId;
  final String? notes;
  final String? createdAt;
  final List<InvoiceItem>? items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    this.subtotalAmount = 0,
    this.discountAmount = 0,
    this.paidAmount = 0,
    this.changeAmount = 0,
    this.status = 'completed',
    this.paymentMethod = 'cash',
    this.customerId,
    this.notes,
    this.createdAt,
    this.items,
  });

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    double? totalAmount,
    double? subtotalAmount,
    double? discountAmount,
    double? paidAmount,
    double? changeAmount,
    String? status,
    String? paymentMethod,
    int? customerId,
    String? notes,
    String? createdAt,
    List<InvoiceItem>? items,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'subtotal_amount': subtotalAmount,
      'discount_amount': discountAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'status': status,
      'payment_method': paymentMethod,
      'customer_id': customerId,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      totalAmount: map['total_amount']?.toDouble() ?? 0,
      subtotalAmount: map['subtotal_amount']?.toDouble() ?? (map['total_amount']?.toDouble() ?? 0),
      discountAmount: map['discount_amount']?.toDouble() ?? 0,
      paidAmount: map['paid_amount']?.toDouble() ?? (map['total_amount']?.toDouble() ?? 0),
      changeAmount: map['change_amount']?.toDouble() ?? 0,
      status: map['status'],
      paymentMethod: map['payment_method'] ?? 'cash',
      customerId: map['customer_id'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final double cost;
  final double costSnapshot;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    required this.cost,
    this.costSnapshot = 0,
  });

  double get unitProfit => price - costSnapshot;
  double get totalProfit => total - (costSnapshot * quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
      'cost': cost,
      'cost_snapshot': costSnapshot,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: (map['quantity'] as num).toInt(),
      price: map['price']?.toDouble() ?? 0,
      total: map['total']?.toDouble() ?? 0,
      cost: map['cost']?.toDouble() ?? 0,
      costSnapshot: map['cost_snapshot']?.toDouble() ?? map['cost']?.toDouble() ?? 0,
    );
  }
}

class Expense {
  final int? id;
  final String name;
  final double amount;
  final String date;
  final String? notes;
  final String? createdAt;

  Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      name: map['name'],
      amount: map['amount']?.toDouble() ?? 0,
      date: map['date'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

class CartItem {
  final int productId;
  final String productName;
  final double price;
  final double cost;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.cost = 0,
    this.quantity = 1,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'total': total,
    };
  }
}

class IngredientModel {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final double minQuantity;
  final double costPrice;
  final String? createdAt;
  final String? updatedAt;

  IngredientModel({
    this.id,
    required this.name,
    this.quantity = 0,
    this.unit = 'حبة',
    this.minQuantity = 0,
    this.costPrice = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'min_quantity': minQuantity,
      'cost_price': costPrice,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory IngredientModel.fromMap(Map<String, dynamic> map) {
    return IngredientModel(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity']?.toDouble() ?? 0,
      unit: map['unit'] ?? 'حبة',
      minQuantity: map['min_quantity']?.toDouble() ?? 0,
      costPrice: map['cost_price']?.toDouble() ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  bool get isLowStock => quantity <= minQuantity;
}

class ProductIngredient {
  final int? id;
  final int productId;
  final int ingredientId;
  final double quantity;

  ProductIngredient({
    this.id,
    required this.productId,
    required this.ingredientId,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
    };
  }

  factory ProductIngredient.fromMap(Map<String, dynamic> map) {
    return ProductIngredient(
      id: map['id'],
      productId: map['product_id'],
      ingredientId: map['ingredient_id'],
      quantity: map['quantity']?.toDouble() ?? 0,
    );
  }
}

class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final double balance;
  final bool isActive;
  final String? taxNumber;
  final String? createdAt;
  final String? updatedAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.balance = 0,
    this.isActive = true,
    this.taxNumber,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'balance': balance,
      'is_active': isActive ? 1 : 0,
      'tax_number': taxNumber,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      notes: map['notes'],
      balance: map['balance']?.toDouble() ?? 0,
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
      taxNumber: map['tax_number'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class PurchaseInvoice {
  final int? id;
  final int supplierId;
  final String? supplierName;
  final String invoiceNumber;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String? notes;
  final String date;
  final String? createdAt;
  final List<PurchaseItem>? items;

  PurchaseInvoice({
    this.id,
    required this.supplierId,
    this.supplierName,
    required this.invoiceNumber,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.status,
    this.notes,
    required this.date,
    this.createdAt,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status,
      'notes': notes,
      'date': date,
      'created_at': createdAt,
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'],
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
      invoiceNumber: map['invoice_number'],
      totalAmount: map['total_amount']?.toDouble() ?? 0,
      paidAmount: map['paid_amount']?.toDouble() ?? 0,
      status: map['status'],
      notes: map['notes'],
      date: map['date'],
      createdAt: map['created_at'],
    );
  }
}

class PurchaseItem {
  final int? id;
  final int? purchaseInvoiceId;
  final int? materialId;
  final int? ingredientId;
  final String? materialName;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final String? unit;

  PurchaseItem({
    this.id,
    this.purchaseInvoiceId,
    this.materialId,
    this.ingredientId,
    this.materialName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_invoice_id': purchaseInvoiceId,
      'material_id': materialId,
      'ingredient_id': ingredientId ?? materialId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'unit': unit,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseInvoiceId: map['purchase_invoice_id'],
      materialId: map['material_id'],
      ingredientId: map['ingredient_id'],
      materialName: map['material_name'] ?? map['ingredient_name'],
      quantity: map['quantity']?.toDouble() ?? 0,
      unitCost: map['unit_cost']?.toDouble() ?? 0,
      totalCost: map['total_cost']?.toDouble() ?? 0,
      unit: map['unit'],
    );
  }
}

class SupplierPayment {
  final int? id;
  final int supplierId;
  final int? purchaseInvoiceId;
  final double amount;
  final String date;
  final String? notes;
  final String? createdAt;

  SupplierPayment({
    this.id,
    required this.supplierId,
    this.purchaseInvoiceId,
    required this.amount,
    required this.date,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'purchase_invoice_id': purchaseInvoiceId,
      'amount': amount,
      'date': date,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'],
      supplierId: map['supplier_id'],
      purchaseInvoiceId: map['purchase_invoice_id'],
      amount: map['amount']?.toDouble() ?? 0,
      date: map['date'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

class Shift {
  final int? id;
  final int userId;
  final String userName;
  final String openedAt;
  final String? closedAt;

  final String status;
  final String? notes;

  Shift({
    this.id,
    required this.userId,
    required this.userName,
    required this.openedAt,
    this.closedAt,
    this.openingBalance = 0,
    this.closingBalance,
    this.status = 'open',
    this.notes,
  });

  final double openingBalance;
  final double? closingBalance;

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
    id: map['id'],
    userId: map['user_id'],
    userName: map['user_name'] ?? '',
    openedAt: map['opened_at'],
    closedAt: map['closed_at'],
    openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
    closingBalance: (map['closing_balance'] as num?)?.toDouble(),
    status: map['status'] ?? 'open',
    notes: map['notes'],
  );
}

class MaterialModel {
  final int? id;
  final String name;
  final String type;
  final String unit;
  final double quantity;
  final double minQuantity;
  final double costPrice;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final String? category;

  MaterialModel({
    this.id,
    required this.name,
    required this.type,
    required this.unit,
    this.quantity = 0,
    this.minQuantity = 0,
    this.costPrice = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.category,
  });

  MaterialModel copyWith({
    int? id,
    String? name,
    String? type,
    String? unit,
    double? quantity,
    double? minQuantity,
    double? costPrice,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? category,
  }) {
    return MaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      costPrice: costPrice ?? this.costPrice,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'unit': unit,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'cost_price': costPrice,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'category': category,
    };
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      unit: map['unit'],
      quantity: map['quantity']?.toDouble() ?? 0,
      minQuantity: map['min_quantity']?.toDouble() ?? 0,
      costPrice: map['cost_price']?.toDouble() ?? 0,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      category: map['category'],
    );
  }

  bool get isPrepared => type == 'prepared';
}

class RecipeModel {
  final int? id;
  final String parentType;
  final int parentId;
  final int materialId;
  final double quantity;
  final String unit;
  final String? createdAt;
  final String? materialName;
  final double? materialCost;

  RecipeModel({
    this.id,
    required this.parentType,
    required this.parentId,
    required this.materialId,
    required this.quantity,
    required this.unit,
    this.createdAt,
    this.materialName,
    this.materialCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_type': parentType,
      'parent_id': parentId,
      'material_id': materialId,
      'quantity': quantity,
      'unit': unit,
      'created_at': createdAt,
    };
  }

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
      id: map['id'],
      parentType: map['parent_type'],
      parentId: map['parent_id'],
      materialId: map['material_id'],
      quantity: map['quantity']?.toDouble() ?? 0,
      unit: map['unit'],
      createdAt: map['created_at'],
      materialName: map['material_name'],
      materialCost: map['material_cost']?.toDouble(),
    );
  }
}

class ProductionBatch {
  final int? id;
  final int materialId;
  final double quantity;
  final double costPerUnit;
  final double totalCost;
  final String? productionDate;
  final String? notes;
  final int? userId;

  ProductionBatch({
    this.id,
    required this.materialId,
    required this.quantity,
    required this.costPerUnit,
    required this.totalCost,
    this.productionDate,
    this.notes,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'quantity': quantity,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'production_date': productionDate,
      'notes': notes,
      'user_id': userId,
    };
  }

  factory ProductionBatch.fromMap(Map<String, dynamic> map) {
    return ProductionBatch(
      id: map['id'],
      materialId: map['material_id'],
      quantity: map['quantity']?.toDouble() ?? 0,
      costPerUnit: map['cost_per_unit']?.toDouble() ?? 0,
      totalCost: map['total_cost']?.toDouble() ?? 0,
      productionDate: map['production_date'],
      notes: map['notes'],
      userId: map['user_id'],
    );
  }
}

class StocktakeSession {
  final int? id;
  final String startDate;
  final String? endDate;
  final String status;
  final String? notes;
  final int? userId;
  final String? userName;

  StocktakeSession({
    this.id,
    required this.startDate,
    this.endDate,
    required this.status,
    this.notes,
    this.userId,
    this.userName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'notes': notes,
      'user_id': userId,
      'user_name': userName,
    };
  }

  factory StocktakeSession.fromMap(Map<String, dynamic> map) {
    return StocktakeSession(
      id: map['id'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      status: map['status'],
      notes: map['notes'],
      userId: map['user_id'],
      userName: map['user_name'],
    );
  }
}

class StocktakeItem {
  final int? id;
  final int sessionId;
  final int materialId;
  final String materialName;
  final double theoreticalQty;
  final double countedQty;
  final double variance;
  final double unitCostAtCount;
  final String? notes;

  StocktakeItem({
    this.id,
    required this.sessionId,
    required this.materialId,
    required this.materialName,
    required this.theoreticalQty,
    required this.countedQty,
    required this.variance,
    required this.unitCostAtCount,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'material_id': materialId,
      'theoretical_qty': theoreticalQty,
      'counted_qty': countedQty,
      'variance': variance,
      'unit_cost_at_count': unitCostAtCount,
      'notes': notes,
    };
  }

  factory StocktakeItem.fromMap(Map<String, dynamic> map) {
    return StocktakeItem(
      id: map['id'],
      sessionId: map['session_id'],
      materialId: map['material_id'],
      materialName: map['material_name'] ?? '',
      theoreticalQty: (map['theoretical_qty'] as num).toDouble(),
      countedQty: (map['counted_qty'] as num).toDouble(),
      variance: (map['variance'] as num).toDouble(),
      unitCostAtCount: (map['unit_cost_at_count'] as num).toDouble(),
      notes: map['notes'],
    );
  }
}

class InventoryAdjustment {
  final int? id;
  final int materialId;
  final String materialName;
  final double quantityChange;
  final String actionType;
  final double costPriceAtAction;
  final String date;
  final String? notes;
  final int? userId;
  final String? userName;

  InventoryAdjustment({
    this.id,
    required this.materialId,
    required this.materialName,
    required this.quantityChange,
    required this.actionType,
    required this.costPriceAtAction,
    required this.date,
    this.notes,
    this.userId,
    this.userName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'quantity_change': quantityChange,
      'action_type': actionType,
      'cost_price_at_action': costPriceAtAction,
      'date': date,
      'notes': notes,
      'user_id': userId,
      'user_name': userName,
    };
  }

  factory InventoryAdjustment.fromMap(Map<String, dynamic> map) {
    return InventoryAdjustment(
      id: map['id'],
      materialId: map['material_id'],
      materialName: map['material_name'] ?? '',
      quantityChange: (map['quantity_change'] as num).toDouble(),
      actionType: map['action_type'],
      costPriceAtAction: (map['cost_price_at_action'] as num).toDouble(),
      date: map['date'],
      notes: map['notes'],
      userId: map['user_id'],
      userName: map['user_name'],
    );
  }
}
