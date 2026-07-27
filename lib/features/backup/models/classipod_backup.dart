import 'dart:convert';

class ClassipodBackup {
  const ClassipodBackup({
    required this.version,
    required this.createdAt,
    required this.settings,
    required this.netease,
    required this.coverFlow,
  });

  static const currentVersion = 1;

  final int version;
  final DateTime createdAt;
  final Map<String, Object> settings;
  final Map<String, Object> netease;
  final Map<String, Object> coverFlow;

  factory ClassipodBackup.fromPreferences(
    Map<String, Object?> preferences, {
    DateTime? createdAt,
  }) {
    final cookies = preferences['netease.cookies'];
    final profile = preferences['netease.profile'];
    final localFavorites = preferences['coverFlow.local'];
    final neteaseFavorites = preferences['coverFlow.netease'];
    final settings =
        <String, Object>{
          for (final entry in preferences.entries)
            if (entry.value != null) entry.key: entry.value!,
        }..removeWhere(
          (key, _) =>
              key.startsWith('netease.') || key.startsWith('coverFlow.'),
        );
    return ClassipodBackup(
      version: currentVersion,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      settings: settings,
      netease: {'cookies': ?cookies, 'profile': ?profile},
      coverFlow: {'local': ?localFavorites, 'netease': ?neteaseFavorites},
    );
  }

  Map<String, Object> preferencesForRestore() => {
    ...settings,
    if (netease['cookies'] case final Object value)
      'netease.cookies': _jsonValue(value),
    if (netease['profile'] case final Object value)
      'netease.profile': _jsonValue(value),
    if (coverFlow['local'] case final Object value) 'coverFlow.local': value,
    if (coverFlow['netease'] case final Object value)
      'coverFlow.netease': value,
  };

  String encode() => jsonEncode({
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'settings': settings,
    'netease': netease,
    'coverFlow': coverFlow,
  });

  static String _jsonValue(Object value) => switch (value) {
    String() => value,
    _ => jsonEncode(value),
  };

  factory ClassipodBackup.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const FormatException('备份文件格式错误');
    final json = Map<String, dynamic>.from(decoded);
    if (json['version'] != currentVersion) {
      throw const FormatException('备份文件版本不受支持');
    }
    try {
      return ClassipodBackup(
        version: json['version'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        settings: Map<String, Object>.from(
          json['settings'] as Map? ?? const {},
        ),
        netease: Map<String, Object>.from(json['netease'] as Map? ?? const {}),
        coverFlow: Map<String, Object>.from(
          json['coverFlow'] as Map? ?? const {},
        ),
      );
    } on Object {
      throw const FormatException('备份文件格式错误');
    }
  }
}
