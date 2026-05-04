import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _headingKey = 'settings_heading';
  static const _subtitleKey = 'settings_subtitle';
  static const _showAttemptsKey = 'settings_show_attempts';
  static const _showLogoKey = 'settings_show_logo';
  static const _showNameKey = 'settings_show_name';
  static const _countdownStyleKey = 'settings_countdown_style';
  static const _showCountdownNumbersKey = 'settings_show_countdown_numbers';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final styleIndex = prefs.getInt(_countdownStyleKey) ?? 0;
    return AppSettings(
      heading: prefs.getString(_headingKey) ?? AppSettings.defaultHeading,
      subtitle: prefs.getString(_subtitleKey) ?? AppSettings.defaultSubtitle,
      showAttemptCount: prefs.getBool(_showAttemptsKey) ?? true,
      showAppLogo: prefs.getBool(_showLogoKey) ?? true,
      showAppName: prefs.getBool(_showNameKey) ?? true,
      countdownStyle: CountdownStyle.values[styleIndex.clamp(0, CountdownStyle.values.length - 1)],
      showCountdownNumbers: prefs.getBool(_showCountdownNumbersKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_headingKey, settings.heading);
    await prefs.setString(_subtitleKey, settings.subtitle);
    await prefs.setBool(_showAttemptsKey, settings.showAttemptCount);
    await prefs.setBool(_showLogoKey, settings.showAppLogo);
    await prefs.setBool(_showNameKey, settings.showAppName);
    await prefs.setInt(_countdownStyleKey, settings.countdownStyle.index);
    await prefs.setBool(_showCountdownNumbersKey, settings.showCountdownNumbers);
  }
}
