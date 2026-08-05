import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';
import 'new_purchase_screen.dart';

class PurchasesListScreen extends StatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير المشتريات'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<PurchaseInvoice>>(
          future: context.watch<AppProvider>().getPurchaseInvoices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final invoices = snapshot.data ?? [];
            if (invoices.isEmpty) {
              return const Center(child: Text('لا توجد فواتير شراء'));
            }

            return ListView.builder(
              itemCount: invoices.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('فاتورة #${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        _buildStatusBadge(inv.status),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('المورد: ${inv.supplierName}', style: const TextStyle(fontSize: 13)),
                        Text('التاريخ: ${inv.date}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${inv.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                        ),
                        const Text('ج.س', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    onTap: () => _showInvoiceItems(context, inv),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
          );
        },
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'paid':
        color = AppTheme.successColor;
        text = 'مدفوعة';
        break;
      case 'partial':
        color = AppTheme.warningColor;
        text = 'جزئية';
        break;
      default:
        color = AppTheme.errorColor;
        text = 'آجلة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showInvoiceItems(BuildContext context, PurchaseInvoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('تفاصيل فاتورة #${invoice.invoiceNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<List<PurchaseItem>>(
                  future: context.read<AppProvider>().getPurchaseItems(invoice.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ListTile(
                          title: Text(item.ingredientName ?? 'صنف'),
                          subtitle: Text('الكمية: ${item.quantity} | السعر: ${item.unitCost}'),
                          trailing: Text('${item.totalCost.toStringAsFixed(2)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
