import 'dart:async';
import 'dart:math';

import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/white_noise/controllers/white_noise_controller.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/procedural_audio_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _RecordingAudioPlayer extends AudioPlayer {
  AudioSource? loadedSource;
  LoopMode? loadedLoopMode;
  int playCount = 0;
  Completer<void>? playCompleter;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loadedSource = source;
    return Duration.zero;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loadedLoopMode = mode;
  }

  @override
  Future<void> play() async {
    playCount++;
    await playCompleter?.future;
  }
}

ProviderContainer _createContainer(_RecordingAudioPlayer player) {
  return ProviderContainer(
    overrides: [
      audioPlayerProvider.overrideWithValue(player),
      whiteNoiseRandomProvider.overrideWithValue(Random(0)),
      whiteNoiseConfiguredLoopModeProvider.overrideWithValue(LoopMode.off),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'starting noise replaces the queue with a playing two hour source',
    () async {
      final player = _RecordingAudioPlayer();
      final container = _createContainer(player);
      addTearDown(() async {
        container.dispose();
        await player.dispose();
      });

      await container
          .read(whiteNoiseControllerProvider.notifier)
          .start(WhiteNoiseCategory.noise);

      final session = container.read(whiteNoiseControllerProvider)!;
      final nowPlaying = container.read(nowPlayingDetailsProvider);
      expect(session.category, WhiteNoiseCategory.noise);
      expect(session.sound, WhiteNoiseSound.white);
      expect(player.loadedSource, isA<ProceduralAudioSource>());
      expect(player.loadedLoopMode, LoopMode.off);
      expect(player.playCount, 1);
      expect(container.read(sleepTimerControllerProvider), 120);
      expect(nowPlaying.metadataList, hasLength(1));
      expect(nowPlaying.currentMetadata?.trackDuration, 7200000);
      expect(nowPlaying.currentMetadata?.trackName, '白噪音');
    },
  );

  test(
    'recorded sounds use an asset source in single track loop mode',
    () async {
      final player = _RecordingAudioPlayer();
      final container = _createContainer(player);
      addTearDown(() async {
        container.dispose();
        await player.dispose();
      });

      await container
          .read(whiteNoiseControllerProvider.notifier)
          .startSound(WhiteNoiseCategory.water, WhiteNoiseSound.ocean);

      expect(player.loadedSource, isA<UriAudioSource>());
      expect((player.loadedSource! as UriAudioSource).uri.scheme, 'asset');
      expect(player.loadedLoopMode, LoopMode.one);
    },
  );

  test(
    'previous and next replace the source with the adjacent category',
    () async {
      final player = _RecordingAudioPlayer();
      final container = _createContainer(player);
      addTearDown(() async {
        container.dispose();
        await player.dispose();
      });
      final controller = container.read(whiteNoiseControllerProvider.notifier);

      await controller.start(WhiteNoiseCategory.noise);
      await controller.previous();
      expect(
        container.read(whiteNoiseControllerProvider)?.category,
        WhiteNoiseCategory.meditation,
      );

      await controller.next();
      expect(
        container.read(whiteNoiseControllerProvider)?.category,
        WhiteNoiseCategory.noise,
      );
      expect(player.playCount, 3);
    },
  );

  test('ordinary music metadata clears the white noise session', () async {
    final player = _RecordingAudioPlayer();
    final container = _createContainer(player);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    await container
        .read(whiteNoiseControllerProvider.notifier)
        .startSound(WhiteNoiseCategory.water, WhiteNoiseSound.ocean);
    expect(player.loadedLoopMode, LoopMode.one);
    container
        .read(nowPlayingDetailsProvider.notifier)
        .setNewMetadataList(
          newMetadataList: [
            MusicMetadata(trackName: 'Song', filePath: '/music/song.mp3'),
          ],
        );

    expect(container.read(whiteNoiseControllerProvider), isNull);
    expect(player.loadedLoopMode, LoopMode.off);
  });

  test('starting a session does not wait for playback to end', () async {
    final player = _RecordingAudioPlayer()..playCompleter = Completer<void>();
    final container = _createContainer(player);
    addTearDown(() async {
      player.playCompleter?.complete();
      container.dispose();
      await player.dispose();
    });

    await container
        .read(whiteNoiseControllerProvider.notifier)
        .start(WhiteNoiseCategory.noise)
        .timeout(const Duration(milliseconds: 200));

    expect(container.read(whiteNoiseControllerProvider), isNotNull);
    expect(player.playCount, 1);
  });
}
