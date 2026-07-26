import 'dart:async';

import 'package:classipod/core/constants/app_palette.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/widgets/marquee_text.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/album/models/album_model.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/music/cover_flow/widgets/cover_flow_album_song_list_tile.dart';
import 'package:classipod/features/music/playlist/models/playlist_model.dart';
import 'package:classipod/features/music/playlist/providers/playlists_provider.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CoverFlowAlbumSelectionScreen extends ConsumerStatefulWidget {
  const CoverFlowAlbumSelectionScreen({super.key, required this.album});

  final CoverFlowAlbum album;

  @override
  ConsumerState createState() => _CoverFlowAlbumSelectionScreenState();
}

class _CoverFlowAlbumSelectionScreenState
    extends ConsumerState<CoverFlowAlbumSelectionScreen>
    with CustomScreen {
  AlbumModel? _localAlbum;
  PlaylistModel? _localPlaylist;
  List<NeteaseTrack> _neteaseTracks = const [];
  String? _error;
  bool _loading = false;
  bool _startingPlayback = false;
  static final Map<String, List<NeteaseTrack>> _tracksMemoryCache = {};
  StreamSubscription<Duration>? _positionSubscription;
  int _lastSavedSecond = -1;

  String get _memoryKey =>
      'cover-flow-memory.${widget.album.source.name}.${widget.album.kind.name}.${widget.album.id}';

  bool get _isLocal => widget.album.source == CoverFlowAlbumSource.local;
  bool get _isLocalPlaylist =>
      _isLocal && widget.album.kind == CoverFlowCollectionKind.playlist;

  @override
  int get topStatusBarHeight => 60;

  @override
  String get routeName => Routes.coverFlowSelection.name;

  @override
  List<Object?> get displayItems {
    final items = _isLocal
        ? (_isLocalPlaylist ? _localPlaylist?.songs : _localAlbum?.albumSongs)
        : _neteaseTracks;
    return items == null || items.isEmpty ? const [null] : items;
  }

  @override
  Future<void> onSelectPressed() async {
    if (displayItems.first == null) {
      if (!_isLocal) await _loadNeteaseTracks();
      return;
    }
    await _play(selectedDisplayItem);
  }

  @override
  void initState() {
    super.initState();
    _positionSubscription = ref.read(audioPlayerProvider).positionStream.listen(
      (position) {
        final second = position.inSeconds;
        if (second == _lastSavedSecond) return;
        _lastSavedSecond = second;
        unawaited(
          ref
              .read(sharedPreferencesWithCacheProvider)
              .requireValue
              .setInt('$_memoryKey.position', second),
        );
      },
    );
    if (_isLocal) {
      final matches = ref
          .read(albumDetailsProvider)
          .where(
            (album) =>
                CoverFlowAlbum.localId(
                  album.albumArtistName,
                  album.albumName,
                ) ==
                widget.album.id,
          );
      _localAlbum = matches.firstOrNull;
      if (_isLocalPlaylist) {
        _localPlaylist = ref
            .read(playlistsProvider)
            .where((playlist) => localPlaylistId(playlist) == widget.album.id)
            .firstOrNull;
      }
      _restoreLastIndex();
    } else {
      unawaited(_loadNeteaseTracks());
    }
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  NeteaseCollection get _neteaseCollection => NeteaseCollection(
    id: widget.album.id,
    kind: switch (widget.album.kind) {
      CoverFlowCollectionKind.album => NeteaseCollectionKind.album,
      CoverFlowCollectionKind.playlist => NeteaseCollectionKind.playlist,
      CoverFlowCollectionKind.podcast => NeteaseCollectionKind.podcast,
    },
    title: widget.album.title,
    subtitle: widget.album.firstArtist,
    coverUrl: widget.album.coverUri ?? '',
  );

  Future<void> _loadNeteaseTracks() async {
    if (_loading) return;
    final cacheKey = '${_neteaseCollection.kind.name}:${_neteaseCollection.id}';
    final cachedTracks = _tracksMemoryCache[cacheKey];
    if (cachedTracks != null) {
      if (mounted) setState(() => _neteaseTracks = cachedTracks);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await ref
          .read(neteaseServiceProvider)
          .tracks(_neteaseCollection);
      _tracksMemoryCache[cacheKey] = tracks;
      if (mounted) {
        setState(() => _neteaseTracks = tracks);
        _restoreLastIndex();
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _restoreLastIndex() {
    final saved = ref
        .read(sharedPreferencesWithCacheProvider)
        .requireValue
        .getInt('$_memoryKey.index');
    if (saved != null && displayItems.isNotEmpty) {
      selectedDisplayItem = saved.clamp(0, displayItems.length - 1);
    }
  }

  Future<void> _play(int index) async {
    if (_startingPlayback) return;
    setState(() {
      selectedDisplayItem = index;
      _error = null;
      _startingPlayback = true;
    });
    unawaited(
      ref
          .read(sharedPreferencesWithCacheProvider)
          .requireValue
          .setInt('$_memoryKey.index', index),
    );
    try {
      if (_isLocal) {
        final currentId = ref
            .read(nowPlayingDetailsProvider)
            .currentMetadata
            ?.originalSongIndex;
        final targetId = displayItems[index] is MusicMetadata
            ? (displayItems[index] as MusicMetadata).originalSongIndex
            : null;
        if (currentId != null && currentId == targetId) {
          if (mounted) await context.pushNamed(Routes.nowPlaying.name);
          return;
        }
        if (_isLocalPlaylist) {
          await ref
              .read(audioPlayerServiceProvider.notifier)
              .playPlaylist(playlistDetail: _localPlaylist!, songIndex: index);
        } else {
          await ref
              .read(audioPlayerServiceProvider.notifier)
              .playAlbum(albumDetail: _localAlbum!, songIndex: index);
        }
      } else {
        final currentId = ref
            .read(nowPlayingDetailsProvider)
            .currentMetadata
            ?.originalSongIndex;
        final targetId = int.parse(_neteaseTracks[index].id);
        if (currentId == targetId) {
          if (mounted) await context.pushNamed(Routes.nowPlaying.name);
          return;
        }
        final settings = ref.read(settingsPreferencesControllerProvider);
        final metadata = await ref
            .read(neteaseServiceProvider)
            .playableTracks(
              _neteaseTracks,
              preferredTrackId: _neteaseTracks[index].id,
              format: settings.neteaseAudioFormat,
              mp3Bitrate: settings.neteaseMp3Bitrate,
              flacQuality: settings.neteaseFlacQuality,
            );
        final playableIndex = metadata.indexWhere(
          (item) => item.originalSongIndex == targetId,
        );
        if (playableIndex < 0) throw StateError('该曲目当前账号无播放权限');
        final coverMetadata =
            _neteaseCollection!.kind == NeteaseCollectionKind.playlist
            ? metadata
                  .map(
                    (item) => item.copyWith(
                      albumName: _neteaseCollection!.title,
                      albumArtistName: CoverFlowAlbum.firstPerformer(
                        _neteaseCollection!.subtitle,
                      ),
                    ),
                  )
                  .toList()
            : metadata;
        final player = ref.read(audioPlayerServiceProvider.notifier);
        await player.setAudioSource(
          nowPlayingType: NowPlayingType.album,
          musicMetadataList: coverMetadata,
          initialIndex: playableIndex,
        );
        await player.setShuffleMode(false);
        unawaited(player.play());
      }
      final savedPosition = ref
          .read(sharedPreferencesWithCacheProvider)
          .requireValue
          .getInt('$_memoryKey.position');
      if (savedPosition != null && savedPosition > 0) {
        await ref
            .read(audioPlayerProvider)
            .seek(Duration(seconds: savedPosition));
      }
      if (mounted) {
        await context.pushNamed(Routes.nowPlaying.name);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _startingPlayback = false);
    }
  }

  String _titleAt(int index) {
    if (_startingPlayback && index == selectedDisplayItem) {
      final title = switch (displayItems[index]) {
        final MusicMetadata metadata => metadata.getTrackName,
        final NeteaseTrack track => track.title,
        _ => '',
      };
      return '正在准备：$title';
    }
    if (displayItems[index] case final MusicMetadata metadata) {
      return metadata.getTrackName;
    }
    if (displayItems[index] case final NeteaseTrack track) return track.title;
    return _loading ? '正在加载…' : _error ?? '暂无曲目';
  }

  int _durationAt(int index) {
    if (displayItems[index] case final MusicMetadata metadata) {
      return metadata.getTrackDuration;
    }
    if (displayItems[index] case final NeteaseTrack track) {
      return track.durationMs;
    }
    return 0;
  }

  int? _originalIndexAt(int index) {
    if (displayItems[index] case final MusicMetadata metadata) {
      return metadata.originalSongIndex;
    }
    if (displayItems[index] case final NeteaseTrack track) {
      return int.tryParse(track.id);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingOriginalIndex = ref
        .watch(
          nowPlayingDetailsProvider.select((value) => value.currentMetadata),
        )
        ?.originalSongIndex;
    return Hero(
      tag: widget.album.heroTag,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 10, 40, 0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: CupertinoColors.white,
            border: Border.all(),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: .16),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 50,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppPalette.selectedTileGradientColor1,
                        AppPalette.selectedTileGradientColor2,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                          ),
                          maxLines: 1,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: MarqueeText(
                                widget.album.firstArtist,
                                mode: TextScrollMode.bouncing,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${displayItems.length} 首',
                              style: const TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              Flexible(
                child: CupertinoScrollbar(
                  controller: scrollController,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: displayItems.length,
                    prototypeItem: CoverFlowAlbumSongListTile(
                      songName: '',
                      songDuration: Duration.zero,
                      isSelected: false,
                      isCurrentlyPlaying: false,
                      onTap: () {},
                    ),
                    itemBuilder: (context, index) => CoverFlowAlbumSongListTile(
                      songName: _titleAt(index),
                      songDuration: Duration(milliseconds: _durationAt(index)),
                      isSelected: selectedDisplayItem == index,
                      isCurrentlyPlaying:
                          currentlyPlayingOriginalIndex ==
                          _originalIndexAt(index),
                      onTap: () => displayItems[index] == null
                          ? unawaited(_loadNeteaseTracks())
                          : unawaited(_play(index)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
