import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restricted_app.dart';

class StorageService {
  static const _appsKey = 'restricted_apps';

  Future<List<RestrictedApp>> loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final today = _todayString();
    return list.map((e) {
      final app = RestrictedApp.fromMap(e as Map<String, dynamic>);
      if (app.lastAttemptDate != today) {
        return app.copyWith(dailyAttempts: 0, lastAttemptDate: today);
      }
      return app;
    }).toList();
  }

  Future<void> saveApps(List<RestrictedApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(apps.map((a) => a.toMap()).toList());
    await prefs.setString(_appsKey, data);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
