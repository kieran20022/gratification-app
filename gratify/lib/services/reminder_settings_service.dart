import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_settings.dart';

class ReminderSettingsService {
  // Keys stored without 'flutter.' prefix — shared_preferences adds it
  // automatically, so the Kotlin side reads them as 'flutter.reminder_*'.
  static const _msgKey         = 'reminder_message';
  static const _posKey         = 'reminder_position';
  static const _colorModeKey   = 'reminder_color_mode';
  static const _customColorKey = 'reminder_custom_color';
  static const _animKey        = 'reminder_animation';
  static const _opacityKey     = 'reminder_opacity';
  static const _durationKey    = 'reminder_duration';

  Future<ReminderSettings> load() async {
    final prefs        = await SharedPreferences.getInstance();
    final posIdx       = prefs.getInt(_posKey)       ?? ReminderPosition.center.index;
    final colorModeIdx = prefs.getInt(_colorModeKey) ?? BannerColorMode.dark.index;
    final customColor  = prefs.getInt(_customColorKey) ?? ReminderSettings.defaultCustomColor;
    final animIdx      = prefs.getInt(_animKey)      ?? BannerAnimation.pop.index;
    final opacity      = prefs.getInt(_opacityKey)   ?? ReminderSettings.defaultOpacity;
    final duration     = prefs.getInt(_durationKey)  ?? ReminderSettings.defaultDuration;
    return ReminderSettings(
      message:     prefs.getString(_msgKey) ?? ReminderSettings.defaultMessage,
      position:    ReminderPosition.values[posIdx.clamp(0, ReminderPosition.values.length - 1)],
      colorMode:   BannerColorMode.values[colorModeIdx.clamp(0, BannerColorMode.values.length - 1)],
      customColor: customColor,
      animation:   BannerAnimation.values[animIdx.clamp(0, BannerAnimation.values.length - 1)],
      opacity:     opacity.clamp(0, 100),
      duration:    duration.clamp(1, 5),
    );
  }

  Future<void> save(ReminderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_msgKey,          s.message);
    await prefs.setInt(_posKey,             s.position.index);
    await prefs.setInt(_colorModeKey,       s.colorMode.index);
    await prefs.setInt(_customColorKey,     s.customColor);
    await prefs.setInt(_animKey,            s.animation.index);
    await prefs.setInt(_opacityKey,         s.opacity);
    await prefs.setInt(_durationKey,        s.duration);
  }
}
