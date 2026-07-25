import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_crypto.dart';
import 'package:classipod/features/netease/services/netease_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final neteaseServiceProvider = Provider<NeteaseService>(
  (_) => NeteaseService(),
);

final neteaseSessionProvider =
    AsyncNotifierProvider<NeteaseSessionNotifier, NeteaseProfile?>(
      NeteaseSessionNotifier.new,
    );

class NeteaseSessionNotifier extends AsyncNotifier<NeteaseProfile?> {
  @override
  Future<NeteaseProfile?> build() =>
      ref.read(neteaseServiceProvider).restoreProfile();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(neteaseServiceProvider).restoreProfile(),
    );
  }
}

class NeteaseService {
  static const _cookiesKey = 'netease.cookies';
  static const _profileKey = 'netease.profile';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10; Classipod) '
      'AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';

  final HttpClient _http = HttpClient()..userAgent = _userAgent;
  final Map<String, String> _cookies = {};
  bool _restored = false;
  NeteaseProfile? _profile;

  NeteaseProfile? get profile => _profile;

  Future<NeteaseProfile?> restoreProfile() async {
    await _restore();
    return _profile;
  }

  Future<NeteaseQrChallenge> createQrLogin() async {
    await _restore();
    await _get(Uri.parse('https://music.163.com/'));
    final root = await _postWeapi(
      'https://music.163.com/weapi/login/qrcode/unikey',
      {'type': 3},
    );
    return NeteaseQrChallenge(NeteaseParser.qrKey(root));
  }

  Future<NeteaseQrStatus> checkQrLogin(String key) async {
    final root = await _postWeapi(
      'https://music.163.com/weapi/login/qrcode/client/login',
      {'key': key, 'type': 3},
    );
    final status = NeteaseParser.qrStatus(root);
    if (status == NeteaseQrStatus.confirmed) {
      final account = await _postWeapi(
        'https://music.163.com/weapi/w/nuser/account/get',
        const {},
      );
      _profile = NeteaseParser.profile(account);
      await _persist();
    }
    return status;
  }

  Future<void> logout() async {
    _cookies.clear();
    _profile = null;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_cookiesKey),
      preferences.remove(_profileKey),
    ]);
  }

  Future<List<NeteaseCollection>> library(NeteaseCollectionKind kind) async {
    final profile = await _requireProfile();
    return switch (kind) {
      NeteaseCollectionKind.album => NeteaseParser.albums(
        await _postWeapi('https://music.163.com/weapi/album/sublist', {
          'offset': '0',
          'limit': '1000',
          'total': 'true',
        }),
      ),
      NeteaseCollectionKind.playlist => NeteaseParser.playlists(
        await _postWeapi('https://music.163.com/weapi/user/playlist', {
          'uid': profile.id,
          'offset': '0',
          'limit': '1000',
          'includeVideo': 'true',
        }),
      ),
      NeteaseCollectionKind.podcast => NeteaseParser.podcasts(
        await _postWeapi('https://music.163.com/weapi/djradio/get/subed', {
          'offset': '0',
          'limit': '1000',
          'total': 'true',
        }),
      ),
    };
  }

  Future<List<NeteaseTrack>> tracks(NeteaseCollection collection) async {
    await _requireProfile();
    return switch (collection.kind) {
      NeteaseCollectionKind.album => NeteaseParser.albumTracks(
        await _postWeapi(
          'https://interface.music.163.com/weapi/v1/album/${collection.id}',
          {'n': '100000', 's': '8'},
        ),
      ),
      NeteaseCollectionKind.playlist => _playlistTracks(collection.id),
      NeteaseCollectionKind.podcast => NeteaseParser.podcastTracks(
        await _postWeapi('https://music.163.com/weapi/dj/program/byradio', {
          'radioId': collection.id,
          'offset': '0',
          'limit': '1000',
          'asc': 'false',
        }),
        collection,
      ),
    };
  }

  Future<List<MusicMetadata>> playableTracks(List<NeteaseTrack> tracks) async {
    if (tracks.isEmpty) return const [];
    final ids = tracks.map((track) => int.parse(track.id)).toList();
    final root = await _postWeapi(
      'https://music.163.com/weapi/song/enhance/player/url',
      {'ids': jsonEncode(ids), 'br': '320000'},
    );
    _requireSuccess(root, '获取播放地址');
    final data = root['data'];
    if (data is! List) throw const FormatException('播放响应缺少 data');
    final urls = <String, String>{};
    for (final item in data.whereType<Map>()) {
      final id = item['id'];
      final url = item['url'];
      if (id != null && url is String && url.isNotEmpty) {
        urls['$id'] = url.replaceFirst('http://', 'https://');
      }
    }
    return [
      for (var index = 0; index < tracks.length; index++)
        if (urls[tracks[index].id] case final String url)
          MusicMetadata(
            trackName: tracks[index].title,
            trackArtistNames: [tracks[index].artist],
            albumName: tracks[index].album,
            albumArtistName: tracks[index].artist,
            trackNumber: index + 1,
            albumLength: tracks.length,
            trackDuration: tracks[index].durationMs,
            filePath: url,
            thumbnailPath: tracks[index].coverUrl,
            originalSongIndex: int.parse(tracks[index].id),
            isOnDevice: false,
          ),
    ];
  }

  Future<List<NeteaseTrack>> _playlistTracks(String id) async {
    final root = await _postPlain(
      'https://music.163.com/api/v6/playlist/detail',
      {'id': id, 'n': '100000', 's': '8'},
    );
    final playlist = root['playlist'];
    if (playlist is! Map) throw const FormatException('歌单详情缺少 playlist');
    final tracks = NeteaseParser.playlistTracks(root);
    final requestedIds = (playlist['trackIds'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item['id'])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList();
    final known = {for (final track in tracks) track.id};
    final missing = requestedIds.where((id) => !known.contains('$id')).toList();
    final all = [...tracks];
    for (var offset = 0; offset < missing.length; offset += 300) {
      final page = missing.sublist(offset, min(offset + 300, missing.length));
      all.addAll(
        NeteaseParser.tracks(
          await _postWeapi('https://music.163.com/weapi/v3/song/detail', {
            'c': jsonEncode(page.map((id) => {'id': id}).toList()),
            'ids': jsonEncode(page),
          }),
        ),
      );
    }
    if (requestedIds.isEmpty) return all;
    final byId = {for (final track in all) track.id: track};
    return requestedIds
        .map((id) => byId['$id'])
        .whereType<NeteaseTrack>()
        .toList();
  }

  Future<NeteaseProfile> _requireProfile() async {
    await _restore();
    if (_profile == null || !_cookies.containsKey('MUSIC_U')) {
      throw StateError('请先在设置中登录网易云音乐');
    }
    return _profile!;
  }

  Future<void> _restore() async {
    if (_restored) return;
    final preferences = await SharedPreferences.getInstance();
    final cookiesJson = preferences.getString(_cookiesKey);
    final profileJson = preferences.getString(_profileKey);
    if (cookiesJson != null) {
      final values = jsonDecode(cookiesJson);
      if (values is Map) {
        _cookies.addAll(values.map((key, value) => MapEntry('$key', '$value')));
      }
    }
    if (profileJson != null) {
      final value = jsonDecode(profileJson);
      if (value is Map<String, dynamic>) {
        _profile = NeteaseProfile.fromJson(value);
      } else if (value is Map) {
        _profile = NeteaseProfile.fromJson(Map<String, dynamic>.from(value));
      }
    }
    _restored = true;
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cookiesKey, jsonEncode(_cookies));
    if (_profile != null) {
      await preferences.setString(_profileKey, jsonEncode(_profile!.toJson()));
    }
  }

  Future<Map<String, dynamic>> _postWeapi(
    String url,
    Map<String, dynamic> payload,
  ) {
    final target = Uri.parse(
      url,
    ).replace(queryParameters: {'csrf_token': _cookies['__csrf'] ?? ''});
    return _post(target, NeteaseCrypto.weapi(payload));
  }

  Future<Map<String, dynamic>> _postPlain(
    String url,
    Map<String, String> payload,
  ) => _post(Uri.parse(url), payload);

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, String> form) async {
    final request = await _http.postUrl(uri);
    _headers(request);
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(
      form.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&'),
    );
    return _response(await request.close());
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final request = await _http.getUrl(uri);
    _headers(request);
    return _response(await request.close(), requireJson: false);
  }

  void _headers(HttpClientRequest request) {
    request.headers
      ..set(HttpHeaders.acceptHeader, '*/*')
      ..set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh-Hans;q=0.9')
      ..set(HttpHeaders.refererHeader, 'https://music.163.com/');
    if (_cookies.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        _cookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; '),
      );
    }
  }

  Future<Map<String, dynamic>> _response(
    HttpClientResponse response, {
    bool requireJson = true,
  }) async {
    final setCookies =
        response.headers[HttpHeaders.setCookieHeader] ?? const [];
    _cookies.addAll(NeteaseParser.cookies(setCookies));
    if (_cookies.isNotEmpty) {
      _cookies.putIfAbsent('os', () => 'pc');
      _cookies.putIfAbsent('appver', () => '8.10.35');
    }
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('网易云请求失败（HTTP ${response.statusCode}）');
    }
    if (!requireJson) return const {};
    final value = jsonDecode(body);
    if (value is! Map) throw const FormatException('网易云响应不是 JSON 对象');
    return Map<String, dynamic>.from(value);
  }

  static void _requireSuccess(Map<String, dynamic> root, String action) {
    if (root['code'] != 200) {
      throw FormatException(
        '$action失败：${root['message'] ?? root['msg'] ?? root['code']}',
      );
    }
  }
}
