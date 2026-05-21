enum ReminderPosition  { top, center, bottom }
enum BannerColorMode   { dark, bright, custom }
enum BannerAnimation   { pop, fade, slide, none }

class ReminderSettings {
  static const defaultMessage     = "You've been in {app} for {time}";
  // Stored as 0xRRGGBB (no alpha) to stay within signed int32 range.
  static const defaultCustomColor = 0x7B6FD4;
  // Percent (0–100). 92 matches the legacy hardcoded argb alpha of 235/255.
  static const defaultOpacity     = 92;
  // Seconds the banner stays on screen (1–5).
  static const defaultDuration    = 4;

  final String           message;
  final ReminderPosition position;
  final BannerColorMode  colorMode;
  final int              customColor;
  final BannerAnimation  animation;
  final int              opacity;
  final int              duration;

  const ReminderSettings({
    this.message     = defaultMessage,
    this.position    = ReminderPosition.center,
    this.colorMode   = BannerColorMode.dark,
    this.customColor = defaultCustomColor,
    this.animation   = BannerAnimation.pop,
    this.opacity     = defaultOpacity,
    this.duration    = defaultDuration,
  });

  ReminderSettings copyWith({
    String?            message,
    ReminderPosition?  position,
    BannerColorMode?   colorMode,
    int?               customColor,
    BannerAnimation?   animation,
    int?               opacity,
    int?               duration,
  }) => ReminderSettings(
    message:     message     ?? this.message,
    position:    position    ?? this.position,
    colorMode:   colorMode   ?? this.colorMode,
    customColor: customColor ?? this.customColor,
    animation:   animation   ?? this.animation,
    opacity:     opacity     ?? this.opacity,
    duration:    duration    ?? this.duration,
  );
}
