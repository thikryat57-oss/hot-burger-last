import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_provider.dart';

class KitchenDisplayScreen extends StatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  Timer? _timer;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final orders = await context.read<AppProvider>().getKitchenOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _orders;
    return _orders.where((o) => o['kitchen_status'] == _filter).toList();
  }

  Future<void> _setStatus(int id, String status) async {
    try {
      await context.read<AppProvider>().updateKitchenStatus(id, status);
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new': return 'جديد';
      case 'preparing': return 'قيد التحضير';
      case 'ready': return 'جاهز';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return AppTheme.warningColor;
      case 'preparing': return AppTheme.infoColor;
      case 'ready': return AppTheme.successColor;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'new': return Icons.notifications_active_outlined;
      case 'preparing': return Icons.soup_kitchen_outlined;
      case 'ready': return Icons.check_circle_outline;
      default: return Icons.done_all;
    }
  }

  String _nextStatus(String status) {
    switch (status) {
      case 'new': return 'preparing';
      case 'preparing': return 'ready';
      case 'ready': return 'delivered';
      default: return '';
    }
  }

  String _nextLabel(String status) {
    switch (status) {
      case 'new': return 'بدء التحضير';
      case 'preparing': return 'جاهز';
      case 'ready': return 'تسليم';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_rounded),
            SizedBox(width: 8),
            Text('شاشة المطبخ'),
          ],
        ),
        actions: [
          IconButton(onPressed: () => _load(), tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 180),
                          Icon(Icons.restaurant_menu_rounded, size: 72, color: AppTheme.textSecondary),
                          SizedBox(height: 14),
                          Center(child: Text('لا توجد طلبات قيد التحضير', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                          SizedBox(height: 8),
                          Center(child: Text('ستظهر الطلبات الجديدة هنا تلقائيًا', style: TextStyle(color: AppTheme.textSecondary))),
                        ])
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1200 ? 4 : constraints.maxWidth >= 800 ? 3 : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.all(14),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: columns == 1 ? 1.55 : 0.82,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _ticket(visible[i]),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final counts = <String, int>{'new': 0, 'preparing': 0, 'ready': 0};
    for (final order in _orders) {
      final status = order['kitchen_status']?.toString() ?? 'new';
      if (counts.containsKey(status)) counts[status] = counts[status]! + 1;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('الكل', 'all', _orders.length),
            _filterChip('جديد', 'new', counts['new']!),
            _filterChip('قيد التحضير', 'preparing', counts['preparing']!),
            _filterChip('جاهز', 'ready', counts['ready']!),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, int count) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        selected: selected,
        label: Text('$label  $count'),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _ticket(Map<String, dynamic> order) {
    final status = order['kitchen_status']?.toString() ?? 'new';
    final color = _statusColor(status);
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final created = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final age = created == null ? '' : _age(created);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: color.withOpacity(0.25))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(_statusIcon(status), color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${order['invoice_number']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('$age • ${_statusLabel(status)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                      if ((order['customer_name']?.toString() ?? '').isNotEmpty)
                        Text('العميل: ${order['customer_name']}', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
                    ],
                  ),
                ),
                Text('${order['item_count'] ?? items.length} صنف', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (_, i) {
                final item = items[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${item['quantity']}', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item['product_name']?.toString() ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_nextStatus(status).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _setStatus(order['id'] as int, _nextStatus(status)),
                  icon: Icon(_nextStatus(status) == 'delivered' ? Icons.done_all : Icons.arrow_back_rounded),
                  label: Text(_nextLabel(status)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _age(DateTime created) {
    final minutes = DateTime.now().difference(created).inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes د';
    final hours = minutes ~/ 60;
    return 'منذ $hours س';
  }
}
