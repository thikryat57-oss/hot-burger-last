import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class RecipeManagementScreen extends StatefulWidget {
  final Product product;

  const RecipeManagementScreen({super.key, required this.product});

  @override
  State<RecipeManagementScreen> createState() =>
      _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  List<Map<String, dynamic>> _recipeItems = [];
  List<IngredientModel> _allIngredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appProvider = context.read<AppProvider>();
    final ingredients = await appProvider.getIngredients();
    final recipeItems = await appProvider.getProductIngredients(widget.product.id!);
    if (mounted) {
      setState(() {
        _allIngredients = ingredients;
        _recipeItems = recipeItems;
        _isLoading = false;
      });
    }
  }

  void _showAddIngredientDialog() {
    // Get available ingredients (not already in recipe)
    final usedIds = _recipeItems.map((e) => e['ingredient_id'] as int).toSet();
    final availableIngredients =
        _allIngredients.where((i) => !usedIds.contains(i.id)).toList();

    if (availableIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مواد خام متاحة للإضافة')),
      );
      return;
    }

    int? selectedIngredientId;
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة مادة خام للوصفة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedIngredientId,
                    decoration: const InputDecoration(hintText: 'اختر المادة الخام'),
                    items: availableIngredients.map((i) {
                      return DropdownMenuItem(
                        value: i.id,
                        child: Text('${i.name} (${i.quantity} ${i.unit})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedIngredientId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      hintText: 'الكمية المستهلكة لكل وحدة منتج',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (selectedIngredientId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'المخزون الحالي: ${availableIngredients.firstWhere((i) => i.id == selectedIngredientId).quantity} ${availableIngredients.firstWhere((i) => i.id == selectedIngredientId).unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedIngredientId == null) return;
                  final qty = double.tryParse(quantityController.text) ?? 0;
                  if (qty <= 0) return;

                  await context.read<AppProvider>().addProductIngredient(
                        ProductIngredient(
                          productId: widget.product.id!,
                          ingredientId: selectedIngredientId!,
                          quantity: qty,
                        ),
                      );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _loadData();
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuantityDialog(Map<String, dynamic> item) {
    final quantityController =
        TextEditingController(text: (item['quantity'] as num).toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تعديل الكمية - ${item['ingredient_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الوحدة: ${item['unit']}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                hintText: 'الكمية المستهلكة لكل وحدة منتج',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(quantityController.text) ?? 0;
              if (qty <= 0) return;

              await context.read<AppProvider>().addProductIngredient(
                    ProductIngredient(
                      productId: widget.product.id!,
                      ingredientId: item['ingredient_id'],
                      quantity: qty,
                    ),
                  );

              if (mounted) {
                Navigator.pop(dialogContext);
                _loadData();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIngredient(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف من الوصفة'),
        content: Text(
            'هل أنت متأكد من حذف "${item['ingredient_name']}" من وصفة ${widget.product.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppProvider>().deleteProductIngredient(
            widget.product.id!,
            item['ingredient_id'],
          );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وصفة: ${widget.product.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipeItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant,
                          size: 80, color: AppTheme.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد مواد خام في الوصفة',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أضف مواد خام لتحديد الوصفة',
                        style: TextStyle(color: AppTheme.textHint),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddIngredientDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مادة خام'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'وصفة ${widget.product.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_recipeItems.length} مادة خام',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _recipeItems.length,
                        itemBuilder: (context, index) {
                          final item = _recipeItems[index];
                          final ingredientName = item['ingredient_name'] as String;
                          final quantity = (item['quantity'] as num).toDouble();
                          final unit = item['unit'] as String;
                          final currentStock =
                              (item['current_stock'] as num).toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: currentStock <= 0
                                      ? AppTheme.errorColor.withOpacity(0.15)
                                      : AppTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  currentStock <= 0
                                      ? Icons.error_outline
                                      : Icons.inventory,
                                  color: currentStock <= 0
                                      ? AppTheme.errorColor
                                      : AppTheme.accentColor,
                                ),
                              ),
                              title: Text(
                                ingredientName,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'المطلوب: $quantity $unit لكل وحدة',
                                    style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'المخزون: $currentStock $unit',
                                    style: TextStyle(
                                      color: currentStock <= 0
                                          ? AppTheme.errorColor
                                          : AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: AppTheme.textSecondary, size: 20),
                                    onPressed: () =>
                                        _showEditQuantityDialog(item),
                                    tooltip: 'تعديل الكمية',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: AppTheme.errorColor, size: 20),
                                    onPressed: () => _deleteIngredient(item),
                                    tooltip: 'حذف',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIngredientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
