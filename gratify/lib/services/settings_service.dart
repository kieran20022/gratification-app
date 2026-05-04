import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _headingKey             = 'settings_heading';
  static const _subtitleKey            = 'settings_subtitle';
  static const _showAttemptsKey        = 'settings_show_attempts';
  static const _showLogoKey            = 'settings_show_logo';
  static const _showNameKey            = 'settings_show_name';
  static const _showHeadingKey         = 'settings_show_heading';
  static const _showSubtitleKey        = 'settings_show_subtitle';
  static const _countdownStyleKey      = 'settings_countdown_style';
  static const _showCountdownNumbersKey = 'settings_show_countdown_numbers';
  static const _showBreathTextKey      = 'settings_show_breath_text';
  static const _fsAppNameKey           = 'settings_fs_app_name';
  static const _fsAttemptCountKey      = 'settings_fs_attempt_count';
  static const _fsHeadingKey           = 'settings_fs_heading';
  static const _fsSubtitleKey          = 'settings_fs_subtitle';
  static const _fsTimerNumberKey       = 'settings_fs_timer_number';
  static const _fsTimerLabelKey        = 'settings_fs_timer_label';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final styleIndex = prefs.getInt(_countdownStyleKey) ?? 0;
    return AppSettings(
      heading:           prefs.getString(_headingKey) ?? AppSettings.defaultHeading,
      subtitle:          prefs.getString(_subtitleKey) ?? AppSettings.defaultSubtitle,
      showAttemptCount:  prefs.getBool(_showAttemptsKey) ?? true,
      showAppLogo:       prefs.getBool(_showLogoKey) ?? true,
      showAppName:       prefs.getBool(_showNameKey) ?? true,
      showHeading:       prefs.getBool(_showHeadingKey) ?? true,
      showSubtitle:      prefs.getBool(_showSubtitleKey) ?? true,
      countdownStyle:    CountdownStyle.values[styleIndex.clamp(0, CountdownStyle.values.length - 1)],
      showCountdownNumbers: prefs.getBool(_showCountdownNumbersKey) ?? true,
      showBreathText:    prefs.getBool(_showBreathTextKey) ?? true,
      fontSizeAppName:      prefs.getDouble(_fsAppNameKey)      ?? AppSettings.defaultFontSizeAppName,
      fontSizeAttemptCount: prefs.getDouble(_fsAttemptCountKey) ?? AppSettings.defaultFontSizeAttemptCount,
      fontSizeHeading:      prefs.getDouble(_fsHeadingKey)      ?? AppSettings.defaultFontSizeHeading,
      fontSizeSubtitle:     prefs.getDouble(_fsSubtitleKey)     ?? AppSettings.defaultFontSizeSubtitle,
      fontSizeTimerNumber:  prefs.getDouble(_fsTimerNumberKey)  ?? AppSettings.defaultFontSizeTimerNumber,
      fontSizeTimerLabel:   prefs.getDouble(_fsTimerLabelKey)   ?? AppSettings.defaultFontSizeTimerLabel,
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_headingKey, s.heading);
    await prefs.setString(_subtitleKey, s.subtitle);
    await prefs.setBool(_showAttemptsKey, s.showAttemptCount);
    await prefs.setBool(_showLogoKey, s.showAppLogo);
    await prefs.setBool(_showNameKey, s.showAppName);
    await prefs.setBool(_showHeadingKey, s.showHeading);
    await prefs.setBool(_showSubtitleKey, s.showSubtitle);
    await prefs.setInt(_countdownStyleKey, s.countdownStyle.index);
    await prefs.setBool(_showCountdownNumbersKey, s.showCountdownNumbers);
    await prefs.setBool(_showBreathTextKey, s.showBreathText);
    await prefs.setDouble(_fsAppNameKey, s.fontSizeAppName);
    await prefs.setDouble(_fsAttemptCountKey, s.fontSizeAttemptCount);
    await prefs.setDouble(_fsHeadingKey, s.fontSizeHeading);
    await prefs.setDouble(_fsSubtitleKey, s.fontSizeSubtitle);
    await prefs.setDouble(_fsTimerNumberKey, s.fontSizeTimerNumber);
    await prefs.setDouble(_fsTimerLabelKey, s.fontSizeTimerLabel);
  }
}
