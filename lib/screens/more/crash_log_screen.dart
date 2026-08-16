import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/crash_logger.dart';
import '../../core/theme/app_theme.dart';

class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  String _content = 'جاري تحميل سجل الأخطاء...';
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    final content = await CrashLogger.read();
    final path = await CrashLogger.path();
    if (!mounted) return;
    setState(() {
      _content = content;
      _filePath = path;
    });
  }

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ سجل الأخطاء')),
    );
  }

  Future<void> _shareLog() async {
    final path = _filePath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد ملف أخطاء لمشاركته')),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'سجل أخطاء تطبيق Hot Burger',
      text: 'سجل أخطاء تطبيق Hot Burger',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأخطاء'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLog,
          ),
          IconButton(
            tooltip: 'نسخ',
            icon: const Icon(Icons.copy),
            onPressed: _copyLog,
          ),
          IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.share),
            onPressed: _shareLog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.04),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}
