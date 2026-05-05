import 'package:flutter/services.dart';

class AppService {
  static const _ch = MethodChannel('com.gratify/app_monitor');

  static Future<bool> checkAccessibilityPermission() async =>
      await _ch.invokeMethod<bool>('checkAccessibilityPermission') ?? false;

  static Future<bool> checkOverlayPermission() async =>
      await _ch.invokeMethod<bool>('checkOverlayPermission') ?? false;

  static Future<void> requestAccessibilityPermission() =>
      _ch.invokeMethod('requestAccessibilityPermission');

  static Future<void> requestOverlayPermission() =>
      _ch.invokeMethod('requestOverlayPermission');

  static Future<List<Map<String, String>>> getInstalledApps() async {
    final raw = await _ch.invokeMethod<List>('getInstalledApps');
    return raw?.map((e) => Map<String, String>.from(e as Map)).toList() ?? [];
  }

  static Future<void> startMonitoring() => _ch.invokeMethod('startMonitoring');

  static Future<void> stopMonitoring() => _ch.invokeMethod('stopMonitoring');

  static Future<bool> isMonitoringActive() async =>
      await _ch.invokeMethod<bool>('isMonitoringActive') ?? false;

  static Future<Uint8List?> getAppIcon(String packageName) async =>
      await _ch.invokeMethod<Uint8List>('getAppIcon', {'packageName': packageName});

  static Future<void> openApp() => _ch.invokeMethod('openApp');

  static Future<void> goHome() => _ch.invokeMethod('goHome');

  static Future<void> recordAccessGranted(String packageName) =>
      _ch.invokeMethod('recordAccessGranted', {'packageName': packageName});

  static Future<void> previewReminder(String appName, int intervalSeconds) =>
      _ch.invokeMethod('previewReminder', {
        'appName': appName,
        'intervalSeconds': intervalSeconds,
      });

  static void setOnAppOpened(
    void Function(String packageName, String appName, int delaySeconds) handler,
  ) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onAppOpened') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        handler(
          args['packageName'] as String,
          args['appName'] as String,
          args['delaySeconds'] as int,
        );
      }
    });
  }
}
