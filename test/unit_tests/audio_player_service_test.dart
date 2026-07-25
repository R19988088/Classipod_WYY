import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/app_theme.dart';
import 'package:classipod/features/settings/models/click_wheel_sensitivity.dart';
import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/repeat_mode.dart';
import 'package:classipod/features/settings/models/settings_preferences_model.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _RecordingAudioPlayer extends AudioPlayer {
  int? loadedInitialIndex;
  int shuffleCount = 0;
  int nextCount = 0;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    loadedInitialIndex = initialIndex;
    return Duration.zero;
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}

  @override
  Future<void> shuffle() async => shuffleCount++;

  @override
  Future<void> seekToNext() async => nextCount++;

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> play() async {}
}

class _NeteaseSettingsController extends SettingsPreferencesControllerNotifier {
  @override
  SettingsPreferencesModel build() => SettingsPreferencesModel(
    languageLocaleCode: 'zh',
    deviceColor: DeviceColor.silver,
    clickWheelSize: ClickWheelSize.large,
    clickWheelSensitivity: ClickWheelSensitivity.medium,
    isTouchScreenEnabled: true,
    repeatMode: RepeatMode.off,
    vibrate: false,
    clickWheelSound: false,
    volumeMode: VolumeMode.app,
    splitScreenEnabled: false,
    immersiveMode: false,
    appTheme: AppTheme.light,
    musicSource: MusicSource.netease,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected track is the first source prepared by the player', () async {
    final player = _RecordingAudioPlayer();
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final songs = [
      MusicMetadata(trackName: 'First', filePath: 'first.mp3'),
      MusicMetadata(trackName: 'Selected', filePath: 'selected.mp3'),
    ];

    await container
        .read(audioPlayerServiceProvider.notifier)
        .setAudioSource(musicMetadataList: songs, initialIndex: 1);

    expect(player.loadedInitialIndex, 1);
    expect(
      container.read(nowPlayingDetailsProvider).currentMetadata?.trackName,
      'Selected',
    );
  });

  test('Netease shuffle keeps the current online queue', () async {
    final player = _RecordingAudioPlayer();
    final container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWithValue(player),
        settingsPreferencesControllerProvider.overrideWith(
          _NeteaseSettingsController.new,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final songs = [
      MusicMetadata(
        trackName: 'Online',
        filePath: 'https://example.test/song.mp3',
        isOnDevice: false,
      ),
    ];
    container
        .read(nowPlayingDetailsProvider.notifier)
        .setNewMetadataList(
          nowPlayingType: NowPlayingType.playlist,
          newMetadataList: songs,
        );

    await container.read(audioPlayerServiceProvider.notifier).shuffleAllSongs();

    expect(player.loadedInitialIndex, isNull);
    expect(player.shuffleCount, 1);
    expect(player.nextCount, 1);
  });
}
