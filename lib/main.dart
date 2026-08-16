import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/auth/login_screen.dart';
import 'core/services/crash_logger.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(CrashLogger.record(
        details.exception,
        details.stack ?? StackTrace.current,
      ));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(CrashLogger.record(error, stack));
      return true;
    };

    // Allow portrait and landscape so POS/KDS can use tablets and wide displays.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final appProvider = AppProvider();
    await appProvider.initDatabase();

    runApp(
      ChangeNotifierProvider(
        create: (_) => appProvider,
        child: const HotBurgerApp(),
      ),
    );
  }, (error, stack) {
    unawaited(CrashLogger.record(error, stack));
  });
}

class HotBurgerApp extends StatelessWidget {
  const HotBurgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hot Burger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeAnimationDuration: const Duration(milliseconds: 250),
      home: const LoginScreen(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      locale: const Locale('ar', 'SA'),
    );
  }
}
