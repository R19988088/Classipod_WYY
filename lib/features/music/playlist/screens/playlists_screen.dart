import 'dart:async';

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/music/playlist/models/playlist_model.dart';
import 'package:classipod/features/music/playlist/providers/playlists_provider.dart';
import 'package:classipod/features/music/playlist/widgets/playlist_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen>
    with CustomScreen {
  @override
  double get displayTileHeight => 54;

  @override
  String get routeName => Routes.playlists.name;

  @override
  List<PlaylistModel> get displayItems => ref.watch(playlistsProvider);

  @override
  Future<void> onSelectPressed() =>
      _navigateToPlaylistSongsScreen(selectedDisplayItem);

  @override
  Future<void> onSelectLongPress() => _toggleCoverFlow(selectedDisplayItem);

  Future<void> _toggleCoverFlow(int index) async {
    await ref.read(deviceButtonsServiceProvider.notifier).buttonPressVibrate();
    await ref
        .read(coverFlowFavoritesControllerProvider.notifier)
        .toggleLocalPlaylist(displayItems[index]);
  }

  Future<void> _navigateToPlaylistSongsScreen(int displayIndex) async {
    setState(() => selectedDisplayItem = displayIndex);
    final playlist = displayItems[displayIndex];
    await context.pushNamed(
      Routes.coverFlowSelection.name,
      extra: CoverFlowAlbum(
        source: CoverFlowAlbumSource.local,
        id: localPlaylistId(playlist),
        title: playlist.name,
        firstArtist: playlist.songs.isEmpty
            ? ''
            : CoverFlowAlbum.firstPerformer(
                playlist.songs.first.getMainArtistName,
              ),
        coverUri: playlist.songs.firstOrNull?.thumbnailPath,
        kind: CoverFlowCollectionKind.playlist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = ref
        .watch(coverFlowFavoritesControllerProvider)
        .local
        .where((album) => album.kind == CoverFlowCollectionKind.playlist)
        .map((album) => album.id)
        .toSet();
    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: Routes.playlists.title(context)),
          Flexible(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length,
                prototypeItem: PlaylistListTile(
                  playlistModel: PlaylistModel(name: '', songs: []),
                  isSelected: false,
                  onTap: () {},
                ),
                itemBuilder: (context, index) => PlaylistListTile(
                  playlistModel: displayItems[index],
                  isSelected: selectedDisplayItem == index,
                  onTap: () async => _navigateToPlaylistSongsScreen(index),
                  onLongPress: () => _toggleCoverFlow(index),
                  coverUri:
                      displayItems[index].songs.firstOrNull?.thumbnailPath,
                  heroTag: CoverFlowAlbum(
                    source: CoverFlowAlbumSource.local,
                    id: localPlaylistId(displayItems[index]),
                    title: displayItems[index].name,
                    firstArtist: displayItems[index].songs.isEmpty
                        ? ''
                        : CoverFlowAlbum.firstPerformer(
                            displayItems[index].songs.first.getMainArtistName,
                          ),
                    coverUri:
                        displayItems[index].songs.firstOrNull?.thumbnailPath,
                    kind: CoverFlowCollectionKind.playlist,
                  ).heroTag,
                  isCoverFlowFavorite: favoriteIds.contains(
                    localPlaylistId(displayItems[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
