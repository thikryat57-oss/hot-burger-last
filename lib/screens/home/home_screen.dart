import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../invoices/invoices_screen.dart';
import '../inventory/inventory_screen.dart';
import '../more/more_screen.dart';
import '../sales/sales_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<Widget> _screens;
  late final ValueNotifier<bool> _dashboardActive;
  late final ValueNotifier<bool> _invoicesActive;
  late final ValueNotifier<bool> _inventoryActive;

  @override
  void initState() {
    super.initState();
    _dashboardActive = ValueNotifier(false);
    _invoicesActive = ValueNotifier(false);
    _inventoryActive = ValueNotifier(false);
    _screens = [
      const SalesScreen(),
      InvoicesScreen(activeListenable: _invoicesActive),
      DashboardScreen(activeListenable: _dashboardActive),
      InventoryScreen(activeListenable: _inventoryActive),
      const MoreScreen(),
    ];
  }

  @override
  void dispose() {
    _dashboardActive.dispose();
    _invoicesActive.dispose();
    _inventoryActive.dispose();
    super.dispose();
  }

  void _setIndex(AppProvider appProvider, int index) {
    _dashboardActive.value = index == 2;
    _invoicesActive.value = index == 1;
    _inventoryActive.value = index == 3;
    appProvider.setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.select<AppProvider, int>((p) => p.currentIndex);
    final index = currentIndex.clamp(0, _screens.length - 1);
    final appProvider = context.read<AppProvider>();
    if (_dashboardActive.value != (index == 2)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dashboardActive.value = index == 2;
          _invoicesActive.value = index == 1;
          _inventoryActive.value = index == 3;
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(index: index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        elevation: 3,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: (value) => _setIndex(appProvider, value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'المبيعات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'الفواتير',
          ),
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المخزون',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'المزيد',
          ),
        ],
      ),
      floatingActionButton: index == 2
          ? FloatingActionButton.extended(
              onPressed: () => _setIndex(appProvider, 0),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('بيع جديد', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
