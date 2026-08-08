import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'profit_report_screen.dart';
import '../dashboard/dashboard_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _monthlyReport;
  bool _isLoadingDaily = false;
  bool _isLoadingMonthly = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDailyReport();
    _loadMonthlyReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyReport() async {
    final appProvider = context.read<AppProvider>();
    setState(() => _isLoadingDaily = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final report = await appProvider.getDailyReport(dateStr);
    if (mounted) {
      setState(() {
        _dailyReport = report;
        _isLoadingDaily = false;
      });
    }
  }

  Future<void> _loadMonthlyReport() async {
    final appProvider = context.read<AppProvider>();
    setState(() => _isLoadingMonthly = true);
    final report = await appProvider.getMonthlyReport(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    if (mounted) {
      setState(() {
        _monthlyReport = report;
        _isLoadingMonthly = false;
      });
    }
  }

  Widget _buildReportCard(String title, Map<String, dynamic>? report, Color color, bool isLoading) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (report == null)
              const Center(child: Text('لا توجد بيانات'))
            else
              Column(
                children: [
                  _buildReportRow('إجمالي المبيعات', '${report['totalSales'].toStringAsFixed(2)} ج.س', color),
                  const Divider(height: 24),
                  _buildReportRow('عدد الفواتير', '${report['invoiceCount']}', color),
                  const Divider(height: 24),
                  _buildReportRow('إجمالي المصروفات', '${report['totalExpenses'].toStringAsFixed(2)} ج.س', AppTheme.warningColor),
                  const Divider(height: 24),
                  _buildReportRow(
                    'صافي الربح',
                    '${report['netProfit'].toStringAsFixed(2)} ج.س',
                    (report['netProfit'] as num) >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
            tooltip: 'لوحة الأعمال',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitReportScreen()),
              );
            },
            tooltip: 'الأرباح والخسائر',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'يومي'),
            Tab(text: 'شهري'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Daily Report
          Column(
            children: [
              // Date picker
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadDailyReport();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          const Text('التاريخ:'),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy/MM/dd').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildReportCard(
                    'تقرير يوم ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                    _dailyReport,
                    AppTheme.primaryColor,
                    _isLoadingDaily,
                  ),
                ),
              ),
            ],
          ),

          // Monthly Report
          Column(
            children: [
              // Month picker
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                surface: AppTheme.cardBackground,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedMonth = picked);
                        _loadMonthlyReport();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          const Text('الشهر:'),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy/MM').format(_selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildReportCard(
                    'تقرير شهر ${DateFormat('yyyy/MM').format(_selectedMonth)}',
                    _monthlyReport,
                    AppTheme.primaryColor,
                    _isLoadingMonthly,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
