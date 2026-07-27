import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/providers/filtered_audio_files_provider.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/music/album/models/album_model.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/album/widgets/album_list_tile.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AlbumsSelectionScreen extends ConsumerStatefulWidget {
  const AlbumsSelectionScreen({super.key});

  @override
  ConsumerState createState() => _AlbumsSelectionScreenState();
}

class _AlbumsSelectionScreenState extends ConsumerState<AlbumsSelectionScreen>
    with CustomScreen {
  @override
  double get displayTileHeight => 54;

  @override
  int get extraDisplayItems => 1;

  @override
  String get routeName => Routes.albums.name;

  @override
  List<AlbumModel> get displayItems => ref.read(albumDetailsProvider);

  @override
  Future<void> onSelectPressed() async =>
      _navigateToAlbumSelectionScreen(selectedDisplayItem);

  @override
  Future<void> onSelectLongPress() => _toggleCoverFlow(selectedDisplayItem);

  Future<void> _toggleCoverFlow(int index) async {
    setState(() => selectedDisplayItem = index);
    if (index == 0) return;
    await ref
        .read(coverFlowFavoritesControllerProvider.notifier)
        .toggleLocal(displayItems[index - 1]);
  }

  void _navigateToAlbumSelectionScreen(int index) {
    setState(() => selectedDisplayItem = index);
    if (index == 0) {
      context.goNamed(
        Routes.albumSongs.name,
        extra: AlbumModel(
          albumName: context.localization.allAlbums,
          albumArtistName: "",
          albumSongs: ref.read(filteredAudioFilesProvider).requireValue,
        ),
      );
    } else {
      final album = displayItems[index - 1];
      unawaited(
        context.pushNamed(
          Routes.coverFlowSelection.name,
          extra: CoverFlowAlbum(
            source: CoverFlowAlbumSource.local,
            id: CoverFlowAlbum.localId(album.albumArtistName, album.albumName),
            title: album.albumName,
            firstArtist: CoverFlowAlbum.firstPerformer(album.albumArtistName),
            coverUri: album.albumArtPath,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = ref
        .watch(coverFlowFavoritesControllerProvider)
        .local
        .map((album) => album.id)
        .toSet();
    if (displayItems.isEmpty) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: Routes.albums.title(context)),
            Expanded(
              child: EmptyStateWidget(
                emptyDescription: context.localization.noAlbumsFound,
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: Routes.albums.title(context)),
          Flexible(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length + 1,
                prototypeItem: AlbumListTile(
                  albumDetails: AlbumModel(
                    albumName: '',
                    albumArtistName: '',
                    albumSongs: [],
                  ),
                  isSelected: false,
                  onTap: () {},
                  onLongPress: () {},
                ),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final allSongs = ref
                        .read(filteredAudioFilesProvider)
                        .requireValue;
                    return AlbumListTile(
                      albumDetails: AlbumModel(
                        albumName: context.localization.allSongs,
                        albumArtistName: context.localization.nSongs(
                          allSongs.length,
                        ),
                        albumSongs: allSongs,
                      ),
                      isSelected: selectedDisplayItem == 0,
                      isAllSongsAlbum: true,
                      onTap: () async => _navigateToAlbumSelectionScreen(0),
                      onLongPress: () {},
                    );
                  }

                  return AlbumListTile(
                    albumDetails: displayItems[index - 1],
                    heroTag: CoverFlowAlbum(
                      source: CoverFlowAlbumSource.local,
                      id: CoverFlowAlbum.localId(
                        displayItems[index - 1].albumArtistName,
                        displayItems[index - 1].albumName,
                      ),
                      title: displayItems[index - 1].albumName,
                      firstArtist: CoverFlowAlbum.firstPerformer(
                        displayItems[index - 1].albumArtistName,
                      ),
                    ).heroTag,
                    isCoverFlowFavorite: favoriteIds.contains(
                      CoverFlowAlbum.localId(
                        displayItems[index - 1].albumArtistName,
                        displayItems[index - 1].albumName,
                      ),
                    ),
                    isSelected: selectedDisplayItem == index,
                    onTap: () async => _navigateToAlbumSelectionScreen(index),
                    onLongPress: () async {
                      await ref
                          .read(deviceButtonsServiceProvider.notifier)
                          .buttonPressVibrate();
                      await _toggleCoverFlow(index);
                    },
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
