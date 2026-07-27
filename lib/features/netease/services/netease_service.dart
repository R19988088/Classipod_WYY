import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_crypto.dart';
import 'package:classipod/features/netease/services/netease_parser.dart';
import 'package:classipod/features/netease/services/netease_playback_resolver.dart';
import 'package:classipod/features/settings/models/netease_audio_format.dart';
import 'package:classipod/features/settings/models/netease_flac_quality.dart';
import 'package:classipod/features/settings/models/netease_mp3_bitrate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final neteaseServiceProvider = Provider<NeteaseService>(
  (_) => NeteaseService(),
);

final neteaseSessionProvider =
    AsyncNotifierProvider<NeteaseSessionNotifier, NeteaseProfile?>(
      NeteaseSessionNotifier.new,
    );

final neteaseArtistsProvider = FutureProvider<List<NeteaseArtist>>(
  (ref) => ref.watch(neteaseServiceProvider).artists(),
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
  final Map<NeteaseCollectionKind, Future<List<NeteaseCollection>>>
  _libraryCache = {};
  final Map<String, Future<List<NeteaseTrack>>> _tracksCache = {};
  Future<List<NeteaseArtist>>? _artistsCache;
  final Map<String, Future<List<NeteaseTrack>>> _artistSongsCache = {};
  final String _deviceId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  bool _restored = false;
  NeteaseProfile? _profile;

  NeteaseProfile? get profile => _profile;

  Future<NeteaseProfile?> restoreProfile() async {
    await _restore();
    // Older backups stored the session cookie without the profile snapshot.
    // Rehydrate the profile from the existing session so those backups remain
    // usable without forcing another QR login.
    if (_profile == null && _cookies.containsKey('MUSIC_U')) {
      try {
        final account = await _postWeapi(
          'https://music.163.com/weapi/w/nuser/account/get',
          const {},
        ).timeout(const Duration(seconds: 8));
        _profile = NeteaseParser.profile(account);
        await _persist();
      } on Object {
        // Keep the restored cookie; the next authenticated request can retry.
      }
    }
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
      _clearCaches();
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
    _clearCaches();
    _cookies.clear();
    _profile = null;
    final preferences = SharedPreferencesAsync();
    await Future.wait([
      preferences.remove(_cookiesKey),
      preferences.remove(_profileKey),
    ]);
  }

  Future<List<NeteaseCollection>> library(NeteaseCollectionKind kind) async {
    final cached = _libraryCache[kind];
    if (cached != null) return cached;
    final request = _loadLibrary(kind);
    _libraryCache[kind] = request;
    try {
      return await request;
    } catch (_) {
      final _ = _libraryCache.remove(kind);
      rethrow;
    }
  }

  Future<NeteaseCollection> privateRadar() async {
    await _requireProfile();
    return NeteaseParser.privateRadar(
      await _postWeapi(
        'https://music.163.com/weapi/v1/discovery/recommend/resource',
        const {},
      ),
    );
  }

  Future<List<NeteaseArtist>> artists() async {
    final cached = _artistsCache;
    if (cached != null) return cached;
    final request = _loadArtists();
    _artistsCache = request;
    try {
      return await request;
    } catch (_) {
      _artistsCache = null;
      rethrow;
    }
  }

  Future<List<NeteaseArtist>> _loadArtists() async {
    await _requireProfile();
    return NeteaseParser.artists(
      await _postWeapi('https://music.163.com/weapi/artist/sublist', {
        'offset': '0',
        'limit': '1000',
        'total': 'true',
      }),
    );
  }

  Future<List<NeteaseTrack>> artistSongs(String artistId) async {
    final cached = _artistSongsCache[artistId];
    if (cached != null) return cached;
    final request = _loadArtistSongs(artistId);
    _artistSongsCache[artistId] = request;
    try {
      return await request;
    } catch (_) {
      final _ = _artistSongsCache.remove(artistId);
      rethrow;
    }
  }

  Future<List<NeteaseTrack>> _loadArtistSongs(String artistId) async {
    await _requireProfile();
    const limit = 100;
    var offset = 0;
    var more = true;
    final songs = <NeteaseTrack>[];
    final ids = <String>{};
    while (more) {
      final root =
          await _postPlain('https://music.163.com/api/v1/artist/songs', {
            'id': artistId,
            'private_cloud': 'true',
            'work_type': '1',
            'order': 'hot',
            'offset': '$offset',
            'limit': '$limit',
          });
      final page = NeteaseParser.artistSongs(root);
      final previousCount = songs.length;
      for (final song in page) {
        if (ids.add(song.id)) songs.add(song);
      }
      more =
          root['more'] == true &&
          page.isNotEmpty &&
          songs.length > previousCount;
      offset += page.length;
    }
    return songs;
  }

  Future<List<NeteaseCollection>> _loadLibrary(
    NeteaseCollectionKind kind,
  ) async {
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
    final key = '${collection.kind.name}:${collection.id}';
    final cached = _tracksCache[key];
    if (cached != null) return cached;
    final request = _loadTracks(collection);
    _tracksCache[key] = request;
    try {
      return await request;
    } catch (_) {
      final _ = _tracksCache.remove(key);
      rethrow;
    }
  }

  Future<List<NeteaseTrack>> _loadTracks(NeteaseCollection collection) async {
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

  Future<List<MusicMetadata>> playableTracks(
    List<NeteaseTrack> tracks, {
    String? preferredTrackId,
    NeteaseAudioFormat format = NeteaseAudioFormat.mp3,
    NeteaseMp3Bitrate mp3Bitrate = NeteaseMp3Bitrate.kbps320,
    NeteaseFlacQuality flacQuality = NeteaseFlacQuality.lossless,
  }) async {
    if (tracks.isEmpty) return const [];
    final ids = tracks.map((track) => int.parse(track.id)).toList();
    final urls = <String, String>{};
    (Object, StackTrace)? batchFailure;
    final Future<String?> preferredUrl = preferredTrackId == null
        ? Future.value()
        : playbackUrl(
            preferredTrackId,
            format: format,
            mp3Bitrate: mp3Bitrate,
            flacQuality: flacQuality,
          ).then<String?>((url) => url).catchError((_) => null);
    for (var offset = 0; offset < ids.length; offset += 200) {
      final page = ids.sublist(offset, min(offset + 200, ids.length));
      try {
        final root = switch (format) {
          NeteaseAudioFormat.mp3 => await _postWeapi(
            'https://music.163.com/weapi/song/enhance/player/url',
            {'ids': jsonEncode(page), 'br': '${mp3Bitrate.apiValue}'},
          ),
          NeteaseAudioFormat.flac => await requestNeteaseEapiWithSessionRetry(
            request: () => _postEapi(
              'https://interface.music.163.com/eapi/song/enhance/player/url/v1',
              {
                'ids': jsonEncode(page),
                'level': flacQuality.name,
                'encodeType': 'flac',
                if (flacQuality == NeteaseFlacQuality.sky) 'immerseType': 'c51',
              },
            ),
            warmSession: () async {
              await _get(Uri.parse('https://music.163.com/'));
            },
            hasLogin:
                _cookies.containsKey('MUSIC_U') ||
                _cookies.containsKey('MUSIC_A'),
          ),
        };
        _collectPlaybackUrls(root, urls);
        if (format == NeteaseAudioFormat.flac) {
          final missing = page.where((id) => !urls.containsKey('$id')).toList();
          if (missing.isNotEmpty) {
            _collectPlaybackUrls(
              await _postWeapi(
                'https://music.163.com/weapi/song/enhance/player/url',
                {'ids': jsonEncode(missing), 'br': '${mp3Bitrate.apiValue}'},
              ),
              urls,
            );
          }
        }
      } catch (error, stackTrace) {
        batchFailure = (error, stackTrace);
        break;
      }
    }
    final resolvedPreferredUrl = await preferredUrl;
    if (resolvedPreferredUrl != null && preferredTrackId != null) {
      urls[preferredTrackId] = resolvedPreferredUrl;
    } else if (preferredTrackId != null &&
        !urls.containsKey(preferredTrackId)) {
      if (batchFailure case (final error, final stackTrace)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      throw StateError('该曲目当前账号无播放权限');
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

  Future<String> playbackUrl(
    String trackId, {
    NeteaseAudioFormat format = NeteaseAudioFormat.mp3,
    NeteaseMp3Bitrate mp3Bitrate = NeteaseMp3Bitrate.kbps320,
    NeteaseFlacQuality flacQuality = NeteaseFlacQuality.lossless,
  }) async {
    await _restore();
    return NeteasePlaybackResolver(
      format: format,
      flacQuality: flacQuality,
      requestEapi: (level) => _postEapi(
        'https://interface.music.163.com/eapi/song/enhance/player/url/v1',
        {
          'ids': '[$trackId]',
          'level': level,
          'encodeType': 'flac',
          if (level == NeteaseFlacQuality.sky.name) 'immerseType': 'c51',
        },
      ),
      requestWeapi: () => _postWeapi(
        'https://music.163.com/weapi/song/enhance/player/url',
        {'ids': '[$trackId]', 'br': '${mp3Bitrate.apiValue}'},
      ),
      warmSession: () async {
        await _get(Uri.parse('https://music.163.com/'));
      },
      hasLogin:
          _cookies.containsKey('MUSIC_U') || _cookies.containsKey('MUSIC_A'),
    ).resolve();
  }

  void _collectPlaybackUrls(
    Map<String, dynamic> root,
    Map<String, String> urls,
  ) {
    _requireSuccess(root, '获取播放地址');
    final data = root['data'];
    if (data is! List) throw const FormatException('播放响应缺少 data');
    for (final item in data.whereType<Map>()) {
      final id = item['id'];
      final url = item['url'];
      if (id != null && url is String && url.isNotEmpty) {
        urls['$id'] = url.replaceFirst('http://', 'https://');
      }
    }
  }

  Future<List<NeteaseTrack>> _playlistTracks(String id) async {
    final root = await _postPlain(
      'https://music.163.com/api/v6/playlist/detail',
      {'id': id, 'n': '100000', 's': '8'},
    );
    final playlist = root['playlist'];
    if (playlist is! Map) throw const FormatException('歌单详情缺少 playlist');
    final cover = NeteaseParser.coverUrlFromCollection(playlist);
    final tracks = NeteaseParser.playlistTracks(root, fallbackCover: cover);
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

  void _clearCaches() {
    _libraryCache.clear();
    _tracksCache.clear();
    _artistsCache = null;
    _artistSongsCache.clear();
  }

  Future<void> _restore() async {
    if (_restored) return;
    final preferences = SharedPreferencesAsync();
    final cookiesJson = await preferences.getString(_cookiesKey);
    final profileJson = await preferences.getString(_profileKey);
    if (cookiesJson != null) {
      try {
        final values = jsonDecode(cookiesJson);
        if (values is Map) {
          _cookies.addAll(
            values.map((key, value) => MapEntry('$key', '$value')),
          );
        }
      } on FormatException {
        // Accept the cookie-header representation used by older backups.
        for (final pair in cookiesJson.split(';')) {
          final separator = pair.indexOf('=');
          if (separator <= 0) continue;
          _cookies[pair.substring(0, separator).trim()] = pair
              .substring(separator + 1)
              .trim();
        }
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
    final preferences = SharedPreferencesAsync();
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

  Future<Map<String, dynamic>> _postEapi(
    String url,
    Map<String, dynamic> payload,
  ) {
    final target = Uri.parse(url);
    final now = DateTime.now().millisecondsSinceEpoch;
    final header = <String, String>{
      'osver': _cookies['osver'] ?? 'Android 16',
      'deviceId': _cookies['deviceId'] ?? _deviceId,
      'os': _cookies['os'] ?? 'android',
      'appver': _cookies['appver'] ?? '8.10.35',
      'versioncode': _cookies['versioncode'] ?? '140',
      'mobilename': _cookies['mobilename'] ?? '',
      'buildver': _cookies['buildver'] ?? '${now ~/ 1000}',
      'resolution': _cookies['resolution'] ?? '1920x1080',
      '__csrf': _cookies['__csrf'] ?? '',
      'channel': _cookies['channel'] ?? 'netease',
      'requestId':
          '${now}_${Random.secure().nextInt(10000).toString().padLeft(4, '0')}',
      if (_cookies['MUSIC_U'] case final String value) 'MUSIC_U': value,
      if (_cookies['MUSIC_A'] case final String value) 'MUSIC_A': value,
    };
    return _post(target, {
      'params': NeteaseCrypto.eapi(target.path, {...payload, 'header': header}),
    }, cookies: header);
  }

  Future<Map<String, dynamic>> _postPlain(
    String url,
    Map<String, String> payload,
  ) => _post(Uri.parse(url), payload);

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, String> form, {
    Map<String, String>? cookies,
  }) async {
    final request = await _http.postUrl(uri);
    _headers(request, cookies: cookies);
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

  void _headers(HttpClientRequest request, {Map<String, String>? cookies}) {
    request.headers
      ..set(HttpHeaders.acceptHeader, '*/*')
      ..set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh-Hans;q=0.9')
      ..set(HttpHeaders.refererHeader, 'https://music.163.com/');
    final requestCookies = cookies ?? _cookies;
    if (requestCookies.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        requestCookies.entries
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
