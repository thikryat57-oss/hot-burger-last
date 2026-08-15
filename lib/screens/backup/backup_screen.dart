import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/utils/backup_helper.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export button
          Card(
            color: AppTheme.successColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.successColor.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppTheme.successColor, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تصدير نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('حفظ ومشاركة قاعدة البيانات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _exportDatabase(context),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('تصدير ومشاركة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Import button
          Card(
            color: AppTheme.warningColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.warningColor.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download_outlined, color: AppTheme.warningColor, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('استعادة نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('استبدال البيانات الحالية بنسخة سابقة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _importDatabase(context),
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('استعادة نسخة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info
          Card(
            color: AppTheme.backgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يتم حفظ النسخ الاحتياطية محلياً في مجلد التطبيق. يمكنك مشاركتها أو نقلها لأي جهاز آخر.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _exportDatabase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await BackupHelper.exportDatabase();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('تم تصدير النسخة الاحتياطية بنجاح'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'مشاركة',
              textColor: Colors.white,
              onPressed: () => BackupHelper.shareBackup(path),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  static Future<void> _importDatabase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await BackupHelper.getBackupFiles();
      if (files.isEmpty) {
        if (context.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('لا توجد نسخ احتياطية'), backgroundColor: AppTheme.warningColor));
        }
        return;
      }

      if (!context.mounted) return;
      final selected = await showDialog<File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اختر نسخة احتياطية'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final name = f.path.split('/').last;
                return ListTile(
                  title: Text(name),
                  subtitle: Text('${f.lengthSync()} bytes', style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
        ),
      );

      if (selected == null || !context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تحذير'),
          content: const Text('سيتم استبدال جميع البيانات الحالية. هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      await BackupHelper.importDatabase(selected.path);
      final provider = context.read<AppProvider>();
      await provider.initDatabase();

      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('تم استعادة النسخة بنجاح'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }
}
