import 'dart:async';

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/songs/widgets/condensed_song_list_tile.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NeteaseTracksScreen extends ConsumerStatefulWidget {
  const NeteaseTracksScreen({
    super.key,
    this.collection,
    this.artist,
    this.privateRadar = false,
  }) : assert(collection != null || artist != null || privateRadar);

  final NeteaseCollection? collection;
  final NeteaseArtist? artist;
  final bool privateRadar;

  @override
  ConsumerState<NeteaseTracksScreen> createState() =>
      _NeteaseTracksScreenState();
}

class _NeteaseTracksScreenState extends ConsumerState<NeteaseTracksScreen>
    with CustomScreen {
  List<NeteaseTrack> _tracks = const [];
  String? _error;
  bool _loading = true;
  bool _startingPlayback = false;
  NeteaseCollection? _resolvedCollection;

  NeteaseCollection? get _collection =>
      _resolvedCollection ?? widget.collection;

  @override
  String get routeName => widget.privateRadar
      ? Routes.neteaseRadar.name
      : widget.artist == null
      ? Routes.neteaseTracks.name
      : Routes.artistTracks.name;

  @override
  List<Object?> get displayItems => _tracks.isEmpty ? const [null] : _tracks;

  @override
  Future<void> onSelectPressed() async {
    if (_tracks.isEmpty) {
      await _load();
    } else {
      await _play(selectedDisplayItem);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(neteaseServiceProvider);
      if (widget.privateRadar) {
        _resolvedCollection = await service.privateRadar();
      }
      final tracks = widget.artist == null
          ? await service.tracks(_collection!)
          : await service.artistSongs(widget.artist!.id);
      if (mounted) setState(() => _tracks = tracks);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(int index) async {
    if (_startingPlayback) return;
    setState(() {
      selectedDisplayItem = index;
      _startingPlayback = true;
      _error = null;
    });
    try {
      final targetId = int.parse(_tracks[index].id);
      final currentId = ref
          .read(nowPlayingDetailsProvider)
          .currentMetadata
          ?.originalSongIndex;
      if (currentId == targetId) {
        if (mounted) await context.pushNamed(Routes.nowPlaying.name);
        return;
      }
      final settings = ref.read(settingsPreferencesControllerProvider);
      final tracksToResolve = widget.artist == null
          ? _tracks
          : [_tracks[index]];
      final metadata = await ref
          .read(neteaseServiceProvider)
          .playableTracks(
            tracksToResolve,
            preferredTrackId: _tracks[index].id,
            format: settings.neteaseAudioFormat,
            mp3Bitrate: settings.neteaseMp3Bitrate,
            flacQuality: settings.neteaseFlacQuality,
          );
      final playableIndex = metadata.indexWhere(
        (item) => item.originalSongIndex == targetId,
      );
      if (playableIndex < 0) throw StateError('该曲目当前账号无播放权限');
      final player = ref.read(audioPlayerServiceProvider.notifier);
      await player.setAudioSource(
        nowPlayingType:
            widget.artist != null ||
                _collection!.kind == NeteaseCollectionKind.album
            ? NowPlayingType.album
            : NowPlayingType.playlist,
        musicMetadataList: metadata,
        initialIndex: playableIndex,
      );
      await player.setShuffleMode(false);
      unawaited(player.play());
      if (mounted) await context.pushNamed(Routes.nowPlaying.name);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _startingPlayback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: widget.artist?.name ?? _collection?.title ?? '私人雷达'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          Expanded(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length,
                prototypeItem: const CondensedSongListTile(
                  songName: '',
                  isSelected: false,
                  isCurrentlyPlaying: false,
                ),
                itemBuilder: (context, index) {
                  if (_tracks.isEmpty) {
                    return CondensedSongListTile(
                      songName: _loading ? '正在加载…' : _error ?? '暂无曲目',
                      isSelected: true,
                      isCurrentlyPlaying: false,
                      onTap: () => unawaited(_load()),
                    );
                  }
                  return CondensedSongListTile(
                    songName: _startingPlayback && index == selectedDisplayItem
                        ? '正在准备：${_tracks[index].title}'
                        : _tracks[index].title,
                    isSelected: selectedDisplayItem == index,
                    isCurrentlyPlaying: false,
                    onTap: () => unawaited(_play(index)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
