import 'dart:async';

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
  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast(sync: true);
  int? loadedInitialIndex;
  int shuffleCount = 0;
  int nextCount = 0;
  void Function()? beforeSetAudioSources;
  Error? setAudioSourcesError;
  bool isPlaying = false;
  bool wasPaused = false;
  double currentVolume = 1;
  final volumeChanges = <double>[];

  @override
  bool get playing => isPlaying;

  @override
  double get volume => currentVolume;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  void emitCurrentIndex(int index) => _currentIndexController.add(index);

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    beforeSetAudioSources?.call();
    if (setAudioSourcesError case final error?) throw error;
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

  @override
  Future<void> pause() async {
    wasPaused = true;
    isPlaying = false;
  }

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume;
    volumeChanges.add(volume);
  }

  @override
  Future<void> dispose() async {
    await _currentIndexController.close();
    await super.dispose();
  }
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

  test(
    'metadata is ready before the player exposes its initial index',
    () async {
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
      container.read(nowPlayingDetailsProvider);
      String? metadataWhenPlayerLoaded;
      player.beforeSetAudioSources = () {
        player.emitCurrentIndex(1);
        metadataWhenPlayerLoaded = container
            .read(nowPlayingDetailsProvider)
            .currentMetadata
            ?.trackName;
      };

      await container
          .read(audioPlayerServiceProvider.notifier)
          .setAudioSource(musicMetadataList: songs, initialIndex: 1);
      expect(metadataWhenPlayerLoaded, 'Selected');
    },
  );

  test('an out-of-range player index keeps the current metadata', () async {
    final player = _RecordingAudioPlayer();
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final song = MusicMetadata(trackName: 'Only', filePath: 'only.mp3');
    container
        .read(nowPlayingDetailsProvider.notifier)
        .setNewMetadataList(newMetadataList: [song]);

    player.emitCurrentIndex(9);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(nowPlayingDetailsProvider).currentMetadata, song);
    expect(container.read(nowPlayingDetailsProvider).currentIndex, 0);
  });

  test('player source errors are returned to the screen', () async {
    final player = _RecordingAudioPlayer()
      ..setAudioSourcesError = StateError('source failed');
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    await expectLater(
      container
          .read(audioPlayerServiceProvider.notifier)
          .setAudioSource(
            musicMetadataList: [
              MusicMetadata(trackName: 'Song', filePath: 'song.mp3'),
            ],
          ),
      throwsStateError,
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
    await Future<void>.delayed(const Duration(milliseconds: 110));

    expect(player.loadedInitialIndex, isNull);
    expect(player.shuffleCount, 1);
    expect(player.nextCount, 1);
  });

  test('pausing white noise fades out before stopping', () async {
    final player = _RecordingAudioPlayer()
      ..isPlaying = true
      ..currentVolume = 0.8;
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    container
        .read(nowPlayingDetailsProvider.notifier)
        .setNewMetadataList(
          newMetadataList: [
            MusicMetadata(trackName: 'Purr', filePath: 'procedural://purr'),
          ],
        );

    await container.read(audioPlayerServiceProvider.notifier).pause();

    expect(player.wasPaused, isTrue);
    expect(player.volumeChanges, hasLength(greaterThan(2)));
    expect(player.volumeChanges.first, lessThan(0.8));
    expect(player.volumeChanges, contains(0));
    expect(player.currentVolume, 0.8);
  });

  test('pausing ordinary music does not alter its volume', () async {
    final player = _RecordingAudioPlayer()..isPlaying = true;
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    container
        .read(nowPlayingDetailsProvider.notifier)
        .setNewMetadataList(
          newMetadataList: [
            MusicMetadata(trackName: 'Song', filePath: '/music/song.mp3'),
          ],
        );

    await container.read(audioPlayerServiceProvider.notifier).pause();

    expect(player.wasPaused, isTrue);
    expect(player.volumeChanges, isEmpty);
  });
}
