import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_settings.dart';

class ReminderSettingsService {
  // Keys stored without 'flutter.' prefix — shared_preferences adds it
  // automatically, so the Kotlin side reads them as 'flutter.reminder_*'.
  static const _msgKey         = 'reminder_message';
  static const _animKey        = 'reminder_animation';
  static const _posKey         = 'reminder_position';
  static const _colorModeKey   = 'reminder_color_mode';
  static const _customColorKey = 'reminder_custom_color';

  Future<ReminderSettings> load() async {
    final prefs        = await SharedPreferences.getInstance();
    final animIdx      = prefs.getInt(_animKey)      ?? ReminderAnimation.bounce.index;
    final posIdx       = prefs.getInt(_posKey)       ?? ReminderPosition.center.index;
    final colorModeIdx = prefs.getInt(_colorModeKey) ?? BannerColorMode.dark.index;
    final customColor  = prefs.getInt(_customColorKey) ?? ReminderSettings.defaultCustomColor;
    return ReminderSettings(
      message:     prefs.getString(_msgKey) ?? ReminderSettings.defaultMessage,
      animation:   ReminderAnimation.values[animIdx.clamp(0, ReminderAnimation.values.length - 1)],
      position:    ReminderPosition.values[posIdx.clamp(0, ReminderPosition.values.length - 1)],
      colorMode:   BannerColorMode.values[colorModeIdx.clamp(0, BannerColorMode.values.length - 1)],
      customColor: customColor,
    );
  }

  Future<void> save(ReminderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_msgKey,          s.message);
    await prefs.setInt(_animKey,            s.animation.index);
    await prefs.setInt(_posKey,             s.position.index);
    await prefs.setInt(_colorModeKey,       s.colorMode.index);
    await prefs.setInt(_customColorKey,     s.customColor);
  }
}
