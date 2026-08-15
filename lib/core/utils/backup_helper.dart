import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class BackupHelper {
  /// Create a consistent SQLite snapshot. The WAL is checkpointed before copying.
  static Future<String> exportDatabase() async {
    final db = await DatabaseHelper.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('قاعدة البيانات غير موجودة');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/hot_burger_backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${backupDir.path}/hot_burger_backup_$timestamp.db');
    await dbFile.copy(backupFile.path);

    // Basic SQLite signature validation prevents sharing an incomplete file.
    final raf = await backupFile.open();
    try {
      final header = await raf.read(16);
      final signature = String.fromCharCodes(header);
      if (!signature.startsWith('SQLite format 3')) {
        await backupFile.delete();
        throw Exception('تعذر التحقق من سلامة النسخة الاحتياطية');
      }
    } finally {
      await raf.close();
    }

    return backupFile.path;
  }

  static Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  static Future<void> exportAndShare() async {
    final path = await exportDatabase();
    await shareBackup(path);
  }

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

  /// Import safely: validate first, preserve a rollback copy, then reopen the DB.
  static Future<void> importDatabase(String backupFilePath) async {
    final source = File(backupFilePath);
    if (!await source.exists()) throw Exception('ملف النسخة الاحتياطية غير موجود');

    final raf = await source.open();
    try {
      final header = await raf.read(16);
      if (!String.fromCharCodes(header).startsWith('SQLite format 3')) {
        throw Exception('ملف النسخة الاحتياطية غير صالح');
      }
    } finally {
      await raf.close();
    }

    final dbPath = await DatabaseHelper.getDatabasePath();
    final current = File(dbPath);
    final rollback = File('$dbPath.before_restore');
    if (await current.exists()) {
      await current.copy(rollback.path);
    }

    final temp = File('$dbPath.restore_tmp');
    if (await temp.exists()) await temp.delete();
    await source.copy(temp.path);

    try {
      await DatabaseHelper.closeDatabase();
      await temp.rename(dbPath);
      // Reopen immediately so schema/migration errors surface now, not later.
      await DatabaseHelper.database;
      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      if (await rollback.exists()) {
        if (await current.exists()) await current.delete();
        await rollback.rename(dbPath);
      }
      await DatabaseHelper.closeDatabase();
      rethrow;
    }
  }

  static Future<int> getDatabaseSize() async {
    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);
    return await dbFile.exists() ? (await dbFile.stat()).size : 0;
  }
}
