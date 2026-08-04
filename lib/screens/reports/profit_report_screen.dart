import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';

enum DateFilter { today, thisWeek, thisMonth, custom }

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  DateFilter _filter = DateFilter.today;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  late final Map<String, dynamic> Function(DateTime?, DateTime?) _getDateRange;

  @override
  void initState() {
    super.initState();
    _getDateRange = _getRangeForFilter(_filter);
    _loadSummary();
  }

  Map<String, dynamic> Function(DateTime?, DateTime?) _getRangeForFilter(DateFilter f) {
    final now = DateTime.now();
    switch (f) {
      case DateFilter.today:
        return (_, __) => {'start': now, 'end': now};
      case DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (_, __) => {'start': start, 'end': now};
      case DateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (_, __) => {'start': start, 'end': now};
      case DateFilter.custom:
        return (start, end) => {'start': start ?? now, 'end': end ?? now};
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final range = _getRangeForFilter(_filter)(_customStart, _customEnd);
    final start = range['start'] as DateTime;
    final end = range['end'] as DateTime;
    final summary = await appProvider.getProfitAndLossSummary(startDate: start, endDate: end);
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
        } else {
          _customEnd = picked;
        }
      });
      _loadSummary();
    }
  }

  String _filterLabel() {
    switch (_filter) {
      case DateFilter.today:
        return 'اليوم';
      case DateFilter.thisWeek:
        return 'هذا الأسبوع';
      case DateFilter.thisMonth:
        return 'هذا الشهر';
      case DateFilter.custom:
        return 'مخصص';
    }
  }

  String _periodText() {
    final fmt = DateFormat('yyyy/MM/dd');
    final range = _getRangeForFilter(_filter)(_customStart, _customEnd);
    final start = range['start'] as DateTime;
    final end = range['end'] as DateTime;
    if (start == end) return fmt.format(start);
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرباح والخسائر'),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(DateFilter.today, 'اليوم'),
                        _buildFilterChip(DateFilter.thisWeek, 'الأسبوع'),
                        _buildFilterChip(DateFilter.thisMonth, 'الشهر'),
                        _buildFilterChip(DateFilter.custom, 'مخصص'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom date range
          if (_filter == DateFilter.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('من', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(DateFormat('yyyy/MM/dd').format(_customStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إلى', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(DateFormat('yyyy/MM/dd').format(_customEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Period label
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Text(
              'الفترة: $_periodText()',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),

          // Summary
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Revenue Card
                      Card(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.trending_up, color: AppTheme.primaryColor, size: 30),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('إجمالي الإيرادات', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    Text(
                                      '${fmt.format(_summary['totalRevenue'] ?? 0)} ج.س',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // COGS Card
                      Card(
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.production_quantity_limits, color: Colors.red.shade700, size: 30),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('تكلفة المبيعات (COGS)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    Text(
                                      '${fmt.format(_summary['cogs'] ?? 0)} ج.س',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Gross Profit Card
                      Card(
                        color: ((_summary['grossProfit'] ?? 0) as num >= 0)
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.errorColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: ((_summary['grossProfit'] ?? 0) as num >= 0)
                                ? AppTheme.successColor.withOpacity(0.3)
                                : AppTheme.errorColor.withOpacity(0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                ((_summary['grossProfit'] ?? 0) as num >= 0) ? Icons.savings : Icons.money_off,
                                color: ((_summary['grossProfit'] ?? 0) as num >= 0) ? AppTheme.successColor : AppTheme.errorColor,
                                size: 30,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('صافي الأرباح', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    Text(
                                      '${fmt.format(_summary['grossProfit'] ?? 0)} ج.س',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: ((_summary['grossProfit'] ?? 0) as num >= 0) ? AppTheme.successColor : AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Profit Margin Card
                      Card(
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.percent, color: Colors.orange.shade700, size: 30),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('هامش الربح', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    Text(
                                      '${fmt.format(_summary['profitMargin'] ?? 0)}%',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(DateFilter value, String label) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textSecondary)),
        selected: isSelected,
        selectedColor: AppTheme.primaryColor,
        backgroundColor: AppTheme.cardBackground,
        onSelected: (selected) {
          if (selected) {
            setState(() => _filter = value);
            _loadSummary();
          }
        },
      ),
    );
  }
}
