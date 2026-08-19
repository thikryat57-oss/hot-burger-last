import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../constants/constants.dart';

/// Result of a backup file validation (Phase 4.5.1 hardening).
///
/// A backup is accepted only when [isAcceptable] is true. [failureReason]
/// carries a human-readable explanation of the first failing check,
/// suitable for surfacing in the UI.
class BackupValidationResult {
  final bool isAcceptable;
  final String failureReason;
  final String filePath;

  const BackupValidationResult._(
    this.isAcceptable,
    this.filePath, {
    this.failureReason = '',
  });

  factory BackupValidationResult.accepted(String filePath) =>
      BackupValidationResult._(true, filePath);

  factory BackupValidationResult.rejected(String filePath, String reason) =>
      BackupValidationResult._(false, filePath, failureReason: reason);

  @override
  String toString() =>
      isAcceptable ? 'accepted' : 'rejected: $failureReason';
}

class BackupHelper {
  /// Key HOT BURGER schema tables that identify a backup as belonging to
  /// this application (data-identity check, Phase 4.5.1).
  // Phase 4.5.1 identity tables — chosen from the PRODUCTION schema:
  // users/categories/products/raw_materials exist in the v1 baseline and are
  // touched by every normal app session; invoices/invoice_items carry the
  // relational structure a random SQLite file is extremely unlikely to
  // reproduce. NOTE: there is NO 'settings' table in the HOT BURGER schema
  // (verified against database_helper.dart line-by-line).
  static const List<String> kIdentityTables = [
    'users',
    'categories',
    'products',
    'raw_materials',
    'invoices',
    'invoice_items',
  ];

  /// Operational event action_types written to invoice_audit_log with the
  /// reserved invoice_id = 0 (AUTOINCREMENT guarantees no real invoice has
  /// id 0). Part of the backup/restore audit trail (Phase 4.5.1).
  static const String kBackupActionType = 'backup_exported';
  static const String kRestoreActionType = 'restore_performed';
  static const String kRestoreFailureActionType = 'restore_failed';
  static const int kOperationalEventInvoiceId = 0;

  /// Test-only failure injection (Phase 4.5.1 atomicity proof).
  /// When true, importDatabase throws a StateError AFTER the production
  /// database has been swapped — proving the rollback copy is required and
  /// that post-restore verification controls rollback deletion.
  static bool _testFailAfterSwap = false;
  static void setTestRestoreFailureAfterSwap(bool value) {
    _testFailAfterSwap = value;
  }

  /// Create a consistent SQLite snapshot. The WAL is checkpointed before copying.
    static Future<String> exportDatabase() async {
    final db = await DatabaseHelper.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('قاعدة البيانات غير موجودة');
    }
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // Human-readable filename (Phase 4.5.1): hot_burger_backup_YYYY-MM-DD_HH-mm-ss.db
    // Older epoch-based files remain compatible (Phase 4.5.1 backward
    // compatibility) — the picker parses both formats.
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    File backupFile = File('${backupDir.path}/hot_burger_backup_$stamp.db');

    // Avoid overwriting a file created within the same second
    // (same filename → different data → ambiguous restoration).
    int suffix = 1;
    while (await backupFile.exists()) {
      backupFile = File('${backupDir.path}/hot_burger_backup_${stamp}_$suffix.db');
      suffix += 1;
    }
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

    // Phase 4.5.1 audit trail: record the export in the operational event
    // area of invoice_audit_log (reserved invoice_id = 0). Failure to log
    // the event does not block the export itself.
    await _logOperationalEvent(kBackupActionType,
        reason: 'filename=${backupFile.path.split('/').last}');

