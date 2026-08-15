import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  Shift? _shift;
  Map<String, dynamic>? _summary;
  List<Shift> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = context.read<AppProvider>();
    final shift = await p.getCurrentUserOpenShift();
    final history = await p.getShifts();
    Map<String, dynamic>? summary;
    if (shift != null) summary = await p.getCurrentShiftCashSummary();
    if (!mounted) return;
    setState(() {
      _shift = shift;
      _summary = summary;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _openShift() async {
    final controller = TextEditingController(text: '0');
    final notes = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فتح وردية جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي للصندوق'),
          ),
          const SizedBox(height: 12),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('فتح الوردية')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      final cash = double.tryParse(controller.text.replaceAll(',', '.')) ?? -1;
      if (cash < 0) throw Exception('الرصيد الافتتاحي غير صالح');
      await context.read<AppProvider>().openShift(cash, notes: notes.text.trim().isEmpty ? null : notes.text.trim());
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _closeShift() async {
    final controller = TextEditingController(text: ((_summary?['expectedCash'] as double?) ?? 0).toStringAsFixed(2));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الوردية'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('النقد المتوقع: ${((_summary?['expectedCash'] as double?) ?? 0).toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'النقد الفعلي في الصندوق'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إغلاق الوردية')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      final cash = double.tryParse(controller.text.replaceAll(',', '.')) ?? -1;
      if (cash < 0) throw Exception('النقد الفعلي غير صالح');
      await context.read<AppProvider>().closeShift(cash);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الوردية بنجاح'), backgroundColor: AppTheme.successColor));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الورديات والصندوق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildCurrentCard(p),
                  const SizedBox(height: 22),
                  const Text('سجل الورديات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد ورديات مسجلة بعد'))))
                  else
                    ..._history.map(_buildHistoryCard),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentCard(AppProvider p) {
    if (_shift == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_clock_rounded, size: 36, color: AppTheme.warningColor),
            const SizedBox(height: 12),
            const Text('لا توجد وردية مفتوحة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('افتح وردية قبل تسجيل المبيعات حتى يتم احتساب صندوق الكاشير بدقة.'),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _openShift, icon: const Icon(Icons.play_arrow_rounded), label: const Text('فتح وردية')),
          ]),
        ),
      );
    }
    final expected = (_summary?['expectedCash'] as double?) ?? 0;
    final sales = (_summary?['cashSales'] as double?) ?? 0;
    final expenses = (_summary?['expenses'] as double?) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_open_rounded, color: AppTheme.successColor),
            const SizedBox(width: 8),
            const Text('الوردية الحالية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const Spacer(),
            Chip(label: Text(_shift!.userName)),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _metric('افتتاحي', _shift!.openingCash),
            _metric('مبيعات كاش', sales),
            _metric('مصروفات', expenses),
            _metric('متوقع', expected),
          ]),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _closeShift,
            icon: const Icon(Icons.lock_rounded),
            label: const Text('إغلاق الوردية ومطابقة الصندوق'),
          ),
        ]),
      ),
    );
  }

  Widget _metric(String label, double value) => Expanded(
    child: Column(children: [
      Text(value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]),
  );

  Widget _buildHistoryCard(Shift s) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(s.status == 'open' ? Icons.lock_open : Icons.lock)),
      title: Text('${s.userName} • ${s.status == 'open' ? 'مفتوحة' : 'مغلقة'}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('فتح: ${s.openedAt.substring(0, 16).replaceFirst('T', ' ')}${s.closedAt == null ? '' : '\nإغلاق: ${s.closedAt!.substring(0, 16).replaceFirst('T', ' ')}'}'),
      trailing: s.difference == null ? null : Text('${s.difference! >= 0 ? '+' : ''}${s.difference!.toStringAsFixed(2)}'),
    ),
  );
}
