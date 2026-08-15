import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';

class BusinessIntelligenceScreen extends StatefulWidget {
  const BusinessIntelligenceScreen({super.key});
  @override
  State<BusinessIntelligenceScreen> createState() => _BusinessIntelligenceScreenState();
}

class _BusinessIntelligenceScreenState extends State<BusinessIntelligenceScreen> {
  DateTime _start = DateTime.now(), _end = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;
  final _money = NumberFormat('#,##0.00');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppProvider>().getBusinessIntelligence(
        start: DateTime(_start.year, _start.month, _start.day),
        end: DateTime(_end.year, _end.month, _end.day),
      );
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context, initialDate: start ? _start : _end,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) { _start = picked; if (_start.isAfter(_end)) _end = picked; }
      else { _end = picked; if (_end.isBefore(_start)) _start = picked; }
    });
    _load();
  }

  String _fmt(num n) => _money.format(n);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الذكاء التجاري'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث')],
      ),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _periodCard(), const SizedBox(height: 12),
                  if (_data != null) ...[
                    _kpiGrid(), const SizedBox(height: 12),
                    _profitCard(), const SizedBox(height: 12),
                    _paymentsCard(), const SizedBox(height: 12),
                    _hoursCard(), const SizedBox(height: 12),
                    _customersCard(), const SizedBox(height: 12),
                    _stockCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _periodCard() => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Expanded(child: _dateButton('من', _start, () => _pick(true))),
      const SizedBox(width: 8),
      Expanded(child: _dateButton('إلى', _end, () => _pick(false))),
    ])),
  );

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) => OutlinedButton(
    onPressed: onTap,
    child: Row(children: [
      const Icon(Icons.calendar_today, size: 17), const SizedBox(width: 7),
      Expanded(child: Text('$label ${DateFormat('yyyy/MM/dd').format(date)}', overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _kpiGrid() {
    final d = _data!;
    final items = <Map<String, dynamic>>[
      {'t':'المبيعات','v':_fmt(d['sales']),'i':Icons.point_of_sale,'c':AppTheme.primaryColor},
      {'t':'متوسط الفاتورة','v':_fmt(d['averageTicket']),'i':Icons.receipt_long,'c':Colors.blue},
      {'t':'صافي الربح','v':_fmt(d['netProfit']),'i':Icons.trending_up,'c':AppTheme.successColor},
      {'t':'هامش الربح','v':'${(d['margin'] as num).toStringAsFixed(1)}%','i':Icons.percent,'c':Colors.orange},
      {'t':'الفواتير','v':'${d['invoices']}','i':Icons.receipt,'c':Colors.purple},
      {'t':'الخصومات','v':_fmt(d['discounts']),'i':Icons.local_offer,'c':Colors.redAccent},
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.65,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final x = items[i];
        return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(x['i'] as IconData, color: x['c'] as Color, size: 22),
            const Spacer(),
            Text(x['v'].toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: x['c'] as Color), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(x['t'].toString(), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        )));
      },
    );
  }

  Widget _section(String title, IconData icon, Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 19, color: AppTheme.primaryColor), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 14), child,
      ],
    )),
  );

  Widget _profitCard() => _section('الربحية', Icons.insights, Column(children: [
    _line('إجمالي الربح قبل المصروفات', _fmt(_data!['grossProfit']), AppTheme.successColor),
    _line('المصروفات التشغيلية', _fmt(_data!['expenses']), Colors.orange),
    const Divider(),
    _line('صافي الربح', _fmt(_data!['netProfit']), (_data!['netProfit'] as num) >= 0 ? AppTheme.successColor : AppTheme.errorColor),
  ]));

  Widget _line(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(label)), Text('$value ج.س', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
    ]),
  );

  Widget _paymentsCard() {
    final list = (_data!['payment'] as List).cast<Map<String, dynamic>>();
    final total = list.fold<double>(0, (a, x) => a + (x['amount'] as num).toDouble());
    return _section('توزيع طرق الدفع', Icons.payments_outlined, Column(
      children: list.map((x) {
        final amount = (x['amount'] as num).toDouble();
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: [
          Row(children: [Expanded(child: Text(x['name'].toString())), Text('${_fmt(amount)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 8, value: total == 0 ? 0 : amount / total)),
        ]));
      }).toList(),
    ));
  }

  Widget _hoursCard() {
    final list = (_data!['hourly'] as List).cast<Map<String, dynamic>>().take(6).toList();
    return _section('أفضل ساعات البيع', Icons.schedule, list.isEmpty
      ? const Center(child: Text('لا توجد مبيعات في الفترة'))
      : Column(children: list.asMap().entries.map((e) {
          final x = e.value, hour = (x['hour'] as num).toInt();
          return ListTile(
            dense: true, leading: CircleAvatar(radius: 15, child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12))),
            title: Text('${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00'),
            subtitle: Text('${x['orders']} فاتورة'),
            trailing: Text('${_fmt((x['sales'] as num).toDouble())} ج.س', style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }).toList()));
  }

  Widget _customersCard() {
    final list = (_data!['customers'] as List).cast<Map<String, dynamic>>();
    return _section('أفضل العملاء', Icons.star_outline, list.isEmpty
      ? const Center(child: Text('لا توجد مشتريات مرتبطة بعملاء'))
      : Column(children: list.asMap().entries.map((e) {
          final x = e.value;
          return ListTile(
            dense: true, leading: CircleAvatar(radius: 16, child: Text('${e.key + 1}')),
            title: Text(x['name']?.toString() ?? 'عميل'), subtitle: Text('${x['visits']} زيارة'),
            trailing: Text('${_fmt((x['spent'] as num).toDouble())} ج.س', style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }).toList()));
  }

  Widget _stockCard() {
    final list = (_data!['lowStock'] as List).cast<Map<String, dynamic>>();
    return _section('تنبيهات المخزون', Icons.warning_amber_rounded, list.isEmpty
      ? const Row(children: [Icon(Icons.check_circle, color: AppTheme.successColor), SizedBox(width: 8), Text('المخزون ضمن الحدود الآمنة')])
      : Column(children: list.map((x) => ListTile(
          dense: true, leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
          title: Text(x['name'].toString()),
          subtitle: Text('المتاح: ${(x['quantity'] as num).toStringAsFixed(2)} ${x['unit']}'),
          trailing: Text('الحد ${(x['min_quantity'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent)),
        )).toList()));
  }
}
