enum CountdownStyle { ring, fill, bar, none }

class AppSettings {
  static const defaultHeading = 'Are you sure you want to\nopen this app?';
  static const defaultSubtitle =
      'Take a breath. This is your moment\nto pause and reflect.';

  final String heading;
  final String subtitle;
  final bool showAttemptCount;
  final bool showAppLogo;
  final bool showAppName;
  final CountdownStyle countdownStyle;
  final bool showCountdownNumbers;

  const AppSettings({
    this.heading = defaultHeading,
    this.subtitle = defaultSubtitle,
    this.showAttemptCount = true,
    this.showAppLogo = true,
    this.showAppName = true,
    this.countdownStyle = CountdownStyle.ring,
    this.showCountdownNumbers = true,
  });

  AppSettings copyWith({
    String? heading,
    String? subtitle,
    bool? showAttemptCount,
    bool? showAppLogo,
    bool? showAppName,
    CountdownStyle? countdownStyle,
    bool? showCountdownNumbers,
  }) =>
      AppSettings(
        heading: heading ?? this.heading,
        subtitle: subtitle ?? this.subtitle,
        showAttemptCount: showAttemptCount ?? this.showAttemptCount,
        showAppLogo: showAppLogo ?? this.showAppLogo,
        showAppName: showAppName ?? this.showAppName,
        countdownStyle: countdownStyle ?? this.countdownStyle,
        showCountdownNumbers: showCountdownNumbers ?? this.showCountdownNumbers,
      );
}
