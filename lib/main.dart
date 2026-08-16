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
import 'core/services/debug_status.dart';

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: IgnorePointer(
                child: ValueListenableBuilder<String>(
                  valueListenable: debugStatus,
                  builder: (context, status, _) => Align(
                    alignment: Alignment.bottomCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'DEBUG: $status',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
