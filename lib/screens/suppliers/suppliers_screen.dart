import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _searchQuery = '';
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _suppliersFuture = context.read<AppProvider>().getSuppliers();
  }

  void _reloadSuppliers() {
    setState(() {
      _suppliersFuture = context.read<AppProvider>().getSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث عن مورد...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Supplier>>(
                future: _suppliersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final suppliers = snapshot.data ?? [];
                  final filtered = suppliers.where((s) => 
                    s.name.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('لا يوجد موردون'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final supplier = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(supplier.phone ?? 'لا يوجد رقم'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('الرصيد', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                '${supplier.balance.toStringAsFixed(2)} ج.س',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: supplier.balance > 0 ? AppTheme.errorColor : AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupplierDetailScreen(supplierId: supplier.id!),
                              ),
                            ).then((_) {
                              if (mounted) _reloadSuppliers();
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المورد *'),
                autofocus: true,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              final supplier = Supplier(
                name: nameController.text,
                phone: phoneController.text,
                address: addressController.text,
                notes: notesController.text,
              );
              
              await context.read<AppProvider>().addSupplier(supplier);
              if (context.mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                });
                _reloadSuppliers();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
