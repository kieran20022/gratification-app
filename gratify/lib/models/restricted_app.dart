import 'dart:convert';

class RestrictedApp {
  final String id;
  final String name;
  final String packageName;
  final int delaySeconds;
  /// Minutes after opening during which re-opens are allowed without a delay.
  /// 0 = always delay on re-open.
  final int graceMinutes;
  final int dailyAttempts;
  final String lastAttemptDate;
  /// Whether to force grayscale display when this app is open.
  final bool grayscale;
  /// Start of the grayscale time window (minutes since midnight), or null for all day.
  final int? grayscaleStartMinute;
  /// End of the grayscale time window (minutes since midnight), or null for all day.
  final int? grayscaleEndMinute;
  /// Show a nudge overlay every X minutes while the app is open. 0 = disabled.
  final int reminderIntervalSeconds;
  /// Re-trigger the delay screen after X minutes of continuous use. 0 = disabled.
  final int usageLimitSeconds;

  const RestrictedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.delaySeconds,
    this.graceMinutes = 2,
    this.dailyAttempts = 0,
    this.lastAttemptDate = '',
    this.grayscale = false,
    this.grayscaleStartMinute,
    this.grayscaleEndMinute,
    this.reminderIntervalSeconds = 0,
    this.usageLimitSeconds = 0,
  });

  String get delayLabel {
    if (delaySeconds < 60) return '${delaySeconds}s delay';
    final mins = delaySeconds ~/ 60;
    final secs = delaySeconds % 60;
    if (secs == 0) return '${mins}m delay';
    return '${mins}m ${secs}s delay';
  }

  RestrictedApp copyWith({
    String? id,
    String? name,
    String? packageName,
    int? delaySeconds,
    int? graceMinutes,
    int? dailyAttempts,
    String? lastAttemptDate,
    bool? grayscale,
    Object? grayscaleStartMinute = _sentinel,
    Object? grayscaleEndMinute = _sentinel,
    int? reminderIntervalSeconds,
    int? usageLimitSeconds,
  }) {
    return RestrictedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      dailyAttempts: dailyAttempts ?? this.dailyAttempts,
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
      grayscale: grayscale ?? this.grayscale,
      grayscaleStartMinute: grayscaleStartMinute == _sentinel
          ? this.grayscaleStartMinute
          : grayscaleStartMinute as int?,
      grayscaleEndMinute: grayscaleEndMinute == _sentinel
          ? this.grayscaleEndMinute
          : grayscaleEndMinute as int?,
      reminderIntervalSeconds: reminderIntervalSeconds ?? this.reminderIntervalSeconds,
      usageLimitSeconds: usageLimitSeconds ?? this.usageLimitSeconds,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'delaySeconds': delaySeconds,
        'graceMinutes': graceMinutes,
        'dailyAttempts': dailyAttempts,
        'lastAttemptDate': lastAttemptDate,
        'grayscale': grayscale,
        'grayscaleStartMinute': grayscaleStartMinute,
        'grayscaleEndMinute': grayscaleEndMinute,
        'reminderIntervalSeconds': reminderIntervalSeconds,
        'usageLimitSeconds': usageLimitSeconds,
      };

  factory RestrictedApp.fromMap(Map<String, dynamic> map) => RestrictedApp(
        id: map['id'] as String,
        name: map['name'] as String,
        packageName: (map['packageName'] as String?) ?? '',
        delaySeconds: map['delaySeconds'] as int,
        graceMinutes: (map['graceMinutes'] as int?) ?? 2,
        dailyAttempts: (map['dailyAttempts'] as int?) ?? 0,
        lastAttemptDate: (map['lastAttemptDate'] as String?) ?? '',
        grayscale: (map['grayscale'] as bool?) ?? false,
        grayscaleStartMinute: map['grayscaleStartMinute'] as int?,
        grayscaleEndMinute: map['grayscaleEndMinute'] as int?,
        reminderIntervalSeconds: (map['reminderIntervalSeconds'] as int?) ?? 0,
        usageLimitSeconds: (map['usageLimitSeconds'] as int?) ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  factory RestrictedApp.fromJson(String source) =>
      RestrictedApp.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

// Sentinel used by copyWith to distinguish "omitted" from explicit null.
const _sentinel = Object();
