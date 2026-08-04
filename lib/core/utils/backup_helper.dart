import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class BackupHelper {
  /// Export database to backup file and return the file path
  static Future<String> exportDatabase() async {
    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);

    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/hot_burger_backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${backupDir.path}/hot_burger_backup_$timestamp.db');
    await dbFile.copy(backupFile.path);

    return backupFile.path;
  }

  /// Share the exported backup file
  static Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  /// Export and share in one step
  static Future<void> exportAndShare() async {
    final path = await exportDatabase();
    await shareBackup(path);
  }

  /// Get all available backup files
  static Future<List<File>> getBackupFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/hot_burger_backups');

    if (!await backupDir.exists()) return [];

    final files = await backupDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Import a backup file and replace the current database
  static Future<void> importDatabase(String backupFilePath) async {
    await DatabaseHelper.closeDatabase();

    final dbPath = await DatabaseHelper.getDatabasePath();
    await File(backupFilePath).copy(dbPath);
  }

  /// Get the current database file size
  static Future<int> getDatabaseSize() async {
    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      return (await dbFile.stat()).size;
    }
    return 0;
  }
}
