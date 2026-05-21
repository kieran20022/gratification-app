import 'package:flutter/material.dart';
import 'models/restricted_app.dart';
import 'screens/delay_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_service.dart';
import 'services/storage_service.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'dart:async';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize MCP Toolkit
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();

      // Your existing app initialization code here...
      runApp(const GratifyApp());
    },
    (error, stack) {
      // Handle zone errors for MCP
      MCPToolkitBinding.instance.handleZoneError(error, stack);

      // Your existing error handling...
    },
  );
}

class GratifyApp extends StatefulWidget {
  const GratifyApp({super.key});

  @override
  State<GratifyApp> createState() => _GratifyAppState();
}

class _GratifyAppState extends State<GratifyApp> {
  @override
  void initState() {
    super.initState();
    AppService.setOnAppOpened(
      (pkg, name, delay, fromSessionLimit) =>
          _handleAppOpened(pkg, name, delay, fromSessionLimit),
    );
  }

  Future<void> _handleAppOpened(
    String packageName,
    String appName,
    int delaySeconds,
    bool fromSessionLimit,
  ) async {
    final storage = StorageService();
    final apps = await storage.loadApps();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final index = apps.indexWhere((a) => a.packageName == packageName);
    late RestrictedApp app;
    if (index >= 0) {
      // Session-limit re-prompts don't count as new opens.
      final newCount = fromSessionLimit
          ? apps[index].dailyAttempts
          : apps[index].dailyAttempts + 1;
      app = apps[index].copyWith(
        dailyAttempts: newCount,
        lastAttemptDate: today,
      );
      apps[index] = app;
      await storage.saveApps(apps);
    } else {
      app = RestrictedApp(
        id: packageName,
        name: appName,
        packageName: packageName,
        delaySeconds: delaySeconds,
        dailyAttempts: fromSessionLimit ? 0 : 1,
        lastAttemptDate: today,
      );
    }

    final nav = _navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => DelayScreen(app: app, fromService: true),
        ),
      );
    } else {
      // Navigator isn't mounted yet (onAppOpened arrived before first frame).
      // Defer until after the frame so currentState is available.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DelayScreen(app: app, fromService: true),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gratify',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF7B6FD4),
              brightness: Brightness.light,
            ).copyWith(
              surface: const Color(0xFFF7F5FF),
              primary: const Color(0xFF7B6FD4),
              secondary: const Color(0xFF6BBFB5),
            ),
        scaffoldBackgroundColor: const Color(0xFFF7F5FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F5FF),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D2D3A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2D2D3A)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF7B6FD4),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF1E1C2E),
              primary: const Color(0xFF9B8AFF),
              secondary: const Color(0xFF6BBFB5),
            ),
        scaffoldBackgroundColor: const Color(0xFF12111A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF12111A),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFECEAFF),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFFECEAFF)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
