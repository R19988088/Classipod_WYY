enum NeteaseCollectionKind { album, playlist, podcast }

enum NeteaseQrStatus { expired, waiting, scanned, confirmed }

class NeteaseProfile {
  const NeteaseProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
  };

  factory NeteaseProfile.fromJson(Map<String, dynamic> json) => NeteaseProfile(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

class NeteaseCollection {
  const NeteaseCollection({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.trackCount,
  });

  final String id;
  final NeteaseCollectionKind kind;
  final String title;
  final String subtitle;
  final String coverUrl;
  final int? trackCount;
}

class NeteaseTrack {
  const NeteaseTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? coverUrl;
}

class NeteaseQrChallenge {
  const NeteaseQrChallenge(this.key);

  final String key;
  String get loginUrl => 'https://music.163.com/login?codekey=$key';
}
