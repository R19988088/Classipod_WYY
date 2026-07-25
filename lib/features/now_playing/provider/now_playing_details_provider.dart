import 'dart:async';

import 'package:classipod/core/constants/constants.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/providers/filtered_audio_files_provider.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/playlist/providers/playlists_provider.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:just_audio/just_audio.dart';

final nowPlayingDetailsProvider =
    NotifierProvider<NowPlayingDetailsNotifier, NowPlayingModel>(
      NowPlayingDetailsNotifier.new,
    );

class NowPlayingDetailsNotifier extends Notifier<NowPlayingModel> {
  @override
  NowPlayingModel build() {
    final player = ref.read(audioPlayerProvider);
    final subscriptions = <StreamSubscription<dynamic>>[
      player.currentIndexStream.listen((newIndex) {
        if (newIndex != null &&
            newIndex != state.currentIndex &&
            newIndex >= 0 &&
            newIndex < state.metadataList.length) {
          state = state.copyWith(
            currentIndex: newIndex,
            currentMetadata: state.metadataList[newIndex],
          );
        }
      }),
      player.playingStream.listen((isPlaying) {
        if (isPlaying != state.isPlaying) {
          state = state.copyWith(isPlaying: isPlaying);
        }
      }),
      player.loopModeStream.listen((loopMode) {
        if (loopMode != state.loopMode) {
          state = state.copyWith(loopMode: loopMode);
        }
      }),
      player.shuffleModeEnabledStream.listen((isShuffleEnabled) {
        if (isShuffleEnabled != state.isShuffleEnabled) {
          state = state.copyWith(isShuffleEnabled: isShuffleEnabled);
        }
      }),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    return NowPlayingModel(
      currentIndex: 0,
      isPlaying: false,
      nowPlayingType: NowPlayingType.songs,
      metadataList: [],
      loopMode: LoopMode.off,
      isShuffleEnabled: false,
    );
  }

  void setNewMetadataList({
    NowPlayingType? nowPlayingType,
    required List<MusicMetadata> newMetadataList,
    int initialIndex = 0,
  }) {
    final currentIndex = newMetadataList.isEmpty
        ? 0
        : initialIndex.clamp(0, newMetadataList.length - 1);
    state = state.copyWith(
      currentIndex: currentIndex,
      nowPlayingType: nowPlayingType,
      currentMetadata: newMetadataList.isNotEmpty
          ? newMetadataList[currentIndex]
          : null,
      metadataList: newMetadataList,
    );
  }

  Future<void> setCurrentMetadataRating(int val) async {
    if (0 <= val && val <= 5 && state.currentMetadata != null) {
      final newMetadata = state.currentMetadata!.copyWith(rating: val);
      await updateMetadata(newMetadata);
    }
  }

  Future<void> increaseCurrentMetadataRating() async {
    final int? currentRating = state.currentMetadata?.rating;
    if (currentRating != null && currentRating < 5) {
      await setCurrentMetadataRating(currentRating + 1);
    }
  }

  Future<void> decreaseCurrentMetadataRating() async {
    final int? currentRating = state.currentMetadata?.rating;
    if (currentRating != null && currentRating > 0) {
      await setCurrentMetadataRating(currentRating - 1);
    }
  }

  Future<void> updateMetadata(MusicMetadata updatedMetadata) async {
    state = state.copyWith(
      currentMetadata:
          state.currentMetadata?.originalSongIndex ==
              updatedMetadata.originalSongIndex
          ? updatedMetadata
          : state.currentMetadata,
      metadataList: [
        for (final metadata in state.metadataList)
          if (metadata.originalSongIndex == updatedMetadata.originalSongIndex)
            updatedMetadata
          else
            metadata,
      ],
    );

    final Box<MusicMetadata> metadataBox = Hive.box<MusicMetadata>(
      Constants.metadataBoxName,
    );
    await metadataBox.putAt(updatedMetadata.originalSongIndex, updatedMetadata);
    ref.invalidate(filteredAudioFilesProvider);
    ref.invalidate(albumDetailsProvider);
    ref.invalidate(playlistsProvider);
  }
}
