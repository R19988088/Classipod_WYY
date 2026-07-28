import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:classipod/core/constants/constants.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/procedural_audio_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

const Duration whiteNoiseSessionDuration = Duration(hours: 2);

class WhiteNoiseSession {
  const WhiteNoiseSession({
    required this.category,
    required this.sound,
    required this.startedAt,
  });

  final WhiteNoiseCategory category;
  final WhiteNoiseSound sound;
  final DateTime startedAt;
}

final whiteNoiseRandomProvider = Provider<Random>((ref) => Random());
final whiteNoiseConfiguredLoopModeProvider = Provider<LoopMode>(
  (ref) =>
      ref.watch(settingsPreferencesControllerProvider).repeatMode.toLoopMode(),
);

final whiteNoiseControllerProvider =
    NotifierProvider<WhiteNoiseController, WhiteNoiseSession?>(
      WhiteNoiseController.new,
    );

class WhiteNoiseController extends Notifier<WhiteNoiseSession?> {
  @override
  WhiteNoiseSession? build() {
    ref.listen(
      nowPlayingDetailsProvider.select(
        (details) => details.currentMetadata?.filePath,
      ),
      (_, filePath) {
        if (state != null && !_isWhiteNoisePath(filePath)) {
          state = null;
          unawaited(
            ref
                .read(audioPlayerProvider)
                .setLoopMode(ref.read(whiteNoiseConfiguredLoopModeProvider)),
          );
        }
      },
    );
    return null;
  }

  Future<void> start(WhiteNoiseCategory category) async {
    final sound = resolveWhiteNoiseSound(
      category,
      ref.read(whiteNoiseRandomProvider),
    );
    await startSound(category, sound);
  }

  Future<void> startSound(
    WhiteNoiseCategory category,
    WhiteNoiseSound sound,
  ) async {
    if (!category.sounds.contains(sound)) {
      throw ArgumentError('$sound does not belong to $category');
    }

    final random = ref.read(whiteNoiseRandomProvider);
    final metadata = _metadata(category, sound);
    final mediaItem = MediaItem(
      id: 'white-noise-${category.name}-${sound.name}',
      title: sound.title,
      album: category.title,
      artist: '白噪音',
      duration: whiteNoiseSessionDuration,
      artUri: Uri.parse(Constants.defaultNotificationAlbumArtImageUrl),
    );
    final AudioSource source = sound.isRecorded
        ? AudioSource.asset(sound.assetPath!, tag: mediaItem)
        : ProceduralAudioSource(
            sound,
            seed: random.nextInt(0x7fffffff),
            tag: mediaItem,
          );
    final playerService = ref.read(audioPlayerServiceProvider.notifier);

    await playerService.setCustomAudioSource(
      audioSource: source,
      metadata: metadata,
    );
    await playerService.setLoopMode(
      sound.isRecorded ? LoopMode.one : LoopMode.off,
    );
    ref.read(sleepTimerControllerProvider.notifier).start(120);
    state = WhiteNoiseSession(
      category: category,
      sound: sound,
      startedAt: DateTime.now(),
    );
    unawaited(playerService.play());
  }

  Future<void> reroll() async {
    final current = state;
    if (current == null) return;

    final alternatives = current.category.sounds
        .where((sound) => sound != current.sound)
        .toList();
    final sound = alternatives.isEmpty
        ? current.sound
        : alternatives[ref
              .read(whiteNoiseRandomProvider)
              .nextInt(alternatives.length)];
    await startSound(current.category, sound);
  }

  Future<void> next() async {
    await start(
      nextWhiteNoiseCategory(state?.category ?? WhiteNoiseCategory.noise),
    );
  }

  Future<void> previous() async {
    await start(
      previousWhiteNoiseCategory(state?.category ?? WhiteNoiseCategory.noise),
    );
  }

  MusicMetadata _metadata(WhiteNoiseCategory category, WhiteNoiseSound sound) {
    return MusicMetadata(
      trackName: sound.title,
      trackArtistNames: const ['白噪音'],
      albumName: category.title,
      albumArtistName: '白噪音',
      trackDuration: whiteNoiseSessionDuration.inMilliseconds,
      filePath: sound.assetPath ?? 'procedural://${sound.name}',
      thumbnailPath: category.imagePath,
    );
  }

  bool _isWhiteNoisePath(String? path) {
    return path?.startsWith('procedural://') == true ||
        path?.startsWith('assets/audio/white_noise/') == true;
  }
}
