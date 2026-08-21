
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';

class StocktakeScreen extends StatefulWidget {
  final int sessionId;

  const StocktakeScreen({super.key, required this.sessionId});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  bool _isLoading = true;
  List<StocktakeItem> _items = [];
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final items = await provider.getStocktakeItems(widget.sessionId);
    
    if (mounted) {
      setState(() {
        _items = items;
        for (var item in _items) {
          _controllers[item.id!] = TextEditingController(text: item.countedQty.toString());
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateItem(StocktakeItem item, String value) async {
    final counted = double.tryParse(value) ?? item.theoreticalQty;
    final updated = StocktakeItem(
      id: item.id,
      sessionId: item.sessionId,
      materialId: item.materialId,
      materialName: item.materialName,
      theoreticalQty: item.theoreticalQty,
      countedQty: counted,
      variance: counted - item.theoreticalQty,
      unitCostAtCount: item.unitCostAtCount,
    );
    await context.read<AppProvider>().updateStocktakeItem(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'اعتماد الجرد',
            onPressed: _showFinalizeDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أدخل الكميات الفعلية الموجودة في المخزن حالياً. سيتم احتساب الفرق تلقائياً.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final variance = item.countedQty - item.theoreticalQty;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.materialName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    'النظري: ${item.theoreticalQty}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _controllers[item.id!],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (val) => _updateItem(item, val),
                                onChanged: (val) {
                                  // Debounced or on-change update if needed
                                  final counted = double.tryParse(val) ?? 0;
                                  setState(() {
                                    _items[index] = StocktakeItem(
                                      id: item.id,
                                      sessionId: item.sessionId,
                                      materialId: item.materialId,
                                      materialName: item.materialName,
                                      theoreticalQty: item.theoreticalQty,
                                      countedQty: counted,
                                      variance: counted - item.theoreticalQty,
                                      unitCostAtCount: item.unitCostAtCount,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    variance == 0 ? '0' : (variance > 0 ? '+$variance' : '$variance'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: variance == 0 ? Colors.grey : (variance > 0 ? Colors.green : Colors.red),
                                    ),
                                  ),
                                  const Text('الفرق', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showFinalizeDialog() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد الجرد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد من اعتماد نتائج الجرد؟ سيتم تحديث كميات المخزون بناءً على الأرقام المدخلة وتسجيل فروقات الجرد.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().finalizeStocktakeSession(
                widget.sessionId,
                notes: notesController.text,
              );
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to materials
              }
            },
            child: const Text('اعتماد نهائي'),
          ),
        ],
      ),
    );
  }
}
