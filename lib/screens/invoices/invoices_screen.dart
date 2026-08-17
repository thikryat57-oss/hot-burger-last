import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  final ValueListenable<bool>? activeListenable;

  const InvoicesScreen({super.key, this.activeListenable});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    widget.activeListenable?.addListener(_handleActiveChanged);
  }

  void _handleActiveChanged() {
    if (widget.activeListenable?.value == true) {
      _loadInvoices();
    }
  }

  @override
  void dispose() {
    widget.activeListenable?.removeListener(_handleActiveChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final appProvider = context.read<AppProvider>();
    final invoices = await appProvider.getInvoices();
    if (mounted) {
      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _isLoading = false;
      });
    }
  }

  void _searchInvoices(String query) {
    if (query.isEmpty) {
      setState(() => _filteredInvoices = _invoices);
    } else {
      setState(() {
        _filteredInvoices = _invoices
            .where((i) => i.invoiceNumber.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  Future<void> _cancelInvoice(Invoice invoice) async {
    final appProvider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content: Text('سيتم إلغاء الفاتورة وإرجاع المواد إلى المخزون. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('إلغاء الفاتورة'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await appProvider.voidInvoice(invoice.id!);
      _loadInvoices();
    }
  }

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
  );

  Future<void> _returnInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استرجاع الفاتورة'),
        content: const Text('سيتم استرجاع الفاتورة بالكامل وإعادة مواد الوصفة إلى المخزون. لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warningColor),
            child: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppProvider>().returnInvoice(invoice.id!);
      await _loadInvoices();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استرجاع الفاتورة وإعادة المخزون')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث برقم الفاتورة...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _searchInvoices('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchInvoices,
            ),
          ),
          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_filteredInvoices.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Text('عدد الفواتير', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${NumberFormat('#,##0.00').format(_filteredInvoices.fold(0.0, (sum, i) => sum + i.totalAmount))} ج.س',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const Text('الإجمالي', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Invoices list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInvoices,
                    child: _filteredInvoices.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 280,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 80, color: AppTheme.textHint),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد فواتير',
                                      style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredInvoices.length,
                            itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: IntrinsicHeight(
                                child: Container(
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(Icons.receipt, color: AppTheme.primaryColor),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (invoice.status == 'cancelled') ...[
                                    const SizedBox(width: 8),
                                    _statusBadge('ملغاة', AppTheme.errorColor),
                                  ] else if (invoice.status == 'returned') ...[
                                    const SizedBox(width: 8),
                                    _statusBadge('مسترجعة', AppTheme.warningColor),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                invoice.createdAt != null
                                    ? DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(DateTime.parse(invoice.createdAt!))
                                    : '',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${invoice.totalAmount.toStringAsFixed(2)} ج.س',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'استرجاع',
                                        icon: Icon(Icons.keyboard_return, color: AppTheme.warningColor, size: 20),
                                        onPressed: (invoice.status == 'cancelled' || invoice.status == 'returned') ? null : () => _returnInvoice(invoice),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'إلغاء',
                                        icon: Icon(Icons.cancel_outlined, color: AppTheme.errorColor, size: 20),
                                        onPressed: (invoice.status == 'cancelled' || invoice.status == 'returned') ? null : () => _cancelInvoice(invoice),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () async {
                                final detail = await context.read<AppProvider>().getInvoiceById(invoice.id!);
                                if (mounted && detail != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailScreen(invoice: detail),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
