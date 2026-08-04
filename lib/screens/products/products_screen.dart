import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'recipe_management_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final appProvider = context.read<AppProvider>();
    final products = await appProvider.getProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final appProvider = context.read<AppProvider>();
    int? _selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<List<Category>>(
            future: appProvider.getCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return AlertDialog(
                title: const Text('إضافة منتج جديد'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(hintText: 'اسم المنتج'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        decoration: const InputDecoration(hintText: 'السعر'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: costController,
                        decoration: const InputDecoration(hintText: 'التكلفة'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(hintText: 'التصنيف'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                          ...categories.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty || priceController.text.isEmpty) {
                        return;
                      }
                      await appProvider.addProduct(Product(
                        name: nameController.text,
                        price: double.tryParse(priceController.text) ?? 0,
                        cost: double.tryParse(costController.text) ?? 0,
                        categoryId: _selectedCategoryId,
                      ));
                      if (mounted) {
                        Navigator.pop(context);
                        _loadProducts();
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toString());
    final costController = TextEditingController(text: product.cost.toString());
    final appProvider = context.read<AppProvider>();
    int? _editCategoryId = product.categoryId;
    bool _editIsAvailable = product.isAvailable;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<List<Category>>(
            future: appProvider.getCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return AlertDialog(
                title: const Text('تعديل المنتج'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(hintText: 'اسم المنتج'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        decoration: const InputDecoration(hintText: 'السعر'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: costController,
                        decoration: const InputDecoration(hintText: 'التكلفة'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: _editCategoryId,
                        decoration: const InputDecoration(hintText: 'التصنيف'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                          ...categories.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _editCategoryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('متاح للبيع'),
                        value: _editIsAvailable,
                        onChanged: (value) {
                          setDialogState(() {
                            _editIsAvailable = value;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await appProvider.updateProduct(Product(
                        id: product.id,
                        name: nameController.text,
                        price: double.tryParse(priceController.text) ?? 0,
                        cost: double.tryParse(costController.text) ?? 0,
                        categoryId: _editCategoryId,
                        isAvailable: _editIsAvailable,
                      ));
                      if (mounted) {
                        Navigator.pop(context);
                        _loadProducts();
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final appProvider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل أنت متأكد من حذف "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await appProvider.deleteProduct(product.id!);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fastfood, size: 80, color: AppTheme.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد منتجات',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أضف منتجات جديدة للبدء',
                        style: TextStyle(
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.fastfood, color: AppTheme.primaryColor),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.categoryName != null
                                ? 'التصنيف: ${product.categoryName}'
                                : 'بدون تصنيف'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'التكلفة: ${product.cost.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'الربح: ${(product.price - product.cost).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (product.price - product.cost) >= 0
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restaurant_menu, color: AppTheme.accentColor, size: 22),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecipeManagementScreen(product: product),
                                  ),
                                );
                                _loadProducts(); // Reload to update cost
                              },
                              tooltip: 'إدارة الوصفة',
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${product.price.toStringAsFixed(2)} ج.س',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                if (product.isAvailable)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'متاح',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showEditProductDialog(product),
                        onLongPress: () => _deleteProduct(product),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
