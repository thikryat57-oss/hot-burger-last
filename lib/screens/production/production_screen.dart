
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';

class ProductionScreen extends StatefulWidget {
  final MaterialModel material;

  const ProductionScreen({super.key, required this.material});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isProcessing = false;
  List<RecipeModel> _recipe = [];
  bool _isLoadingRecipe = true;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    final recipe = await context.read<AppProvider>().getRecipe('material', widget.material.id!);
    if (mounted) {
      setState(() {
        _recipe = recipe;
        _isLoadingRecipe = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إنتاج: ${widget.material.name}'),
      ),
      body: _isLoadingRecipe
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  const Text('الكمية المراد إنتاجها:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'أدخل الكمية',
                      suffixText: widget.material.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const Text('المكونات المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildComponentsList(),
                  const SizedBox(height: 20),
                  const Text('ملاحظات:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(hintText: 'ملاحظات اختيارية'),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isProcessing ? null : _processProduction,
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('بدء عملية الإنتاج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المخزون الحالي:'),
                Text('${widget.material.quantity} ${widget.material.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('التكلفة الحالية للوحدة:'),
                Text('${widget.material.costPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentsList() {
    if (_recipe.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('تحذير: لا توجد وصفة محددة لهذه المادة', style: TextStyle(color: Colors.red)),
      );
    }

    final double prodQty = double.tryParse(_qtyController.text) ?? 0;

    return Column(
      children: _recipe.map((item) {
        final required = item.quantity * prodQty;
        return ListTile(
          title: Text(item.materialName ?? ''),
          trailing: Text('${required.toStringAsFixed(2)} ${item.unit}'),
          subtitle: Text('لكل وحدة: ${item.quantity} ${item.unit}'),
        );
      }).toList(),
    );
  }

  Future<void> _processProduction() async {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال كمية صالحة')));
      return;
    }

    if (_recipe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن الإنتاج بدون وصفة')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await context.read<AppProvider>().produceBatch(
            widget.material.id!,
            qty,
            notes: _notesController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت عملية الإنتاج بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
