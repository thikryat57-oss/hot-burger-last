import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/utils/backup_helper.dart';
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

  static String _formatBackupInfo(File f) {
    // Phase 4.5.1: show a human-readable creation date when the filename
    // follows the new format (YYYY-MM-DD_HH-mm-ss) or the legacy epoch
    // format; fall back to the raw filename otherwise.
    final date = BackupHelper.parseBackupDate(f.path);
    final sizeMb = f.lengthSync() / (1024 * 1024);
    final size = '${sizeMb.toStringAsFixed(2)} ميغابايت';
    if (date != null) {
      final parts = [
        date.year.toString().padLeft(4, '0'),
        date.month.toString().padLeft(2, '0'),
        date.day.toString().padLeft(2, '0'),
      ];
      final time = [
        date.hour.toString().padLeft(2, '0'),
        date.minute.toString().padLeft(2, '0'),
      ];
      return '${parts.join('-')} ${time.join(':')} — $size';
    }
    return '${f.path.split('/').last} — $size';
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
      // File picker dialog: human-readable date + size per backup
      // (Phase 4.5.1, closes P3-F4).
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
                return ListTile(
                  title: Text(_formatBackupInfo(f)),
                  subtitle: Text(f.path.split('/').last,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
        ),
      );

      if (selected == null || !context.mounted) return;

      // Phase 4.5.1 typed confirmation (closes P2-F2): the operator must
      // type the exact string "RESTORE" — no trimming, no case folding.
      final confirmed = await _showTypedConfirmationDialog(context);
      if (confirmed != true || !context.mounted) return;

      final provider = context.read<AppProvider>();
      final user = provider.currentUser;

      // Pass the acting user so the audit trail row attributes the restore.
      await BackupHelper.importDatabase(
        selected.path,
        actorName: user?.name,
        actorId: user?.id,
        confirmationText: 'RESTORE',
      );

      // Post-restore state refresh (Phase 4.5.1, closes P3-F5): reopen the
      // database handle so all consumers (Dashboard, Invoices, ...) reload
      // their data from the restored database.
      await provider.initDatabase();
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم استعادة النسخة بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      // Phase 4.5.1: surface the validation rejection reason (failureReason)
      // when importDatabase rejects the file.
      String message = 'خطأ: $e';
      final m = RegExp(r'النسخة الاحتياطية مرفوضة: (.+)').firstMatch(e.toString());
      if (m != null) {
        message = 'النسخة الاحتياطية مرفوضة: ${m.group(1)}';
      }
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Typed-confirmation dialog (Phase 4.5.1): requires the exact string
  /// "RESTORE" before the restore proceeds. The confirm button stays
  /// disabled until the field matches exactly (no trim, case-sensitive).
  static Future<bool?> _showTypedConfirmationDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool enabled = false;
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تأكيد الاستعادة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تحذير: سيتم استبدال جميع البيانات الحالية بنسخة سابقة ولا يمكن التراجع يدوياً.',
                style: TextStyle(color: AppTheme.warningColor),
              ),
              const SizedBox(height: 14),
              const Text('اكتب كلمة RESTORE للمتابعة:'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'RESTORE',
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    // Exact match only: case-sensitive, no trimming.
                    enabled = value == 'RESTORE';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: enabled ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}
