import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<IngredientModel> _ingredients = [];
  List<IngredientModel> _lowStock = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appProvider = context.read<AppProvider>();
    final ingredients = await appProvider.getIngredients();
    final lowStock = await appProvider.getLowStockIngredients();
    if (mounted) {
      setState(() {
        _ingredients = ingredients;
        _lowStock = lowStock;
        _isLoading = false;
      });
    }
  }

  void _showAddIngredientDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final minQuantityController = TextEditingController(text: '0');
    final costPriceController = TextEditingController(text: '0');
    String selectedUnit = 'حبة';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة مادة خام'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'اسم المادة الخام'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(hintText: 'الكمية الحالية'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(hintText: 'الوحدة'),
                    items: ['حبة', 'كيلو', 'جرام', 'لتر', 'مل', 'عبوة', 'كيس']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedUnit = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minQuantityController,
                    decoration: const InputDecoration(hintText: 'حد التنبيه بالنفاد'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costPriceController,
                    decoration: const InputDecoration(hintText: 'سعر التكلفة'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
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
                  if (nameController.text.isEmpty) return;
                  await context.read<AppProvider>().addIngredient(IngredientModel(
                    name: nameController.text,
                    quantity: double.tryParse(quantityController.text) ?? 0,
                    unit: selectedUnit,
                    minQuantity: double.tryParse(minQuantityController.text) ?? 0,
                    costPrice: double.tryParse(costPriceController.text) ?? 0,
                  ));
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

  void _showEditIngredientDialog(IngredientModel ingredient) {
    final nameController = TextEditingController(text: ingredient.name);
    final quantityController = TextEditingController(text: ingredient.quantity.toString());
    final minQuantityController = TextEditingController(text: ingredient.minQuantity.toString());
    final costPriceController = TextEditingController(text: ingredient.costPrice.toString());
    String selectedUnit = ingredient.unit;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('تعديل المادة الخام'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'اسم المادة الخام'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(hintText: 'الكمية الحالية'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(hintText: 'الوحدة'),
                    items: ['حبة', 'كيلو', 'جرام', 'لتر', 'مل', 'عبوة', 'كيس']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedUnit = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minQuantityController,
                    decoration: const InputDecoration(hintText: 'حد التنبيه بالنفاد'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costPriceController,
                    decoration: const InputDecoration(hintText: 'سعر التكلفة'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
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
                  if (nameController.text.isEmpty) return;
                  final provider = Provider.of<AppProvider>(dialogContext, listen: false);
                  await provider.updateIngredient(IngredientModel(
                    id: ingredient.id,
                    name: nameController.text,
                    quantity: double.tryParse(quantityController.text) ?? 0,
                    unit: selectedUnit,
                    minQuantity: double.tryParse(minQuantityController.text) ?? 0,
                    costPrice: double.tryParse(costPriceController.text) ?? 0,
                  ));
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    await _loadData();
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

  void _showPurchaseDialog(IngredientModel ingredient) {
    final quantityController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تسجيل عملية شراء - ${ingredient.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الكمية الحالية: ${ingredient.quantity} ${ingredient.unit}',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  hintText: 'الكمية المشتراة (${ingredient.unit})',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: const InputDecoration(hintText: 'سعر الشراء (اختياري)'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
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
              final purchasedQty = double.tryParse(quantityController.text) ?? 0;
              if (purchasedQty <= 0) return;
              final cost = double.tryParse(costController.text) ?? 0;
              await context.read<AppProvider>().recordPurchase(
                ingredient.id!,
                purchasedQty,
                cost,
              );
              if (mounted) {
                Navigator.pop(dialogContext);
                _loadData();
              }
            },
            child: const Text('تسجيل الشراء'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIngredient(IngredientModel ingredient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المادة الخام'),
        content: Text('هل أنت متأكد من حذف "${ingredient.name}"؟'),
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
      await context.read<AppProvider>().deleteIngredient(ingredient.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddIngredientDialog,
            tooltip: 'إضافة مادة خام',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
          // Low stock warning banner
          if (_lowStock.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.warningColor.withOpacity(0.15),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تحذير: ${_lowStock.length} مادة قرب النفاد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        Text(
                          _lowStock.map((i) => i.name).join('، '),
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Inventory list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ingredients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.textHint),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مواد خام',
                              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أضف مواد خام لتتبع المخزون',
                              style: TextStyle(color: AppTheme.textHint),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ingredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = _ingredients[index];
                          final isLow = ingredient.isLowStock;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isLow
                                ? AppTheme.warningColor.withOpacity(0.1)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isLow
                                  ? BorderSide(color: AppTheme.warningColor, width: 1)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isLow
                                      ? AppTheme.warningColor.withOpacity(0.15)
                                      : AppTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isLow ? Icons.warning_amber_rounded : Icons.inventory,
                                  color: isLow ? AppTheme.warningColor : AppTheme.accentColor,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ingredient.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLow)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'نفاد قريب',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${ingredient.quantity} ${ingredient.unit}',
                                      style: TextStyle(
                                        color: isLow ? AppTheme.warningColor : AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'الحد: ${ingredient.minQuantity} ${ingredient.unit}',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${ingredient.costPrice.toStringAsFixed(2)} ج.س',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                      Text(
                                        'التكلفة',
                                        style: TextStyle(fontSize: 10, color: AppTheme.textHint),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.shopping_cart, color: AppTheme.successColor, size: 20),
                                    onPressed: () => _showPurchaseDialog(ingredient),
                                    tooltip: 'تسجيل شراء',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                                    onPressed: () => _showEditIngredientDialog(ingredient),
                                    tooltip: 'تعديل',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                                    onPressed: () => _deleteIngredient(ingredient),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIngredientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
