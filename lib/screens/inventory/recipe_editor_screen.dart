
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/utils/recipe_engine.dart';

class RecipeEditorScreen extends StatefulWidget {
  final String parentType;
  final int parentId;
  final String parentName;

  const RecipeEditorScreen({
    super.key,
    required this.parentType,
    required this.parentId,
    required this.parentName,
  });

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  List<RecipeModel> _recipeItems = [];
  List<MaterialModel> _availableMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    final recipe = await provider.getRecipe(widget.parentType, widget.parentId);
    final materials = await provider.getMaterials();
    
    if (mounted) {
      setState(() {
        _recipeItems = recipe;
        _availableMaterials = materials;
        _isLoading = false;
      });
    }
  }

  void _addIngredient({RecipeModel? existingItem, int? index}) {
    showDialog(
      context: context,
      builder: (context) {
        MaterialModel? selected = existingItem != null
            ? _availableMaterials.firstWhere((m) => m.id == existingItem.materialId)
            : null;
        final qtyController = TextEditingController(text: existingItem?.quantity.toString());
        
        final filteredMaterials = _availableMaterials.where((m) {
          // Don't show already added materials unless editing this specific one
          final isAlreadyAdded = _recipeItems.any((ri) => ri.materialId == m.id);
          if (existingItem != null && m.id == existingItem.materialId) return true;
          return !isAlreadyAdded;
        }).toList();

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existingItem == null ? 'إضافة مكون' : 'تعديل مكون'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (filteredMaterials.isEmpty && existingItem == null)
                  const Text('لا توجد مواد متاحة للإضافة. أضف مواد خام أولاً.')
                else ...[
                  DropdownButtonFormField<MaterialModel>(
                    value: selected,
                    items: filteredMaterials
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selected = val),
                    decoration: const InputDecoration(labelText: 'المادة', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      suffixText: selected?.unit ?? '',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              if (!(filteredMaterials.isEmpty && existingItem == null))
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text) ?? 0;
                    if (selected == null || qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى اختيار مادة وإدخال كمية صحيحة')),
                      );
                      return;
                    }
                    
                    if (widget.parentType == 'material' && selected!.id == widget.parentId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لا يمكن للمادة أن تعتمد على نفسها')),
                      );
                      return;
                    }

                    setState(() {
                      final newItem = RecipeModel(
                        id: existingItem?.id,
                        parentType: widget.parentType,
                        parentId: widget.parentId,
                        materialId: selected!.id!,
                        materialName: selected!.name,
                        quantity: qty,
                        unit: selected!.unit,
                      );
                      
                      if (index != null) {
                        _recipeItems[index] = newItem;
                      } else {
                        _recipeItems.add(newItem);
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Text(existingItem == null ? 'إضافة' : 'تحديث'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وصفة: ${widget.parentName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _recipeItems.length,
                    itemBuilder: (context, index) {
                      final item = _recipeItems[index];
                      return ListTile(
                        title: Text(item.materialName ?? 'مادة غير معروفة', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('الكمية: ${item.quantity} ${item.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _addIngredient(existingItem: item, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _recipeItems.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة مكون'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () async {
                            await context.read<AppProvider>().updateRecipe(
                              widget.parentType,
                              widget.parentId,
                              _recipeItems,
                            );
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text('حفظ الوصفة', style: TextStyle(color: Colors.white)),
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
