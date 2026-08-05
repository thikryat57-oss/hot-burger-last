import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';
import '../../models/models.dart';
import '../reports/shift_report_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Product> _products = [];
  List<CartItem> _cart = [];
  String _searchQuery = '';
  int? _selectedCategoryId;
  String _selectedPaymentMethod = 'cash';

  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    _categoriesFuture = appProvider.getCategories();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final appProvider = context.read<AppProvider>();
    final products = await appProvider.getProducts();
    if (mounted) {
      setState(() {
        _products = products.where((p) => p.isAvailable).toList();
      });
    }
  }

  List<Product> get _filteredProducts {
    var filtered = _products;
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((c) => c.productId == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(CartItem(
          productId: product.id!,
          productName: product.name,
          price: product.price,
          quantity: 1,
        ));
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      _cart.removeWhere((c) => c.productId == productId);
    });
  }

  void _updateQuantity(int productId, int quantity) {
    setState(() {
      final index = _cart.indexWhere((c) => c.productId == productId);
      if (index >= 0) {
        if (quantity <= 0) {
          _cart.removeAt(index);
        } else {
          _cart[index].quantity = quantity;
        }
      }
    });
  }

  double get _totalAmount {
    return _cart.fold(0.0, (sum, item) => sum + item.total);
  }

  Future<void> _saveInvoice() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة')),
      );
      return;
    }

    final appProvider = context.read<AppProvider>();
    final invoices = await appProvider.getInvoices();
    final invoiceNumber = 'INV-${(invoices.length + 1).toString().padLeft(5, '0')}';

    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      totalAmount: _totalAmount,
      status: 'completed',
      paymentMethod: _selectedPaymentMethod,
    );

    try {
      final invoiceId = await appProvider.createInvoice(invoice, _cart);

      if (mounted) {
        // Check for low stock warning
        final savedInvoice = await appProvider.getInvoiceById(invoiceId);
        if (savedInvoice?.notes != null && savedInvoice!.notes!.startsWith('تحذير:')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${savedInvoice.notes}\nتم حفظ الفاتورة بنجاح',
              ),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'طباعة',
                textColor: Colors.white,
                onPressed: () {
                  PdfHelper.showPrintOptions(context, savedInvoice);
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم حفظ الفاتورة بنجاح'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'طباعة',
                textColor: Colors.white,
                onPressed: () {
                  if (savedInvoice != null) {
                    PdfHelper.showPrintOptions(context, savedInvoice);
                  }
                },
              ),
            ),
          );
        }
        setState(() {
          _cart.clear();
          _selectedPaymentMethod = 'cash';
        });
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('خطأ في إتمام البيع'),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: TextStyle(color: AppTheme.errorColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftReportScreen()),
              );
            },
            tooltip: 'تقرير تقفيل الوردية',
          ),
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              label: const Text('مسح', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث عن منتج...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category filter chips
          FutureBuilder<List<Category>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('الكل'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                      backgroundColor: AppTheme.backgroundColor,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((c) => FilterChip(
                      label: Text(c.name),
                      selected: _selectedCategoryId == c.id,
                      onSelected: (_) => setState(() => _selectedCategoryId = c.id),
                      backgroundColor: AppTheme.backgroundColor,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == c.id ? Colors.white : AppTheme.textPrimary,
                      ),
                    )),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Products grid + cart split view
          Expanded(
            child: Row(
              children: [
                // Products grid
                Expanded(
                  flex: 3,
                  child: _filteredProducts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fastfood, size: 60, color: AppTheme.textHint),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد منتجات',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 130,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return GestureDetector(
                              onTap: () => _addToCart(product),
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.fastfood, color: AppTheme.primaryColor, size: 28),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${product.price.toStringAsFixed(2)} ج.س',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const VerticalDivider(width: 1),

                // Cart
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_cart, size: 20, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'السلة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Spacer(),
                            Text(
                              '${_cart.length} عنصر',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _cart.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_basket_outlined, size: 50, color: AppTheme.textHint),
                                    SizedBox(height: 8),
                                    Text(
                                      'السلة فارغة',
                                      style: TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _cart.length,
                                itemBuilder: (context, index) {
                                  final item = _cart[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                Text(
                                                  '${item.price.toStringAsFixed(2)} ج.س',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 22),
                                                onPressed: () => _updateQuantity(item.productId, item.quantity - 1),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, size: 22),
                                                onPressed: () => _updateQuantity(item.productId, item.quantity + 1),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${item.total.toStringAsFixed(2)} ج.س',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18, color: AppTheme.errorColor),
                                                onPressed: () => _removeFromCart(item.productId),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Total and actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: const Text(
                                      'الإجمالي:',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${_totalAmount.toStringAsFixed(2)} ج.س',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Payment method selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      Icons.money,
                                      size: 16,
                                      color: _selectedPaymentMethod == 'cash' ? Colors.white : AppTheme.primaryColor,
                                    ),
                                    label: const Text('نقداً'),
                                    selected: _selectedPaymentMethod == 'cash',
                                    selectedColor: AppTheme.primaryColor,
                                    labelStyle: TextStyle(
                                      color: _selectedPaymentMethod == 'cash' ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) setState(() => _selectedPaymentMethod = 'cash');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      Icons.account_balance,
                                      size: 16,
                                      color: _selectedPaymentMethod == 'bank' ? Colors.white : AppTheme.primaryColor,
                                    ),
                                    label: const Text('تحويل بنكي'),
                                    selected: _selectedPaymentMethod == 'bank',
                                    selectedColor: AppTheme.primaryColor,
                                    labelStyle: TextStyle(
                                      color: _selectedPaymentMethod == 'bank' ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) setState(() => _selectedPaymentMethod = 'bank');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton(
                                      onPressed: _cart.isEmpty ? null : _clearCart,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.errorColor,
                                        side: const BorderSide(color: AppTheme.errorColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('إلغاء'),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: ElevatedButton(
                                      onPressed: _cart.isEmpty ? null : _saveInvoice,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('حفظ الفاتورة'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
