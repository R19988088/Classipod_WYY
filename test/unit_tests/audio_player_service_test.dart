import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _RecordingAudioPlayer extends AudioPlayer {
  int? loadedInitialIndex;

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
}
