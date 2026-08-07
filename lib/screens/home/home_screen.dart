import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../sales/sales_screen.dart';
import '../invoices/invoices_screen.dart';
import '../products/products_screen.dart';
import '../categories/categories_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/reports_screen.dart';
import '../backup/backup_screen.dart';
import '../inventory/inventory_screen.dart';
import '../more/more_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final screens = [
          const DashboardScreen(),
          const SalesScreen(),
          const InvoicesScreen(),
          const ProductsScreen(),
          const CategoriesScreen(),
          const InventoryScreen(),
          const ExpensesScreen(),
          const ReportsScreen(),
          const MoreScreen(),
        ];

        return Scaffold(
          body: screens[appProvider.currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: appProvider.currentIndex,
            onTap: (index) => appProvider.setIndex(index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'لوحة الأعمال',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale),
                label: 'المبيعات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'الفواتير',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fastfood),
                label: 'المنتجات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.category),
                label: 'التصنيفات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2),
                label: 'المخزون',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.money_off),
                label: 'المصروفات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'التقارير',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz),
                label: 'المزيد',
              ),
            ],
          ),
        );
      },
    );
  }
}
