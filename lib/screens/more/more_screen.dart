import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../suppliers/suppliers_screen.dart';
import '../purchases/purchases_list_screen.dart';
import '../backup/backup_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المزيد'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMenuItem(
              context,
              title: 'الموردون',
              subtitle: 'إدارة بيانات الموردين وحساباتهم',
              icon: Icons.people_outline,
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              context,
              title: 'فواتير المشتريات',
              subtitle: 'تسجيل وإدارة فواتير شراء المواد الخام',
              icon: Icons.shopping_cart_outlined,
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesListScreen())),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              context,
              title: 'النسخ الاحتياطي',
              subtitle: 'تصدير واستعادة قاعدة البيانات',
              icon: Icons.backup_outlined,
              color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
