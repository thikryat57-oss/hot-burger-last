import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SupplierDetailScreen extends StatefulWidget {
  final int supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Supplier?>(
      future: context.watch<AppProvider>().getSupplierById(widget.supplierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final supplier = snapshot.data;
        if (supplier == null) {
          return const Scaffold(body: Center(child: Text('المورد غير موجود')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.payment),
                onPressed: () => _showPaymentDialog(context, supplier),
                tooltip: 'تسجيل دفعة',
              ),
            ],
          ),
          body: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Column(
              children: [
                // Supplier Info Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          supplier.name[0],
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(supplier.phone ?? 'بدون رقم هاتف', style: TextStyle(color: AppTheme.textSecondary)),
                            if (supplier.address != null && supplier.address!.isNotEmpty)
                              Text(supplier.address!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('الرصيد الحالي', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(
                            '${supplier.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: supplier.balance > 0 ? AppTheme.errorColor : AppTheme.successColor,
                            ),
                          ),
                          const Text('ج.س', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20, color: AppTheme.textSecondary),
                      SizedBox(width: 8),
                      Text('كشف الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: context.read<AppProvider>().getSupplierLedger(widget.supplierId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final ledger = snapshot.data ?? [];
                      if (ledger.isEmpty) {
                        return const Center(child: Text('لا توجد حركات سابقة'));
                      }

                      return ListView.separated(
                        itemCount: ledger.length,
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = ledger[index];
                          final isInvoice = item['type'] == 'invoice';
                          
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isInvoice ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
                                child: Icon(
                                  isInvoice ? Icons.receipt_outlined : Icons.payments_outlined,
                                  color: isInvoice ? AppTheme.errorColor : AppTheme.successColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                isInvoice ? 'فاتورة شراء #${item['number']}' : 'دفعة سداد',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['date'], style: const TextStyle(fontSize: 12)),
                                  if (item['notes'] != null && item['notes'].isNotEmpty)
                                    Text(item['notes'], style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                              trailing: Text(
                                '${isInvoice ? "+" : "-"}${item['amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isInvoice ? AppTheme.errorColor : AppTheme.successColor,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, Supplier supplier) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل دفعة للمورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('رصيد المورد الحالي: ${supplier.balance.toStringAsFixed(2)} ج.س', 
                 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع *'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            TextField(
              controller: dateController,
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
                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              
              final payment = SupplierPayment(
                supplierId: supplier.id!,
                amount: amount,
                date: dateController.text,
                notes: notesController.text,
              );
              
              await context.read<AppProvider>().addSupplierPayment(payment);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {}); // Refresh ledger
              }
            },
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
  }
}
