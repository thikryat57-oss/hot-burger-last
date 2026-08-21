
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';
import 'recipe_editor_screen.dart';
import 'production_screen.dart';
import 'stocktake_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _isLoading = true;
  List<MaterialModel> _materials = [];
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final type = _filterType == 'all' ? null : _filterType;
    final materials = await appProvider.getMaterials(type: type);
    if (mounted) {
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواد والوصفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            tooltip: 'بدء جرد',
            onPressed: _handleStocktake,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showMaterialDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? const Center(child: Text('لا توجد مواد مضافة'))
                    : ListView.builder(
                        itemCount: _materials.length,
                        itemBuilder: (context, index) {
                          final material = _materials[index];
                          return _buildMaterialCard(material);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: const Text('الكل'),
            selected: _filterType == 'all',
            onSelected: (val) {
              setState(() => _filterType = 'all');
              _loadMaterials();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('مواد خام'),
            selected: _filterType == 'raw',
            onSelected: (val) {
              setState(() => _filterType = 'raw');
              _loadMaterials();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('مواد محضرة'),
            selected: _filterType == 'prepared',
            onSelected: (val) {
              setState(() => _filterType = 'prepared');
              _loadMaterials();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(MaterialModel material) {
    final isLow = material.quantity <= material.minQuantity && material.minQuantity > 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isLow ? AppTheme.errorColor.withOpacity(0.5) : AppTheme.textHint.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (material.isPrepared ? Colors.blue : Colors.green).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    material.isPrepared ? Icons.restaurant : Icons.category,
                    color: material.isPrepared ? Colors.blue : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        material.isPrepared ? 'مادة محضرة' : 'مادة خام',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'نفاد قريب',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.textHint.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('الكمية', '${material.quantity} ${material.unit}', isLow ? AppTheme.errorColor : AppTheme.primaryColor),
                  _buildStatItem('التكلفة', '${material.costPrice.toStringAsFixed(2)} ر.س', AppTheme.textSecondary),
                  _buildStatItem('الحد', '${material.minQuantity} ${material.unit}', AppTheme.textHint),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (material.isPrepared) ...[
                  _buildActionButton(
                    icon: Icons.precision_manufacturing,
                    color: Colors.blue,
                    tooltip: 'إنتاج',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProductionScreen(material: material)),
                    ).then((_) => _loadMaterials()),
                  ),
                  _buildActionButton(
                    icon: Icons.receipt_long,
                    color: Colors.purple,
                    tooltip: 'وصفة',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeEditorScreen(
                          parentType: 'material',
                          parentId: material.id!,
                          parentName: material.name,
                        ),
                      ),
                    ).then((_) => _loadMaterials()),
                  ),
                ],
                _buildActionButton(
                  icon: Icons.analytics_outlined,
                  color: Colors.orange,
                  tooltip: 'تسوية',
                  onPressed: () => _showAdjustmentDialog(material),
                ),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: AppTheme.textSecondary,
                  tooltip: 'تعديل',
                  onPressed: () => _showMaterialDialog(material: material),
                ),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  color: AppTheme.errorColor,
                  tooltip: 'حذف',
                  onPressed: () => _handleDeleteMaterial(material),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.textHint),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(),
    );
  }

  void _handleDeleteMaterial(MaterialModel material) async {
    final provider = context.read<AppProvider>();
    
    // 1. Show loading impact preview
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final impact = await provider.getMaterialImpact(material.id!);
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // 2. Analyze impact and show appropriate dialog
    final bool isSafe = impact['is_safe'] == true;
    final int purchaseCount = impact['purchase_count'] ?? 0;
    final int productionCount = impact['production_count'] ?? 0;
    final int adjustmentCount = impact['adjustment_count'] ?? 0;
    final List recipeLinks = impact['recipe_links'] ?? [];

    if (purchaseCount > 0 || productionCount > 0 || adjustmentCount > 0) {
      // PERMANENTLY BLOCKED
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('لا يمكن حذف المادة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('هذه المادة مرتبطة بسجلات تاريخية لا يمكن حذفها لضمان سلامة البيانات المالية:'),
              const SizedBox(height: 12),
              if (purchaseCount > 0) Text('• $purchaseCount فاتورة شراء'),
              if (productionCount > 0) Text('• $productionCount عملية إنتاج'),
              if (adjustmentCount > 0) Text('• $adjustmentCount عملية تسوية/جرد'),
              const SizedBox(height: 12),
              const Text('يمكنك بدلاً من ذلك جعل المادة غير نشطة (قريباً).', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
          ],
        ),
      );
      return;
    }

    // 3. Confirm Deletion (with force if recipes exist)
    final bool needsForce = recipeLinks.isNotEmpty;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف المادة "${material.name}"؟'),
            if (needsForce) ...[
              const SizedBox(height: 12),
              Text(
                'تنبيه: هذه المادة مستخدمة في ${recipeLinks.length} وصفة. سيؤدي الحذف إلى إزالة هذه المادة من الوصفات التالية:',
                style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...recipeLinks.take(5).map((l) => Text('• ${l['parent_name']} (${l['parent_type'] == 'product' ? 'منتج' : 'مادة'})')),
              if (recipeLinks.length > 5) Text('... و ${recipeLinks.length - 5} أخرى'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              try {
                await provider.deleteMaterial(material.id!, force: needsForce);
                if (mounted) {
                  Navigator.pop(context);
                  _loadMaterials();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف المادة بنجاح')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _handleStocktake() async {
    final provider = context.read<AppProvider>();
    final activeSession = await provider.getActiveStocktakeSession();
    
    if (!mounted) return;

    if (activeSession != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StocktakeScreen(sessionId: activeSession.id!)),
      ).then((_) => _loadMaterials());
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('بدء جرد جديد'),
          content: const Text('هل تريد بدء جلسة جرد جديدة للمخزون؟ سيتم تسجيل الكميات الحالية ككميات نظرية.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final id = await provider.startStocktakeSession();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StocktakeScreen(sessionId: id)),
                  ).then((_) => _loadMaterials());
                }
              },
              child: const Text('بدء الجرد'),
            ),
          ],
        ),
      );
    }
  }

  void _showAdjustmentDialog(MaterialModel material) {
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    String actionType = 'waste';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تسوية مخزون: ${material.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: actionType,
                items: const [
                  DropdownMenuItem(value: 'waste', child: Text('فاقد / هالك')),
                  DropdownMenuItem(value: 'damage', child: Text('تلف')),
                  DropdownMenuItem(value: 'theft', child: Text('سرقة')),
                  DropdownMenuItem(value: 'correction', child: Text('تصحيح يدوي')),
                ],
                onChanged: (val) => setDialogState(() => actionType = val!),
                decoration: const InputDecoration(labelText: 'نوع التسوية'),
              ),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  hintText: 'استخدم قيمة سالبة للنقص',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'السبب / ملاحظات'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final change = double.tryParse(qtyController.text) ?? 0;
                if (change == 0) return;
                
                final adj = InventoryAdjustment(
                  materialId: material.id!,
                  materialName: material.name,
                  quantityChange: change,
                  actionType: actionType,
                  costPriceAtAction: material.costPrice,
                  date: DateTime.now().toIso8601String(),
                  notes: notesController.text,
                );
                
                await context.read<AppProvider>().adjustInventory(adj);
                if (mounted) {
                  Navigator.pop(context);
                  _loadMaterials();
                }
              },
              child: const Text('تنفيذ التسوية'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialDialog({MaterialModel? material}) {
    final nameController = TextEditingController(text: material?.name);
    final minQtyController = TextEditingController(text: material?.minQuantity.toString() ?? '0');
    final costController = TextEditingController(text: material?.costPrice.toString() ?? '0');
    final openingQtyController = TextEditingController(text: '0');
    
    String type = material?.type ?? 'raw';
    String selectedUnit = material?.unit ?? 'حبة';
    final List<String> commonUnits = ['حبة', 'كيلو', 'جرام', 'لتر', 'مل', 'عبوة', 'كيس'];
    if (!commonUnits.contains(selectedUnit)) {
      commonUnits.add(selectedUnit);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(material == null ? 'إضافة مادة جديدة' : 'تعديل بيانات المادة'),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المادة',
                      hintText: 'مثلاً: طماطم، لحم، خبز',
                      prefixIcon: Icon(Icons.drive_file_rename_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'raw', child: Text('مادة خام (تُشترى)')),
                      DropdownMenuItem(value: 'prepared', child: Text('مادة محضرة (تُنتج)')),
                    ],
                    onChanged: material != null ? null : (val) => setDialogState(() => type = val!),
                    decoration: const InputDecoration(
                      labelText: 'نوع المادة',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      helperText: 'لا يمكن تغيير النوع بعد الإنشاء',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    items: commonUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) => setDialogState(() => selectedUnit = val!),
                    decoration: const InputDecoration(
                      labelText: 'وحدة القياس',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (material == null) ...[
                    TextField(
                      controller: openingQtyController,
                      decoration: InputDecoration(
                        labelText: 'الكمية الافتتاحية',
                        suffixText: selectedUnit,
                        prefixIcon: const Icon(Icons.add_business_outlined),
                        helperText: 'الكمية الموجودة حالياً في المخزن',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: minQtyController,
                    decoration: InputDecoration(
                      labelText: 'حد التنبيه بالنفاد',
                      suffixText: selectedUnit,
                      prefixIcon: const Icon(Icons.notifications_active_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (type == 'raw') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة (للوحدة)',
                        suffixText: 'ر.س',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المادة')));
                  return;
                }
                
                final provider = context.read<AppProvider>();
                final newMaterial = MaterialModel(
                  id: material?.id,
                  name: name,
                  type: type,
                  unit: selectedUnit,
                  minQuantity: double.tryParse(minQtyController.text) ?? 0,
                  costPrice: type == 'raw' ? (double.tryParse(costController.text) ?? 0) : (material?.costPrice ?? 0),
                  quantity: material == null ? (double.tryParse(openingQtyController.text) ?? 0) : material.quantity,
                  isActive: material?.isActive ?? true,
                );
                
                try {
                  int id;
                  if (material == null) {
                    id = await provider.addMaterial(newMaterial);
                  } else {
                    id = material.id!;
                    await provider.updateMaterial(newMaterial);
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadMaterials();
                    
                    // If it's a new prepared material, suggest adding a recipe
                    if (material == null && type == 'prepared') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeEditorScreen(
                            parentType: 'material',
                            parentId: id,
                            parentName: name,
                          ),
                        ),
                      ).then((_) => _loadMaterials());
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ البيانات'),
            ),
          ],
        ),
      ),
    );
  }
}
