import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final users = await context.read<AppProvider>().getActiveUsers();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  Future<void> _addUser() async {
    final name = TextEditingController();
    final password = TextEditingController();
    String role = 'cashier';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: const Text('إضافة مستخدم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
          const SizedBox(height: 10),
          TextField(controller: password, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رمز الدخول'), obscureText: true),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(labelText: 'الصلاحية'),
            items: const [
              DropdownMenuItem(value: 'manager', child: Text('مدير')),
              DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
            ],
            onChanged: (v) => setDialog(() => role = v ?? 'cashier'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (result != true || !mounted) return;
    try {
      await context.read<AppProvider>().addUser(name: name.text, password: password.text, role: role);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _changePassword(User user) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغيير رمز ${user.name}'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'رمز الدخول الجديد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحديث')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      await context.read<AppProvider>().updateUserPassword(user.id!, controller.text);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    if (!p.canManageUsers()) return const Scaffold(body: Center(child: Text('هذه الصفحة متاحة للمدير فقط')));
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون والصلاحيات'), actions: [
        IconButton(onPressed: _addUser, icon: const Icon(Icons.person_add_alt_1_rounded), tooltip: 'إضافة مستخدم'),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _users.length,
          itemBuilder: (_, i) {
            final user = _users[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(user.role == 'manager' ? Icons.admin_panel_settings : Icons.point_of_sale)),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(user.role == 'manager' ? 'مدير • صلاحيات كاملة' : 'كاشير • المبيعات والورديات'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'password') await _changePassword(user);
                    if (v == 'disable') {
                      try { await p.setUserActive(user.id!, false); await _load(); }
                      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'password', child: Text('تغيير رمز الدخول')),
                    PopupMenuItem(value: 'disable', child: Text('تعطيل المستخدم')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addUser, icon: const Icon(Icons.person_add), label: const Text('مستخدم جديد')),
    );
  }
}