    return backupFile.path;
  }

  static Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  static Future<void> exportAndShare() async {
    final path = await exportDatabase();
    await shareBackup(path);
  }

  /// Lists *.db files in the backup directory, newest first. Accepts both
  /// the new human-readable format (hot_burger_backup_YYYY-MM-DD_HH-mm-ss.db)
  /// and the legacy epoch format (hot_burger_backup_<milliseconds>.db) so
  /// existing backups on devices remain selectable (Phase 4.5.1 backward
  /// compatibility).
  static Future<List<File>> getBackupFiles() async {
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) return [];

    final files = await backupDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Resolves the backup storage directory. Production uses the application
  /// documents directory (getApplicationDocumentsDirectory). Tests inject a
  /// plain temp directory via [setTestBackupDirectory] because
  /// path_provider's platform channel is unavailable in plain unit tests
  /// (Phase 4.5.1 testability hook — never called in production).
  static Future<Directory> _getBackupDirectory() async {
    if (_testBackupDirectory != null) return _testBackupDirectory!;
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/hot_burger_backups');
  }

  static Directory? _testBackupDirectory;

  /// Injects a test directory for the backup folder. Pass null to restore
  /// production behavior. Returns the previous value.
  static Directory? setTestBackupDirectory(Directory? directory) {
    final previous = _testBackupDirectory;
    _testBackupDirectory = directory;
    return previous;
  }

  /// Extracts a human-readable creation date from a backup filename.
  /// Returns null for filenames that match neither the new format nor the
  /// legacy epoch format (Phase 4.5.1).
  static DateTime? parseBackupDate(String filePath) {
    final name = filePath.split('/').last;
    final epochMatch = RegExp(r'^hot_burger_backup_(\d+)\.db$').firstMatch(name);
    if (epochMatch != null) {
      final ms = int.tryParse(epochMatch.group(1)!);
      if (ms != null) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    final readableMatch = RegExp(
      r'^hot_burger_backup_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})(?:_\d+)?\.db$',
    ).firstMatch(name);
    if (readableMatch == null) return null;
    final y = int.parse(readableMatch.group(1)!);
    final mo = int.parse(readableMatch.group(2)!);
    final d = int.parse(readableMatch.group(3)!);
    final h = int.parse(readableMatch.group(4)!);
    final mi = int.parse(readableMatch.group(5)!);
    final s = int.parse(readableMatch.group(6)!);
    try {
      return DateTime(y, mo, d, h, mi, s);
    } catch (_) {
      return null;
    }
  }

  /// Validates a candidate backup file WITHOUT touching the production
  /// database (Phase 4.5.1 pre-flight gate).
  ///
  /// Checks, in order:
  /// 1. File exists and is readable with a non-zero size.
  /// 2. SQLite header signature (`SQLite format 3`).
  /// 3. The file can be opened as a SQLite database and `PRAGMA
  ///    integrity_check` returns `ok`.
  /// 4. Schema identity: every key HOT BURGER table exists.
  /// 5. Data identity: at least one of the identity tables holds data
  ///    (a random empty SQLite database is not HOT BURGER data).
    /// 6. Application version identity: the backup's user_version must equal
  /// the production DB version — a backup created by a newer app release
  /// is rejected rather than downgrading silently.
  static Future<BackupValidationResult> validateBackupFile(String filePath) async {
    final source = File(filePath);
    if (!await source.exists()) {
      return BackupValidationResult.rejected(filePath, 'الملف غير موجود');
    }
    final stat = await source.stat();
    if (stat.size == 0) {
      return BackupValidationResult.rejected(filePath, 'الملف فارغ');
    }
    if (stat.size < 100) {
      return BackupValidationResult.rejected(filePath, 'حجم الملف أصغر من الحد الأدنى لملف SQLite');
    }

    final raf = await source.open();
    try {
      final header = await raf.read(16);
      if (!String.fromCharCodes(header).startsWith('SQLite format 3')) {
        return BackupValidationResult.rejected(filePath, 'التوقيع غير صالح: ليس ملف SQLite');
      }
    } finally {
      await raf.close();
    }

    Database? validationDb;
    try {
      // A backup is a byte-for-byte copy of a production database that was
      // opened with Constants.dbVersion, so its user_version header equals
      // dbVersion. The handle is opened readOnly (readOnly=true), which
      // means passing `version:` would make sqflite try to WRITE the
      // user_version pragma and fail with "attempt to write a readonly
      // database" whenever the header disagrees — so the header check is
      // performed by hand on the read-only handle instead. A version-0 or
      // mismatching header (never-migrated / newer-app backup) is rejected
      // explicitly rather than silently accepted.
      validationDb = await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
        ),
      );
      final uv = await validationDb.rawQuery('PRAGMA user_version');
      final userVersion = (uv.first['user_version'] ?? 0) as int;
      if (userVersion != Constants.dbVersion) {
        return BackupValidationResult.rejected(
          filePath,
          userVersion == 0
              ? 'النسخة الاحتياطية غير مهيأة (user_version=0)'
              : 'النسخة الاحتياطية من إصدار مختلف عن التطبيق (user_version=$userVersion)',
        );
      }

      final integrity = await validationDb.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        return BackupValidationResult.rejected(
            filePath, 'قاعدة البيانات تالفة (integrity_check فشل)');
      }

      for (final table in kIdentityTables) {
        final tables = await validationDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
        );
        if (tables.isEmpty) {
          return BackupValidationResult.rejected(
              filePath, 'هيكل قاعدة البيانات غير متطابق: جدول $table مفقود');
        }
      }

      final dataRows = await validationDb.rawQuery(
        'SELECT (SELECT COUNT(*) FROM users) + '
        '(SELECT COUNT(*) FROM categories) AS cnt',
      );
      if (dataRows.isEmpty || (dataRows.first['cnt'] ?? 0) == 0) {
        return BackupValidationResult.rejected(
            filePath, 'قاعدة البيانات لا تحتوي بيانات تطبيق صالحة');
      }

      // Version gating is already enforced above: the backup's
      // user_version must EQUAL the production dbVersion. A backup written
      // by a newer app release carries a higher user_version and is
      // rejected there with a mismatch reason; silently accepting it would
      // risk restoring data shaped by migrations this build does not know.
      return BackupValidationResult.accepted(filePath);
    } on Exception catch (e) {
      // OpenDatabaseOptions failure (e.g. file corrupt or not openable).
      return BackupValidationResult.rejected(filePath, 'تعذر فتح الملف كقاعدة بيانات SQLite: $e');
    } finally {
      await validationDb?.close();
    }
  }

  /// Records an operational event (backup/restore) in the reserved
  /// invoice_id = 0 area of invoice_audit_log (Phase 4.5.1 audit trail).
  /// Never throws — a logging failure must never block backup/restore.
  static Future<void> _logOperationalEvent(String actionType,
      {String? actorName, int? actorId, bool success = true, String? reason}) async {
    try {
      // invoice_id = 0 is a reserved sentinel that by design does not
      // reference any real invoice. The invoice_audit_log FK (ON DELETE
      // CASCADE) would therefore reject the insert on a normal connection
      // with foreign_keys ON — so the audit row is written through a
      // dedicated short-lived connection where the FK pragma is disabled
      // just for this operation. singleInstance:false guarantees no other
      // caller's pragma state is touched (Phase 4.5.1 audit trail).
      final dbPath = await DatabaseHelper.getDatabasePath();
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = OFF');
          },
        ),
      );
      try {
        await db.insert('invoice_audit_log', {
          'invoice_id': kOperationalEventInvoiceId,
          'action_type': actionType,
          'action_date': DateTime.now().toIso8601String(),
          'user_id': actorId,
          'user_name': actorName,
          'note': reason,
        });
      } finally {
        await db.close();
      }
    } catch (_) {
      // Deliberately ignored: audit trail must not break the operation.
    }
  }

  /// Import safely: validate first, preserve a rollback copy, swap,
  /// reopen, VERIFY, then (only after verified success) delete the
  /// rollback copy (Phase 4.5.1 hardening).
  ///
  /// The production database is NOT touched until validation passes.
  /// If anything fails after the swap, the rollback copy is restored.
  static Future<void> importDatabase(
    String backupFilePath, {
    String? actorName,
    int? actorId,
    String? confirmationText,
  }) async {
    // --- Pre-flight validation (no mutation before this point) ---
    final validation = await validateBackupFile(backupFilePath);
    if (!validation.isAcceptable) {
      // Failure before any mutation: production database untouched.
      await _logOperationalEvent(kRestoreFailureActionType,
          actorName: actorName,
          actorId: actorId,
          success: false,
          reason:
              'reason=${validation.failureReason};confirmation=$confirmationText');
      throw Exception('النسخة الاحتياطية مرفوضة: ${validation.failureReason}');
    }

    final dbPath = await DatabaseHelper.getDatabasePath();
    final current = File(dbPath);
    final rollback = File('$dbPath.before_restore');
    if (await current.exists()) {
      await current.copy(rollback.path);
    }

    final temp = File('$dbPath.restore_tmp');
    if (await temp.exists()) await temp.delete();
    if (_testFailCopy) {
      throw Exception('TEST: copy failure injected (pre-mutation)');
    }
    await File(backupFilePath).copy(temp.path);

    try {
      await DatabaseHelper.closeDatabase();
      await temp.rename(dbPath);
      // Reopen immediately so schema/migration errors surface now, not later.
      await DatabaseHelper.database;

      // --- Post-restore verification (Phase 4.5.1) ---
      // Integrity + schema identity on the NEW live database BEFORE the
      // rollback copy is discarded.
      // The swapped-in database must carry the production user_version.
      // readOnly=true, so the check is performed by hand (passing version: to
      // a readOnly handle makes sqflite attempt a write whenever the header
      // disagrees). A mismatched header is treated as a verification failure.
      final verificationDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
        ),
      );
      String? verificationFailure;
      try {
        final uv =
            await verificationDb.rawQuery('PRAGMA user_version');
        final uvValue = (uv.first['user_version'] ?? 0) as int;
        if (uvValue != Constants.dbVersion) {
          verificationFailure =
              'user_version المستعادة غير مطابق ($uvValue ≠ ${Constants.dbVersion})';
        } else {
          final integrity =
              await verificationDb.rawQuery('PRAGMA integrity_check');
          if (integrity.isEmpty ||
              integrity.first['integrity_check'] != 'ok') {
            verificationFailure =
                'integrity_check فشل على قاعدة البيانات المستعادة';
          } else {
            for (final table in kIdentityTables) {
              final tables = await verificationDb.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
              );
              if (tables.isEmpty) {
                verificationFailure =
                    'جدول $table مفقود في قاعدة البيانات المستعادة';
                break;
              }
            }
          }
        }
      } finally {
        await verificationDb.close();
      }

      if (verificationFailure != null) {
        // Verification failed while the live DB is bad → restore rollback.
        await _restoreFromRollback(dbPath, current, rollback);
        await _logOperationalEvent(kRestoreFailureActionType,
            actorName: actorName,
            actorId: actorId,
            success: false,
            reason:
                'reason=$verificationFailure;confirmation=$confirmationText');
        throw Exception('فشل التحقق من النسخة المستعادة: $verificationFailure');
      }

      // Phase 4.5.1 test hook: simulated late failure proves the rollback
      // copy is still available and deletion happens only after success.
      if (_testFailAfterSwap) {
        await _restoreFromRollback(dbPath, current, rollback);
        throw StateError('TEST: post-swap failure injected after swap');
      }

      // Only now that the restored database is verified does the rollback
      // copy get discarded (Phase 4.5.1: delayed rollback deletion).
      if (await rollback.exists()) await rollback.delete();

      // Audit trail: success recorded in the NEW (restored) database.
      await _logOperationalEvent(kRestoreActionType,
          actorName: actorName,
          actorId: actorId,
          success: true,
          reason: 'confirmation=$confirmationText');
    } catch (e) {
      if (await temp.exists()) await temp.delete();
      // Restore rollback for any other post-swap failure as well
      // (Phase 4.5.1 hardened catch-all).
      if (await rollback.exists()) {
        await _restoreFromRollback(dbPath, current, rollback);
      }
      await _logOperationalEvent(kRestoreFailureActionType,
          actorName: actorName,
          actorId: actorId,
          success: false,
          reason: 'reason=$e;confirmation=$confirmationText');
      await DatabaseHelper.closeDatabase();
      rethrow;
    }
  }

  static Future<void> _restoreFromRollback(
      String dbPath, File current, File rollback) async {
    if (await rollback.exists()) {
      if (await current.exists()) await current.delete();
      await rollback.rename(dbPath);
    }
  }

  /// Test-only copy failure injection (Phase 4.5.1 atomicity proof).
  /// When true, the temp copy step throws BEFORE any production mutation
  /// — proving the pre-flight gate keeps the live database untouched.
  static bool _testFailCopy = false;

  /// Test-only setter — production never uses it.
  static void setTestCopyFailure(bool value) {
    _testFailCopy = value;
  }

  static Future<int> getDatabaseSize() async {
    final dbPath = await DatabaseHelper.getDatabasePath();
    final dbFile = File(dbPath);
    return await dbFile.exists() ? (await dbFile.stat()).size : 0;
  }
}
