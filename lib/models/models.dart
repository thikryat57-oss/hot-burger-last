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

class Invoice {
  final int? id;
  final String invoiceNumber;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final String? notes;
  final String? createdAt;
  final List<InvoiceItem>? items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    this.status = 'completed',
    this.paymentMethod = 'cash',
    this.notes,
    this.createdAt,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'status': status,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      totalAmount: map['total_amount']?.toDouble() ?? 0,
      status: map['status'],
      paymentMethod: map['payment_method'] ?? 'cash',
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

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: map['quantity'],
      price: map['price']?.toDouble() ?? 0,
      total: map['total']?.toDouble() ?? 0,
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

// Cart item for sales
class CartItem {
  final int productId;
  final String productName;
  final double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}
// Inventory / Ingredient model for raw materials
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

// Product-Ingredient relation model (recipe link)
class ProductIngredient {
  final int? id;
  final int productId;
  final int ingredientId;
  final double quantity; // الكمية المستهلكة من المادة الخام لكل منتج

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
