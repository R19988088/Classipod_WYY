import 'package:classipod/features/netease/models/netease_models.dart';

abstract final class NeteaseParser {
  static String qrKey(Map<String, dynamic> root) {
    _requireCode(root, 200, '创建登录二维码');
    final key =
        _string(root['unikey']) ?? _string((root['data'] as Map?)?['unikey']);
    if (key == null) throw const FormatException('二维码响应缺少 unikey');
    return key;
  }

  static NeteaseQrStatus qrStatus(Map<String, dynamic> root) {
    return switch (_integer(root['code'])) {
      800 => NeteaseQrStatus.expired,
      801 => NeteaseQrStatus.waiting,
      802 => NeteaseQrStatus.scanned,
      803 => NeteaseQrStatus.confirmed,
      _ => throw FormatException(_message(root, '检查登录二维码')),
    };
  }

  static NeteaseProfile profile(Map<String, dynamic> root) {
    _requireCode(root, 200, '获取账号信息');
    final value = root['profile'];
    if (value is! Map) throw const FormatException('账号响应缺少 profile');
    final id = _integer(value['userId']);
    if (id == null) throw const FormatException('账号响应缺少 userId');
    return NeteaseProfile(
      id: '$id',
      nickname: _string(value['nickname']) ?? '网易云用户',
      avatarUrl: _https(_string(value['avatarUrl'])),
    );
  }

  static List<NeteaseCollection> playlists(Map<String, dynamic> root) {
    _requireCode(root, 200, '个人歌单');
    final items = root['playlist'];
    if (items is! List) throw const FormatException('歌单响应缺少 playlist');
    return items
        .whereType<Map>()
        .map((item) {
          final creator = item['creator'] as Map?;
          return NeteaseCollection(
            id: '${_integer(item['id'])}',
            kind: NeteaseCollectionKind.playlist,
            title: _string(item['name']) ?? '',
            subtitle: _string(creator?['nickname']) ?? '',
            coverUrl:
                _https(
                  _string(item['coverImgUrl']) ??
                      _string(item['coverUrl']) ??
                      _string(item['picUrl']) ??
                      _string(item['backgroundCoverUrl']) ??
                      _string(item['titleImageUrl']),
                ) ??
                '',
            trackCount: _integer(item['trackCount']),
          );
        })
        .where((item) => item.id != 'null' && item.title.isNotEmpty)
        .toList();
  }

  static List<NeteaseCollection> albums(Map<String, dynamic> root) {
    _requireCode(root, 200, '收藏专辑');
    final items = root['data'] ?? root['playlist'];
    if (items is! List) throw const FormatException('专辑响应缺少 data');
    return items
        .whereType<Map>()
        .map((item) {
          final info = item['dataInfo'] as Map?;
          final data = (info?['data'] as Map?) ?? item;
          final artists = data['artists'] as List?;
          return NeteaseCollection(
            id: '${_integer(data['id'])}',
            kind: NeteaseCollectionKind.album,
            title: _string(data['name']) ?? '',
            subtitle: _artists(artists),
            coverUrl:
                _https(
                  _string(info?['picUrl']) ??
                      _string(data['picUrl']) ??
                      _string(data['blurPicUrl']),
                ) ??
                '',
            trackCount: _integer(data['size']) ?? _integer(data['songCount']),
          );
        })
        .where((item) => item.id != 'null' && item.title.isNotEmpty)
        .toList();
  }

  static List<NeteaseCollection> podcasts(Map<String, dynamic> root) {
    _requireCode(root, 200, '订阅播客');
    final data = root['data'];
    final items =
        root['djRadios'] ??
        (data is List ? data : null) ??
        (data is Map ? data['djRadios'] ?? data['list'] : null);
    if (items is! List) throw const FormatException('播客响应缺少列表');
    return items
        .whereType<Map>()
        .map((item) {
          final publisher = (item['dj'] as Map?) ?? (item['creator'] as Map?);
          return NeteaseCollection(
            id: '${_integer(item['id']) ?? _integer(item['radioId'])}',
            kind: NeteaseCollectionKind.podcast,
            title: _string(item['name']) ?? _string(item['title']) ?? '',
            subtitle: _string(publisher?['nickname']) ?? '',
            coverUrl:
                _https(_string(item['picUrl']) ?? _string(item['coverUrl'])) ??
                '',
            trackCount:
                _integer(item['programCount']) ?? _integer(item['trackCount']),
          );
        })
        .where((item) => item.id != 'null' && item.title.isNotEmpty)
        .toList();
  }

