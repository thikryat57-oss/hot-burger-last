import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../backup/backup_screen.dart';
import '../categories/categories_screen.dart';
import '../expenses/expenses_screen.dart';
import '../auth/login_screen.dart';
import '../products/products_screen.dart';
import '../purchases/purchases_list_screen.dart';
import '../reports/profit_report_screen.dart';
import '../reports/reports_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../shifts/shift_management_screen.dart';
import '../users/user_management_screen.dart';
import '../kitchen_display_screen.dart';
import '../customers/customers_screen.dart';
import '../analytics/business_intelligence_screen.dart';
import 'package:provider/provider.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإدارة'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _sectionTitle('إدارة التشغيل'),
          const SizedBox(height: 10),
          _buildGrid(context, [
            _MenuItem('شاشة المطبخ', 'متابعة الطلبات: جديد، تحضير، جاهز، تسليم', Icons.restaurant_rounded, AppTheme.accentColor, const KitchenDisplayScreen()),
            _MenuItem('العملاء والولاء', 'سجل العملاء، المشتريات ونقاط الولاء', Icons.card_membership_rounded, AppTheme.successColor, const CustomersScreen()),
            if (context.read<AppProvider>().canManageUsers()) _MenuItem('المستخدمون', 'إدارة المديرين والكاشير والصلاحيات', Icons.manage_accounts_outlined, AppTheme.infoColor, const UserManagementScreen()),
            if (context.read<AppProvider>().canManageCatalog()) _MenuItem('المنتجات', 'إدارة قائمة الطعام والأسعار', Icons.fastfood_outlined, AppTheme.primaryColor, const ProductsScreen()),
            if (context.read<AppProvider>().canManageCatalog()) _MenuItem('التصنيفات', 'تنظيم المنتجات داخل أقسام', Icons.category_outlined, AppTheme.infoColor, const CategoriesScreen()),
            if (context.read<AppProvider>().canManageFinance()) _MenuItem('المصروفات', 'تسجيل ومراجعة المصروفات', Icons.account_balance_wallet_outlined, AppTheme.warningColor, const ExpensesScreen()),
            if (context.read<AppProvider>().canManageCatalog()) _MenuItem('الوصفات', 'اختر المنتج لإدارة وربط مكونات الوصفة', Icons.receipt_long_outlined, AppTheme.successColor, const ProductsScreen()),
          ]),
          const SizedBox(height: 22),
          _sectionTitle('المشتريات والموردون'),
          const SizedBox(height: 10),
          _buildGrid(context, [
            _MenuItem('الورديات والصندوق', 'فتح وإغلاق ورديات الكاشير ومطابقة النقد', Icons.lock_clock_outlined, AppTheme.warningColor, const ShiftManagementScreen()),
            if (context.read<AppProvider>().canManageCatalog()) _MenuItem('الموردون', 'بيانات الموردين والأرصدة', Icons.people_alt_outlined, AppTheme.infoColor, const SuppliersScreen()),
            if (context.read<AppProvider>().canManageCatalog()) _MenuItem('المشتريات', 'فواتير شراء المواد الخام', Icons.shopping_cart_outlined, AppTheme.accentColor, const PurchasesListScreen()),
          ]),
          const SizedBox(height: 22),
          _sectionTitle('التقارير والبيانات'),
          const SizedBox(height: 10),
          _buildGrid(context, [
            if (context.read<AppProvider>().canManageFinance()) _MenuItem('الذكاء التجاري', 'مؤشرات الربح والعملاء وطرق الدفع وساعات الذروة', Icons.insights_rounded, AppTheme.primaryColor, const BusinessIntelligenceScreen()),
            if (context.read<AppProvider>().canManageFinance()) _MenuItem('التقارير', 'مبيعات يومية وشهرية', Icons.bar_chart_rounded, AppTheme.infoColor, const ReportsScreen()),
            if (context.read<AppProvider>().canManageFinance()) _MenuItem('الأرباح والخسائر', 'تحليل الأداء المالي', Icons.trending_up_rounded, AppTheme.successColor, const ProfitReportScreen()),
            if (context.read<AppProvider>().canManageFinance()) _MenuItem('النسخ الاحتياطي', 'حماية واستعادة بيانات النظام', Icons.backup_outlined, AppTheme.primaryColor, const BackupScreen()),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(17)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مركز الإدارة', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(user?.name ?? 'مدير النظام', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary));

  Widget _buildGrid(BuildContext context, List<_MenuItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (_, index) => _buildMenuCard(context, items[index]),
        );
      },
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuItem item) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.screen)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(item.icon, color: item.color, size: 23),
              ),
              const Spacer(),
              Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد إنهاء جلسة العمل الحالية؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (shouldLogout == true && context.mounted) {
      context.read<AppProvider>().logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _MenuItem(this.title, this.subtitle, this.icon, this.color, this.screen);
}
