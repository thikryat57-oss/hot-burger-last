import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final appProvider = context.read<AppProvider>();
    final expenses = await appProvider.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  void _showAddExpenseDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final notesController = TextEditingController();
    final appProvider = context.read<AppProvider>();

    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مصروف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'اسم المصروف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(hintText: 'القيمة'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: InputDecoration(
                  hintText: 'التاريخ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(hintText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || amountController.text.isEmpty) return;
              await appProvider.addExpense(Expense(
                name: nameController.text,
                amount: double.tryParse(amountController.text) ?? 0,
                date: dateController.text,
                notes: notesController.text.isEmpty ? null : notesController.text,
              ));
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                });
                _loadExpenses();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditExpenseDialog(Expense expense) {
    final nameController = TextEditingController(text: expense.name);
    final amountController = TextEditingController(text: expense.amount.toString());
    final dateController = TextEditingController(text: expense.date);
    final notesController = TextEditingController(text: expense.notes ?? '');
    final appProvider = context.read<AppProvider>();

    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل المصروف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'اسم المصروف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(hintText: 'القيمة'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: InputDecoration(
                  hintText: 'التاريخ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(hintText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || amountController.text.isEmpty) return;
              await appProvider.updateExpense(Expense(
                id: expense.id,
                name: nameController.text,
                amount: double.tryParse(amountController.text) ?? 0,
                date: dateController.text,
                notes: notesController.text.isEmpty ? null : notesController.text,
              ));
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                });
                _loadExpenses();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final appProvider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text('هل أنت متأكد من حذف "${expense.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await appProvider.deleteExpense(expense.id!);
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصروفات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Total expenses card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.money_off, color: AppTheme.warningColor),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'إجمالي المصروفات',
                                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          Text(
                            '${_expenses.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)} ج.س',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Expenses list
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off, size: 80, color: AppTheme.textHint),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مصروفات',
                                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // السطر العلوي: اسم المصروف + التاريخ
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppTheme.warningColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.receipt_long, color: AppTheme.warningColor, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            expense.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            expense.date,
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // السطر السفلي: المبلغ + أيقونتي تعديل/حذف
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${expense.amount.toStringAsFixed(2)} ج.س',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.warningColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: Icon(Icons.edit, color: AppTheme.textSecondary, size: 18),
                                              onPressed: () => _showEditExpenseDialog(expense),
                                              tooltip: 'تعديل',
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                                              onPressed: () => _deleteExpense(expense),
                                              tooltip: 'حذف',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
