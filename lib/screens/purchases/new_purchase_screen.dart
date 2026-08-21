import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  Supplier? _selectedSupplier;
  final List<PurchaseItem> _items = [];
  final _invoiceNumberController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  String _status = 'unpaid';

  double get _totalAmount => _items.fold(0, (sum, item) => sum + item.totalCost);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة شراء جديدة'),
      ),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          children: [
            // Header Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      FutureBuilder<List<Supplier>>(
                        future: context.read<AppProvider>().getSuppliers(),
                        builder: (context, snapshot) {
                          final suppliers = snapshot.data ?? [];
                          return DropdownButtonFormField<Supplier>(
                            decoration: const InputDecoration(labelText: 'المورد *'),
                            value: _selectedSupplier,
                            items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                            onChanged: (val) => setState(() => _selectedSupplier = val),
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _invoiceNumberController,
                              decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _dateController,
                              decoration: const InputDecoration(labelText: 'التاريخ'),
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Items List
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('لم يتم إضافة أصناف بعد'))
                  : ListView.builder(
                      itemCount: _items.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
	                            title: Text(item.materialName ?? 'صنف', style: const TextStyle(fontWeight: FontWeight.bold)),
	                            subtitle: Text('الكمية: ${item.quantity} ${item.unit ?? ''} | السعر: ${item.unitCost}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item.totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                  onPressed: () => setState(() => _items.removeAt(index)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Summary & Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_totalAmount.toStringAsFixed(2)} ج.س', 
                           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _paidAmountController,
                          decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final paid = double.tryParse(val) ?? 0;
                            setState(() {
                              if (paid >= _totalAmount && _totalAmount > 0) {
                                _status = 'paid';
                              } else if (paid > 0) {
                                _status = 'partial';
                              } else {
                                _status = 'unpaid';
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'حالة الدفع'),
                          value: _status,
                          items: const [
                            DropdownMenuItem(value: 'paid', child: Text('مدفوع بالكامل')),
                            DropdownMenuItem(value: 'partial', child: Text('دفع جزئي')),
                            DropdownMenuItem(value: 'unpaid', child: Text('آجل / لم يدفع')),
                          ],
                          onChanged: (val) => setState(() => _status = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddItemDialog(context),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('إضافة صنف'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 45)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveInvoice,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ الفاتورة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 45),
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
    );
  }

  void _showAddItemDialog(BuildContext context) {
    MaterialModel? selectedMat;
    final qtyController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة صنف للفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<List<MaterialModel>>(
              future: context.read<AppProvider>().getMaterials(),
              builder: (context, snapshot) {
                final materials = (snapshot.data ?? []).where((m) => !m.isPrepared).toList();
                return DropdownButtonFormField<MaterialModel>(
                  decoration: const InputDecoration(labelText: 'المادة الخام *'),
                  items: materials.map((i) => DropdownMenuItem(value: i, child: Text(i.name))).toList(),
                  onChanged: (val) {
                    selectedMat = val;
                    costController.text = val?.costPrice.toString() ?? '';
                  },
                );
              },
            ),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'الكمية *'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'سعر التكلفة (للوحدة) *'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              final cost = double.tryParse(costController.text) ?? 0;
              if (selectedMat == null || qty <= 0 || cost <= 0) return;
              
              setState(() {
                _items.add(PurchaseItem(
                  materialId: selectedMat!.id!,
                  materialName: selectedMat!.name,
                  quantity: qty,
                  unitCost: cost,
                  totalCost: qty * cost,
                  unit: selectedMat!.unit,
                ));
              });
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار مورد'), backgroundColor: AppTheme.errorColor));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إضافة أصناف للفاتورة'), backgroundColor: AppTheme.errorColor));
      return;
    }

    try {
      final invoice = PurchaseInvoice(
        supplierId: _selectedSupplier!.id!,
        invoiceNumber: _invoiceNumberController.text,
        totalAmount: _totalAmount,
        paidAmount: double.tryParse(_paidAmountController.text) ?? 0,
        status: _status,
        date: _dateController.text,
        notes: _notesController.text,
      );

      await context.read<AppProvider>().createPurchaseInvoice(invoice, _items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح'), backgroundColor: AppTheme.successColor));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }
}
