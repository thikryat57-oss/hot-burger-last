import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'debug_status.dart';

class CrashLogger {
  CrashLogger._();

  static const _fileName = 'app_crash_log.txt';

  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<void> checkpoint(String name) async {
    updateDebugStatus(name);
    unawaited(_writeCheckpointToDisk(name));
  }

  static Future<void> _writeCheckpointToDisk(String name) async {
    try {
      final file = await _file();
      await file.writeAsString(
        '[checkpoint] $name - ${DateTime.now()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Breadcrumb logging must never affect the sale flow.
    }
  }

  static Future<void> record(Object error, StackTrace stackTrace) async {
    try {
      final file = await _file();
      final timestamp = DateTime.now().toIso8601String();
      final entry = '\n[$timestamp]\n$error\n$stackTrace\n${'-' * 80}\n';
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (_) {
      // Crash logging must never introduce a second application error.
    }
  }

  static Future<String> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return 'لا توجد أخطاء مسجلة.';
      final content = await file.readAsString();
      return content.trim().isEmpty ? 'لا توجد أخطاء مسجلة.' : content;
    } catch (error) {
      return 'تعذر قراءة سجل الأخطاء: $error';
    }
  }

  static Future<String?> path() async {
    try {
      return (await _file()).path;
    } catch (_) {
      return null;
    }
  }
}
