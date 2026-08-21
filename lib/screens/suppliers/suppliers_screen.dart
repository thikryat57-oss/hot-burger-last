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
	                          title: Row(
                                children: [
                                  Expanded(child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  if (!supplier.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('غير نشط', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
                                    ),
                                ],
                              ),
	                          subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(supplier.phone ?? 'لا يوجد رقم'),
                                  if (supplier.taxNumber != null && supplier.taxNumber!.isNotEmpty)
                                    Text('ضريبي: ${supplier.taxNumber}', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
	                          trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
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
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showSupplierDialog(context, supplier: supplier),
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
        onPressed: () => _showSupplierDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, {Supplier? supplier}) {
    final nameController = TextEditingController(text: supplier?.name);
    final phoneController = TextEditingController(text: supplier?.phone);
    final addressController = TextEditingController(text: supplier?.address);
    final notesController = TextEditingController(text: supplier?.notes);
    final taxController = TextEditingController(text: supplier?.taxNumber);

    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'إضافة مورد جديد' : 'تعديل مورد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المورد *'),
                autofocus: supplier == null,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
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
              
              final newSupplier = Supplier(
                id: supplier?.id,
                name: nameController.text,
                phone: phoneController.text,
                address: addressController.text,
                notes: notesController.text,
                taxNumber: taxController.text,
                balance: supplier?.balance ?? 0,
                isActive: supplier?.isActive ?? true,
              );
              
              if (supplier == null) {
                await context.read<AppProvider>().addSupplier(newSupplier);
              } else {
                await context.read<AppProvider>().updateSupplier(newSupplier);
              }
              
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
