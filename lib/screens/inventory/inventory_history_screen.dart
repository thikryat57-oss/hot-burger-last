import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/pdf_helper.dart';

/// Inventory audit trail screen: full history of every stock movement.
class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedActionType;
  int? _selectedIngredientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _ingredients = [];
  bool _loading = true;

  static const Map<String, String> _actionLabels = {
    'added': 'إضافة مادة',
    'edited': 'تعديل مادة',
    'manual_adjust': 'تعديل يدوي',
    'price_changed': 'تعديل السعر',
    'purchase': 'شراء',
    'sale': 'بيع',
    'sale_deleted': 'استرجاع (حذف فاتورة)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await DatabaseHelper.getInventoryAuditLogs(
        query: _searchController.text.isEmpty ? null : _searchController.text,
        actionType: _selectedActionType,
        ingredientId: _selectedIngredientId,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
      );
      final ingredients = await DatabaseHelper.getIngredients();
      if (mounted) {
        setState(() {
          _logs = results;
          _ingredients = ingredients;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تصفية السجل', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع الحركة'),
                value: _selectedActionType,
                items: _actionLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setSheetState(() => _selectedActionType = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'المادة'),
                value: _selectedIngredientId,
                items: _ingredients
                    .map((i) => DropdownMenuItem(
                        value: i['id'] as int,
                        child: Text(i['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setSheetState(() => _selectedIngredientId = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _FilterChip(
                    label: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : 'من تاريخ',
                    onPressed: () => _pickDate(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterChip(
                    label: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : 'إلى تاريخ',
                    onPressed: () => _pickDate(context, false),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedActionType = null;
                        _selectedIngredientId = null;
                        _dateFrom = null;
                        _dateTo = null;
                      });
                      setSheetState(() {});
                      _loadData();
                      Navigator.pop(context);
                    },
                    child: const Text('إعادة تعيين'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _loadData();
                      Navigator.pop(context);
                    },
                    child: const Text('تطبيق'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  Future<void> _printReport() async {
    await PdfHelper.printInventoryHistoryReport(_logs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل حركات المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تقرير PDF',
            onPressed: _logs.isEmpty ? null : _printReport,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو ملاحظة...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => _loadData(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.filter_list),
                tooltip: 'تصفية',
                onPressed: _showFilters,
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('لا توجد حركات مسجلة بعد'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final actionType = log['action_type'] as String;
                          final change = (log['quantity_change'] as num).toDouble();
                          final isPositive = change >= 0;
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Icon(
                                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isPositive ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              title: Text(
                                log['ingredient_name'] as String? ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'قبل: ${_fmt(log['quantity_before'])} ← بعد: ${_fmt(log['quantity_after'])} | السعر: ${_fmt(log['cost_price_at_action'])}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPositive ? '+' : ''}${_fmt(change)}',
                                    style: TextStyle(
                                      color: isPositive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _actionLabels[actionType] ?? actionType,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
          // Timeline summary footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(children: [
              Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('آخر تحديث: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              const Spacer(),
              Text('${_logs.length} حركة', style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic v) => v == null ? '0' : NumberFormat('#,##0.####').format(v);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _FilterChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }
}
