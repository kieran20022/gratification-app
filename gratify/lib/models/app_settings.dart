enum CountdownStyle { ring, fill, bar, none, breath }

class AppSettings {
  static const defaultHeading = 'Are you sure you want to\nopen this app?';
  static const defaultSubtitle =
      'Take a breath. This is your moment\nto pause and reflect.';

  // default font sizes
  static const double defaultFontSizeAppName        = 24;
  static const double defaultFontSizeAttemptCount   = 14;
  static const double defaultFontSizeHeading        = 19;
  static const double defaultFontSizeSubtitle       = 14;
  static const double defaultFontSizeTimerNumber    = 72;
  static const double defaultFontSizeTimerLabel     = 14;

  final String heading;
  final String subtitle;
  final bool showAttemptCount;
  final bool showAppLogo;
  final bool showAppName;
  final bool showHeading;
  final bool showSubtitle;
  final CountdownStyle countdownStyle;
  final bool showCountdownNumbers;
  final bool showBreathText;

  final double fontSizeAppName;
  final double fontSizeAttemptCount;
  final double fontSizeHeading;
  final double fontSizeSubtitle;
  final double fontSizeTimerNumber;
  final double fontSizeTimerLabel;

  const AppSettings({
    this.heading           = defaultHeading,
    this.subtitle          = defaultSubtitle,
    this.showAttemptCount  = true,
    this.showAppLogo       = true,
    this.showAppName       = true,
    this.showHeading       = true,
    this.showSubtitle      = true,
    this.countdownStyle    = CountdownStyle.ring,
    this.showCountdownNumbers = true,
    this.showBreathText    = true,
    this.fontSizeAppName       = defaultFontSizeAppName,
    this.fontSizeAttemptCount  = defaultFontSizeAttemptCount,
    this.fontSizeHeading       = defaultFontSizeHeading,
    this.fontSizeSubtitle      = defaultFontSizeSubtitle,
    this.fontSizeTimerNumber   = defaultFontSizeTimerNumber,
    this.fontSizeTimerLabel    = defaultFontSizeTimerLabel,
  });

  AppSettings copyWith({
    String? heading,
    String? subtitle,
    bool? showAttemptCount,
    bool? showAppLogo,
    bool? showAppName,
    bool? showHeading,
    bool? showSubtitle,
    CountdownStyle? countdownStyle,
    bool? showCountdownNumbers,
    bool? showBreathText,
    double? fontSizeAppName,
    double? fontSizeAttemptCount,
    double? fontSizeHeading,
    double? fontSizeSubtitle,
    double? fontSizeTimerNumber,
    double? fontSizeTimerLabel,
  }) =>
      AppSettings(
        heading:           heading          ?? this.heading,
        subtitle:          subtitle         ?? this.subtitle,
        showAttemptCount:  showAttemptCount ?? this.showAttemptCount,
        showAppLogo:       showAppLogo      ?? this.showAppLogo,
        showAppName:       showAppName      ?? this.showAppName,
        showHeading:       showHeading      ?? this.showHeading,
        showSubtitle:      showSubtitle     ?? this.showSubtitle,
        countdownStyle:    countdownStyle   ?? this.countdownStyle,
        showCountdownNumbers: showCountdownNumbers ?? this.showCountdownNumbers,
        showBreathText:    showBreathText   ?? this.showBreathText,
        fontSizeAppName:       fontSizeAppName      ?? this.fontSizeAppName,
        fontSizeAttemptCount:  fontSizeAttemptCount ?? this.fontSizeAttemptCount,
        fontSizeHeading:       fontSizeHeading      ?? this.fontSizeHeading,
        fontSizeSubtitle:      fontSizeSubtitle     ?? this.fontSizeSubtitle,
        fontSizeTimerNumber:   fontSizeTimerNumber  ?? this.fontSizeTimerNumber,
        fontSizeTimerLabel:    fontSizeTimerLabel   ?? this.fontSizeTimerLabel,
      );
}
