import 'package:classipod/features/netease/services/netease_parser.dart';
import 'package:classipod/features/settings/models/netease_audio_format.dart';
import 'package:classipod/features/settings/models/netease_flac_quality.dart';

typedef NeteaseEapiRequest =
    Future<Map<String, dynamic>> Function(String level);
typedef NeteaseWeapiRequest = Future<Map<String, dynamic>> Function();

Future<Map<String, dynamic>> requestNeteaseEapiWithSessionRetry({
  required Future<Map<String, dynamic>> Function() request,
  required Future<void> Function() warmSession,
  required bool hasLogin,
}) async {
  var response = await request();
  if (response['code'] == 301 && hasLogin) {
    try {
      await warmSession();
    } catch (_) {}
    response = await request();
  }
  return response;
}

class NeteasePlaybackResolver {
  const NeteasePlaybackResolver({
    required this.format,
    required this.flacQuality,
    required this.requestEapi,
    required this.requestWeapi,
    required this.warmSession,
    required this.hasLogin,
  });

  final NeteaseAudioFormat format;
  final NeteaseFlacQuality flacQuality;
  final NeteaseEapiRequest requestEapi;
  final NeteaseWeapiRequest requestWeapi;
  final Future<void> Function() warmSession;
  final bool hasLogin;

  Future<String> resolve() async {
    if (format == NeteaseAudioFormat.mp3) {
      return NeteaseParser.playbackUrl(await requestWeapi());
    }
    try {
      final response = await requestNeteaseEapiWithSessionRetry(
        request: () => requestEapi(flacQuality.name),
        warmSession: warmSession,
        hasLogin: hasLogin,
      );
      return NeteaseParser.playbackUrl(response);
    } catch (_) {
      return NeteaseParser.playbackUrl(await requestWeapi());
    }
  }
}
