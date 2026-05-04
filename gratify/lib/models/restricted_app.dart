import 'dart:convert';

class RestrictedApp {
  final String id;
  final String name;
  final String packageName;
  final int delaySeconds;
  final int dailyAttempts;
  final String lastAttemptDate;

  const RestrictedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.delaySeconds,
    this.dailyAttempts = 0,
    this.lastAttemptDate = '',
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
    int? dailyAttempts,
    String? lastAttemptDate,
  }) {
    return RestrictedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      dailyAttempts: dailyAttempts ?? this.dailyAttempts,
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'delaySeconds': delaySeconds,
        'dailyAttempts': dailyAttempts,
        'lastAttemptDate': lastAttemptDate,
      };

  factory RestrictedApp.fromMap(Map<String, dynamic> map) => RestrictedApp(
        id: map['id'] as String,
        name: map['name'] as String,
        packageName: (map['packageName'] as String?) ?? '',
        delaySeconds: map['delaySeconds'] as int,
        dailyAttempts: (map['dailyAttempts'] as int?) ?? 0,
        lastAttemptDate: (map['lastAttemptDate'] as String?) ?? '',
      );

  String toJson() => jsonEncode(toMap());

  factory RestrictedApp.fromJson(String source) =>
      RestrictedApp.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
