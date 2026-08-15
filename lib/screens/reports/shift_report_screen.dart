import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';

class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final summary = await appProvider.getShiftSummary(startDate: _startDate, endDate: _endDate);
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير تقفيل الوردية'),
        actions: [
          if (!_isLoading && _summary.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => PdfHelper.printShiftReport(
                _summary,
                startDate: _startDate,
                endDate: _endDate,
              ),
              tooltip: 'طباعة التقرير',
            ),
        ],
      ),
      body: Column(
        children: [
          // Date range selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('من', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text(DateFormat('yyyy/MM/dd').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إلى', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text(DateFormat('yyyy/MM/dd').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _summary.isEmpty
                    ? const Center(child: Text('لا توجد بيانات لهذه الفترة', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Total Sales Card
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
                                  Icon(Icons.attach_money, color: AppTheme.primaryColor, size: 32),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('إجمالي المبيعات', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        Text(
                                          '${fmt.format(_summary['totalSales'] ?? 0)} ج.س',
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${_summary['invoiceCount']} فاتورة',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cash Card
                          Card(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(Icons.money, color: const Color(0xFF4CAF50), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('نقداً', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        Text(
                                          '${fmt.format(_summary['cashTotal'] ?? 0)} ج.س',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bank Card
                          Card(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: const Color(0xFF2196F3).withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance, color: const Color(0xFF2196F3), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('تحويل بنكي', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        Text(
                                          '${fmt.format(_summary['bankTotal'] ?? 0)} ج.س',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Card Payment Card
                          Card(
                            color: const Color(0xFF9C27B0).withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(Icons.credit_card, color: const Color(0xFF9C27B0), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('بطاقة', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        Text(
                                          '${fmt.format(_summary['cardTotal'] ?? 0)} ج.س',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0)),
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
      floatingActionButton: _isLoading || _summary.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => PdfHelper.printShiftReport(
                _summary,
                startDate: _startDate,
                endDate: _endDate,
              ),
              icon: const Icon(Icons.print),
              label: const Text('طباعة التقرير'),
            ),
    );
  }
}
