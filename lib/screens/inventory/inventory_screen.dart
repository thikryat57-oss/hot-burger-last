import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'inventory_history_screen.dart';

class InventoryScreen extends StatelessWidget {
  final ValueListenable<bool>? activeListenable;

  const InventoryScreen({super.key, this.activeListenable});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'المخزون', icon: Icon(Icons.inventory_2)),
              Tab(text: 'سجل الحركات', icon: Icon(Icons.history)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _InventoryList(activeListenable: activeListenable),
                const InventoryHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryList extends StatefulWidget {
  final ValueListenable<bool>? activeListenable;

  const _InventoryList({this.activeListenable});

  @override
  State<_InventoryList> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<_InventoryList> {
  List<IngredientModel> _ingredients = [];
  List<IngredientModel> _lowStock = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.activeListenable?.addListener(_handleActiveChanged);
  }

  void _handleActiveChanged() {
    if (widget.activeListenable?.value == true) {
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.activeListenable?.removeListener(_handleActiveChanged);
    super.dispose();
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

  // ===== قسم المواد التي تحتاج إلى شراء =====
  // يعرض المواد التي انخفضت عن الحد الأدنى مع الكمية المقترحة للشراء
  // الترتيب: نسبة (الحالي ÷ الحد الأدنى) الأصغر أولًا، ثم حسب الاسم
  Widget _buildPurchaseSuggestions() {
    // استخدام قائمة المواد الموجودة (من Provider) دون استعلام جديد
    final suggestions = _ingredients
        .where((i) => i.minQuantity > 0 && i.quantity < i.minQuantity)
        .toList()
      ..sort((a, b) {
        // نسبة الاحتياج: الأقل أولًا (المواد الأشد حاجة أولًا)
        final ratioA = a.minQuantity > 0 ? a.quantity / a.minQuantity : 0.0;
        final ratioB = b.minQuantity > 0 ? b.quantity / b.minQuantity : 0.0;
        final cmp = ratioA.compareTo(ratioB);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });

    if (suggestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          'لا توجد مواد تحتاج إلى شراء حاليًا.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textHint),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_basket, color: AppTheme.warningColor, size: 18),
              const SizedBox(width: 6),
              const Text(
                'المواد التي تحتاج إلى شراء',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${suggestions.length} مادة',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.map((i) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppTheme.warningColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.warningColor.withOpacity(0.5), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.add_shopping_cart, color: AppTheme.warningColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'الحالي: ${i.quantity} ${i.unit} · الحد: ${i.minQuantity} ${i.unit}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'يُقترح شراء: ${(i.minQuantity - i.quantity).toStringAsFixed(1)} ${i.unit}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
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
                  await context.read<AppProvider>().updateIngredient(IngredientModel(
                    id: ingredient.id,
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // السطر العلوي: أيقونة + اسم المادة + شارة نفاد قريب
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isLow
                                              ? AppTheme.warningColor.withOpacity(0.15)
                                              : AppTheme.accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isLow ? Icons.warning_amber_rounded : Icons.inventory,
                                          color: isLow ? AppTheme.warningColor : AppTheme.accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          ingredient.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isLow)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                  const SizedBox(height: 6),
                                  // السطر الأوسط: الكمية والوحدة + حد التنبيه
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${ingredient.quantity} ${ingredient.unit}',
                                          style: TextStyle(
                                            color: isLow ? AppTheme.warningColor : AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'الحد: ${ingredient.minQuantity} ${ingredient.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // السطر الأخير: التكلفة + الأزرار الثلاثة
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${ingredient.costPrice.toStringAsFixed(2)} ج.س',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: Icon(Icons.shopping_cart, color: AppTheme.successColor, size: 18),
                                            onPressed: () => _showPurchaseDialog(ingredient),
                                            tooltip: 'تسجيل شراء',
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: Icon(Icons.edit, color: AppTheme.textSecondary, size: 18),
                                            onPressed: () => _showEditIngredientDialog(ingredient),
                                            tooltip: 'تعديل',
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: Icon(Icons.delete, color: AppTheme.errorColor, size: 18),
                                            onPressed: () => _deleteIngredient(ingredient),
                                            tooltip: 'حذف',
                                          ),
                                        ],
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
          // المواد التي تحتاج إلى شراء (تحت الحد الأدنى)
          _buildPurchaseSuggestions(),
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
