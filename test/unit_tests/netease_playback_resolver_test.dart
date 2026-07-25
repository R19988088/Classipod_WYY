import 'dart:io';

import 'package:classipod/features/netease/services/netease_playback_resolver.dart';
import 'package:classipod/features/settings/models/netease_audio_format.dart';
import 'package:classipod/features/settings/models/netease_flac_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FLAC batch requests use the same session retry path', () {
    final service = File(
      'lib/features/netease/services/netease_service.dart',
    ).readAsStringSync();

    expect(service, contains('requestNeteaseEapiWithSessionRetry('));
  });

  test('MP3 uses the bitrate endpoint without requesting EAPI', () async {
    var eapiCount = 0;
    final resolver = NeteasePlaybackResolver(
      format: NeteaseAudioFormat.mp3,
      flacQuality: NeteaseFlacQuality.lossless,
      requestEapi: (_) async {
        eapiCount++;
        return const {};
      },
      requestWeapi: () async => {
        'code': 200,
        'data': [
          {'url': 'http://mp3', 'type': 'mp3'},
        ],
      },
      warmSession: () async {},
      hasLogin: true,
    );

    expect(await resolver.resolve(), 'https://mp3');
    expect(eapiCount, 0);
  });

  test('FLAC code 301 warms the session and retries EAPI', () async {
    var calls = 0;
    var warmCount = 0;
    final resolver = NeteasePlaybackResolver(
      format: NeteaseAudioFormat.flac,
      flacQuality: NeteaseFlacQuality.hires,
      requestEapi: (level) async {
        expect(level, 'hires');
        calls++;
        return calls == 1
            ? {'code': 301}
            : {
                'code': 200,
                'data': [
                  {'url': 'http://flac', 'type': 'flac'},
                ],
              };
      },
      requestWeapi: () async => throw StateError('WEAPI should not run'),
      warmSession: () async => warmCount++,
      hasLogin: true,
    );

    expect(await resolver.resolve(), 'https://flac');
    expect(calls, 2);
    expect(warmCount, 1);
  });

  test(
    'FLAC keeps ALAC when the Android software decoder supports it',
    () async {
      final resolver = NeteasePlaybackResolver(
        format: NeteaseAudioFormat.flac,
        flacQuality: NeteaseFlacQuality.jymaster,
        requestEapi: (level) async => {
          'code': 200,
          'data': [
            {'url': 'http://unsupported/$level', 'type': 'alac'},
          ],
        },
        requestWeapi: () async => {
          'code': 200,
          'data': [
            {'url': 'http://fallback', 'type': 'mp3'},
          ],
        },
        warmSession: () async {},
        hasLogin: true,
      );

      expect(await resolver.resolve(), 'https://unsupported/jymaster');
    },
  );
}
