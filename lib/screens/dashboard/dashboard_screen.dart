import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_screen.dart';

enum DashboardPeriod { today, yesterday, thisWeek, thisMonth, custom }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.today;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _topSold = [];
  List<Map<String, dynamic>> _topProfit = [];
  List<Map<String, dynamic>> _expensesByCategory = [];
  int _lowStockCount = 0;
  bool _isLoading = false;

  final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning from another screen (e.g., after a sale or purchase)
    _loadAll();
  }

  Map<String, DateTime> _getRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case DashboardPeriod.today:
        return {'start': today, 'end': now};
      case DashboardPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return {'start': y, 'end': y.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
      case DashboardPeriod.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return {'start': start, 'end': now};
      case DashboardPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return {'start': start, 'end': now};
      case DashboardPeriod.custom:
        final start = DateTime(_customStart.year, _customStart.month, _customStart.day);
        final end = DateTime(_customEnd.year, _customEnd.month, _customEnd.day)
            .add(const Duration(hours: 23, minutes: 59, seconds: 59));
        return {'start': start, 'end': end};
    }
  }

  Future<void> _loadAll() async {
    final appProvider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    final range = _getRange();
    final start = range['start']!;
    final end = range['end']!;

    // 1. P&L (single query bundle: revenue, COGS from cost_snapshot, expenses)
    final summary = await appProvider.getProfitAndLossSummary(startDate: start, endDate: end);

    // 2. Daily sales series (one grouped query, grouped by DATE(created_at))
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final dailyResult = await appProvider.rawQuery(
      'SELECT DATE(created_at) as d, COALESCE(SUM(total_amount),0) as total, COUNT(*) as count '
      'FROM invoices WHERE DATE(created_at) BETWEEN ? AND ? GROUP BY DATE(created_at) ORDER BY d ASC',
      [startStr, endStr],
    );
    final dailySales = dailyResult
        .map((e) => <String, dynamic>{
              'date': e['d'] as String,
              'total': (e['total'] is num) ? (e['total'] as num).toDouble() : 0.0,
              'count': (e['count'] is num) ? e['count'] as int : 0,
            })
        .toList();

    // 3. Top 5 best-selling products (by quantity sold)
    final topSoldResult = await appProvider.rawQuery(
      'SELECT product_name, SUM(quantity) as qty, COALESCE(SUM(total),0) as total '
      'FROM invoice_items WHERE DATE(created_at) BETWEEN ? AND ? '
      'GROUP BY product_id ORDER BY qty DESC LIMIT 5',
      [startStr, endStr],
    );
    final topSold = topSoldResult.map((e) => <String, dynamic>{
          'name': e['product_name'] as String,
          'qty': (e['qty'] is num) ? (e['qty'] as num).toDouble() : 0.0,
          'total': (e['total'] is num) ? (e['total'] as num).toDouble() : 0.0,
        }).toList();

    // 4. Top 5 most profitable products (from saved total_profit)
    final topProfitResult = await appProvider.rawQuery(
      'SELECT product_name, SUM(quantity) as qty, COALESCE(SUM(total_profit),0) as profit '
      'FROM invoice_items WHERE DATE(created_at) BETWEEN ? AND ? '
      'GROUP BY product_id ORDER BY profit DESC LIMIT 5',
      [startStr, endStr],
    );
    final topProfit = topProfitResult.map((e) => <String, dynamic>{
          'name': e['product_name'] as String,
          'qty': (e['qty'] is num) ? (e['qty'] as num).toDouble() : 0.0,
          'profit': (e['profit'] is num) ? (e['profit'] as num).toDouble() : 0.0,
        }).toList();

    // 5. Expenses by category (uses the product/category name embedded in expense.name)
    final expenses = await appProvider.getExpenses();
    final byCat = <String, double>{};
    for (final exp in expenses) {
      final d = DateTime.tryParse(exp.date);
      if (d != null && d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)))) {
        byCat[exp.name] = (byCat[exp.name] ?? 0) + exp.amount;
      }
    }
    final expensesByCategory = byCat.entries
        .map((e) => <String, dynamic>{'name': e.key, 'amount': e.value})
        .toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // 6. Low stock count (reuse existing min_quantity logic)
    final lowStock = await appProvider.getLowStockIngredients();

    if (mounted) {
      setState(() {
        _summary = summary;
        _dailySales = dailySales;
        _topSold = topSold;
        _topProfit = topProfit;
        _expensesByCategory = expensesByCategory;
        _lowStockCount = lowStock.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
        } else {
          _customEnd = picked;
        }
      });
      _loadAll();
    }
  }

  String _periodLabel() {
    switch (_period) {
      case DashboardPeriod.today:
        return 'اليوم';
      case DashboardPeriod.yesterday:
        return 'أمس';
      case DashboardPeriod.thisWeek:
        return 'هذا الأسبوع';
      case DashboardPeriod.thisMonth:
        return 'هذا الشهر';
      case DashboardPeriod.custom:
        return 'مخصص';
    }
  }

  String _periodText() {
    final fmt = DateFormat('yyyy/MM/dd');
    final range = _getRange();
    final start = range['start']!;
    final end = range['end']!;
    if (start == end) return fmt.format(start);
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }

  void _setPeriod(DashboardPeriod p) {
    setState(() => _period = p);
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الأعمال'),
      ),
      body: Column(
        children: [
          // Period filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.today, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip(DashboardPeriod.today, 'اليوم'),
                        _buildChip(DashboardPeriod.yesterday, 'أمس'),
                        _buildChip(DashboardPeriod.thisWeek, 'الأسبوع'),
                        _buildChip(DashboardPeriod.thisMonth, 'الشهر'),
                        _buildChip(DashboardPeriod.custom, 'مخصص'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_period == DashboardPeriod.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: _buildSmallBox('من', DateFormat('yyyy/MM/dd').format(_customStart)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: _buildSmallBox('إلى', DateFormat('yyyy/MM/dd').format(_customEnd)),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text('الفترة: ${_periodText()}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _loadAll, child: _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(DashboardPeriod p, String label) {
    final selected = _period == p;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setPeriod(p),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildSmallBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final double grossProfit = (_summary['grossProfit'] ?? 0).toDouble();
    final Color profitColor = grossProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ===== KPI cards =====
        Row(
          children: [
            Expanded(
              child: _buildKpi('المبيعات', _summary['totalRevenue'] ?? 0, Icons.point_of_sale, AppTheme.primaryColor, suffix: ' ج.س'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi('تكلفة المبيعات', _summary['cogs'] ?? 0, Icons.production_quantity_limits, Colors.red.shade700, suffix: ' ج.س'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpi('إجمالي الربح', grossProfit, Icons.savings, profitColor, suffix: ' ج.س'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi('المصروفات', _summary['totalExpenses'] ?? 0, Icons.money_off, Colors.purple.shade700, suffix: ' ج.س'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildKpiFull('صافي الربح', grossProfit - ((_summary['totalExpenses'] ?? 0) as num).toDouble(), profitColor),
        const SizedBox(height: 14),

        // ===== Stock alert =====
        _buildStockCard(),
        const SizedBox(height: 14),

        // ===== Daily sales =====
        _buildDailySalesCard(),
        const SizedBox(height: 14),

        // ===== Top sold =====
        _buildTopCard('المنتجات الأكثر مبيعًا', _topSold, 'qty', 'total', 'حبة', Colors.blue.shade700, Icons.emoji_events),
        const SizedBox(height: 14),

        // ===== Top profit =====
        _buildTopCard('المنتجات الأكثر ربحية', _topProfit, 'qty', 'profit', 'حبة', AppTheme.successColor, Icons.trending_up),
        const SizedBox(height: 14),

        // ===== Expenses =====
        _buildExpensesCard(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildKpi(String title, num value, IconData icon, Color color, {String suffix = ''}) {
    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(
              '${_fmt.format(value.toDouble())}$suffix',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiFull(String title, double value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(color == AppTheme.errorColor ? Icons.money_off : Icons.account_balance_wallet, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text(
                    '${_fmt.format(value)} ج.س',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard() {
    final hasLowStock = _lowStockCount > 0;
    final color = hasLowStock ? AppTheme.warningColor : AppTheme.successColor;
    return Card(
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryScreen()),
          ).then((_) => _loadAll());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(hasLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حالة المخزون', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      hasLowStock ? 'مواد تحتاج إلى شراء: $_lowStockCount' : 'لا توجد مواد تحتاج إلى شراء حاليًا',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ),
              Icon(Icons.inventory_2, color: AppTheme.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySalesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المبيعات اليومية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_dailySales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(child: Text('لا توجد مبيعات في هذه الفترة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              )
            else
              Column(
                children: [
                  // Simple horizontal bar list (no extra chart library)
                  ..._dailySales.map((d) {
                    final max = _dailySales.map((e) => e['total'] as double).reduce((a, b) => a > b ? a : b);
                    final ratio = max > 0 ? (d['total'] as double) / max : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('MM/dd').format(DateTime.parse('${d['date']}T00:00:00')),
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                Text('${d['count']} فاتورة', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: MediaQuery.of(context).size.width * 0.55 * ratio,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('${_fmt.format(d['total'])} ج.س', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(String title, List<Map<String, dynamic>> items, String qtyKey, String valueKey, String unit, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('لا توجد منتجات مباعة في هذه الفترة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              )
            else
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.textHint.withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: color.withOpacity(0.12),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('${item[qtyKey].toStringAsFixed(0)} $unit', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        '${_fmt.format(item[valueKey] as double)} ج.س',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard() {
    final totalExpenses = ((_summary['totalExpenses'] ?? 0) as num).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.money_off, size: 18, color: Colors.purple),
                const SizedBox(width: 6),
                const Text('المصروفات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_fmt.format(totalExpenses)} ج.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 10),
            if (_expensesByCategory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('لا توجد مصروفات في هذه الفترة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              )
            else
              ..._expensesByCategory.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(c['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                      Text('${_fmt.format(c['amount'])} ج.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
