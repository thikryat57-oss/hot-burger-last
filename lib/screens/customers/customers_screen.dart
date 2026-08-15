import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  Future<void> _addCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('عميل جديد'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم العميل', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 10),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            try {
              await context.read<AppProvider>().addCustomer(name: name.text, phone: phone.text, email: email.text);
              if (c.mounted) Navigator.pop(c, true);
            } catch (e) {
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
            }
          }, child: const Text('حفظ')),
        ],
      ),
    );
    name.dispose(); phone.dispose(); email.dispose();
    if (result == true && mounted) setState(() {});
  }

  Future<void> _showCustomer(Customer customer) async {
    final purchases = await context.read<AppProvider>().getCustomerPurchases(customer.id!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * .72, child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(customer.phone ?? 'بدون رقم هاتف', style: const TextStyle(color: AppTheme.textSecondary)),
            ])),
            Chip(label: Text('${customer.points} نقطة')),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _stat('الزيارات', '${customer.visitCount}')),
            const SizedBox(width: 10),
            Expanded(child: _stat('إجمالي الإنفاق', '${customer.totalSpent.toStringAsFixed(0)} ج.س')),
          ]),
          const SizedBox(height: 18),
          const Text('آخر المشتريات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(child: purchases.isEmpty ? const Center(child: Text('لا توجد مشتريات مسجلة')) : ListView.separated(
            itemCount: purchases.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = purchases[i];
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(p['invoice_number'].toString()),
                subtitle: Text(p['created_at'].toString().replaceFirst('T', ' ')),
                trailing: Text('${(p['total_amount'] as num).toStringAsFixed(0)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800)),
              );
            },
          )),
        ]),
      )),
    );
  }

  Widget _stat(String label, String value) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ])),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء والولاء'), actions: [
        IconButton(onPressed: _addCustomer, tooltip: 'إضافة عميل', icon: const Icon(Icons.person_add_alt_1)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          decoration: const InputDecoration(hintText: 'ابحث بالاسم أو الهاتف', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v),
        )),
        Expanded(child: FutureBuilder<List<Customer>>(
          future: context.read<AppProvider>().getCustomers(query: _query),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final customers = snapshot.data ?? [];
            if (customers.isEmpty) return const Center(child: Text('لا يوجد عملاء'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = customers[i];
                return Card(child: ListTile(
                  onTap: () => _showCustomer(c),
                  leading: CircleAvatar(child: Text(c.name.trim().isEmpty ? '?' : c.name.trim()[0])),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(c.phone ?? 'بدون رقم هاتف'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${c.points} نقطة', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${c.visitCount} زيارة', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ]),
                ));
              },
            );
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addCustomer, icon: const Icon(Icons.person_add_alt_1), label: const Text('عميل جديد')),
    );
  }
}