  static List<NeteaseTrack> tracks(Map<String, dynamic> root) {
    _requireCode(root, 200, '曲目详情');
    final items = root['songs'];
    if (items is! List) throw const FormatException('曲目响应缺少 songs');
    return items
        .whereType<Map>()
        .map(_track)
        .whereType<NeteaseTrack>()
        .toList();
  }

  static List<NeteaseTrack> playlistTracks(Map<String, dynamic> root) {
    _requireCode(root, 200, '歌单详情');
    final playlist = root['playlist'];
    if (playlist is! Map) throw const FormatException('歌单详情缺少 playlist');
    return tracks({'code': 200, 'songs': playlist['tracks'] ?? const []});
  }

  static List<NeteaseTrack> albumTracks(Map<String, dynamic> root) {
    _requireCode(root, 200, '专辑详情');
    final album = root['album'] as Map?;
    final cover = _https(_string(album?['picUrl']));
    final items = root['songs'];
    if (items is! List) throw const FormatException('专辑详情缺少 songs');
    return items
        .whereType<Map>()
        .map((item) => _track(item, fallbackCover: cover))
        .whereType<NeteaseTrack>()
        .toList();
  }

  static List<NeteaseTrack> podcastTracks(
    Map<String, dynamic> root,
    NeteaseCollection collection,
  ) {
    _requireCode(root, 200, '播客节目');
    final data = root['data'];
    final programs =
        root['programs'] ?? (data is Map ? data['programs'] : null);
    if (programs is! List) throw const FormatException('播客响应缺少 programs');
    return programs
        .whereType<Map>()
        .map((program) {
          final song = program['mainSong'];
          if (song is! Map) return null;
          final id = _integer(song['id']) ?? _integer(program['mainSongId']);
          final dj = program['dj'] as Map?;
          return id == null
              ? null
              : NeteaseTrack(
                  id: '$id',
                  title:
                      _string(program['name']) ?? _string(song['name']) ?? '',
                  artist:
                      _artists(
                        song['ar'] as List? ?? song['artists'] as List?,
                      ).trim().isNotEmpty
                      ? _artists(
                          song['ar'] as List? ?? song['artists'] as List?,
                        )
                      : _string(dj?['nickname']) ?? collection.subtitle,
                  album: collection.title,
                  durationMs:
                      _integer(song['duration']) ?? _integer(song['dt']) ?? 0,
                  coverUrl:
                      _https(_string(program['coverUrl'])) ??
                      collection.coverUrl,
                );
        })
        .whereType<NeteaseTrack>()
        .toList();
  }

  static String playbackUrl(Map<String, dynamic> root) {
    _requireCode(root, 200, '获取播放地址');
    final data = root['data'];
    final item = data is List && data.isNotEmpty
        ? data.first
        : data is Map
        ? data
        : null;
    final url = item is Map ? _https(_string(item['url'])) : null;
    if (url == null) throw const FormatException('网易云未返回可播放地址');
    return url;
  }

  static Map<String, String> cookies(Iterable<String> values) => {
    for (final value in values)
      if (value.split(';').first.trim().split('=').first.trim().isNotEmpty)
        value.split(';').first.trim().split('=').first.trim(): value
            .split(';')
            .first
            .trim()
            .substring(value.split(';').first.trim().indexOf('=') + 1),
  };

  static NeteaseTrack? _track(Map item, {String? fallbackCover}) {
    final id = _integer(item['id']);
    final title = _string(item['name']);
    if (id == null || title == null) return null;
    final album = (item['al'] as Map?) ?? (item['album'] as Map?);
    return NeteaseTrack(
      id: '$id',
      title: title,
      artist: _artists(item['ar'] as List? ?? item['artists'] as List?),
      album: _string(album?['name']) ?? '',
      durationMs: _integer(item['dt']) ?? _integer(item['duration']) ?? 0,
      coverUrl: _https(_string(album?['picUrl'])) ?? fallbackCover,
    );
  }

  static String _artists(List? values) =>
      values
          ?.whereType<Map>()
          .map((item) => _string(item['name']))
          .whereType<String>()
          .join(' / ') ??
      '';

  static int? _integer(dynamic value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };

  static String? _string(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String? _https(String? value) => value?.startsWith('http://') == true
      ? 'https://${value!.substring(7)}'
      : value;

  static void _requireCode(
    Map<String, dynamic> root,
    int expected,
    String action,
  ) {
    if (_integer(root['code']) != expected) {
      throw FormatException(_message(root, action));
    }
  }

  static String _message(Map<String, dynamic> root, String action) =>
      '$action失败：${_string(root['msg']) ?? _string(root['message']) ?? '接口返回 code=${root['code']}'}';
}
