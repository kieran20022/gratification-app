enum ReminderPosition  { top, center, bottom }
enum BannerColorMode   { dark, bright, custom }

class ReminderSettings {
  static const defaultMessage    = "You've been in {app} for {time}";
  // Stored as 0xRRGGBB (no alpha) to stay within signed int32 range.
  static const defaultCustomColor = 0x7B6FD4;

  final String           message;
  final ReminderPosition position;
  final BannerColorMode  colorMode;
  final int              customColor;

  const ReminderSettings({
    this.message     = defaultMessage,
    this.position    = ReminderPosition.center,
    this.colorMode   = BannerColorMode.dark,
    this.customColor = defaultCustomColor,
  });

  ReminderSettings copyWith({
    String?            message,
    ReminderPosition?  position,
    BannerColorMode?   colorMode,
    int?               customColor,
  }) => ReminderSettings(
    message:     message     ?? this.message,
    position:    position    ?? this.position,
    colorMode:   colorMode   ?? this.colorMode,
    customColor: customColor ?? this.customColor,
  );
}
