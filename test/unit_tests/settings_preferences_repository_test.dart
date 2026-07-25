// ignore_for_file: depend_on_referenced_packages

import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/netease_audio_format.dart';
import 'package:classipod/features/settings/models/netease_flac_quality.dart';
import 'package:classipod/features/settings/models/netease_mp3_bitrate.dart';
import 'package:classipod/features/settings/repository/settings_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new installations default to Netease and a large click wheel',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      final repository = SettingsPreferencesRepository(preferences);

      expect(repository.getMusicSource(), MusicSource.netease.name);
      expect(repository.getClickWheelSize(), ClickWheelSize.large.name);
      expect(repository.getNeteaseAudioFormat(), NeteaseAudioFormat.mp3.name);
      expect(repository.getNeteaseMp3Bitrate(), NeteaseMp3Bitrate.kbps320.name);
      expect(
        repository.getNeteaseFlacQuality(),
        NeteaseFlacQuality.lossless.name,
      );

      await repository.setNeteaseAudioFormat(
        formatName: NeteaseAudioFormat.flac.name,
      );
      await repository.setNeteaseMp3Bitrate(
        bitrateName: NeteaseMp3Bitrate.kbps192.name,
      );
      await repository.setNeteaseFlacQuality(
        qualityName: NeteaseFlacQuality.jymaster.name,
      );
      expect(repository.getNeteaseAudioFormat(), NeteaseAudioFormat.flac.name);
      expect(repository.getNeteaseMp3Bitrate(), NeteaseMp3Bitrate.kbps192.name);
      expect(
        repository.getNeteaseFlacQuality(),
        NeteaseFlacQuality.jymaster.name,
      );
    },
  );

  test('all API Enhanced bitrate and FLAC levels cycle in order', () {
    expect(NeteaseMp3Bitrate.kbps128.next, NeteaseMp3Bitrate.kbps192);
    expect(NeteaseMp3Bitrate.kbps192.next, NeteaseMp3Bitrate.kbps320);
    expect(NeteaseMp3Bitrate.kbps320.next, NeteaseMp3Bitrate.kbps128);
    expect(NeteaseFlacQuality.lossless.next, NeteaseFlacQuality.hires);
    expect(NeteaseFlacQuality.hires.next, NeteaseFlacQuality.jyeffect);
    expect(NeteaseFlacQuality.jyeffect.next, NeteaseFlacQuality.sky);
    expect(NeteaseFlacQuality.sky.next, NeteaseFlacQuality.jymaster);
    expect(NeteaseFlacQuality.jymaster.next, NeteaseFlacQuality.lossless);
  });
}
