import 'dart:convert';

import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/features/backup/services/backup_service.dart';
import 'package:classipod/features/music/album/models/album_model.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/music/playlist/models/playlist_model.dart';
import 'package:classipod/features/music/playlist/providers/playlists_provider.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coverFlowFavoritesControllerProvider =
    NotifierProvider<CoverFlowFavoritesController, CoverFlowFavorites>(
      CoverFlowFavoritesController.new,
    );

final currentCoverFlowAlbumsProvider = Provider<List<CoverFlowAlbum>>((ref) {
  final source = ref.watch(
    settingsPreferencesControllerProvider.select((value) => value.musicSource),
  );
  final favorites = ref.watch(coverFlowFavoritesControllerProvider);
  final albums = favorites.forSource(
    source == MusicSource.local
        ? CoverFlowAlbumSource.local
        : CoverFlowAlbumSource.netease,
  );
  if (source != MusicSource.local) return albums;
  final playlists = ref.watch(playlistsProvider);
  return [
    for (final album in albums)
      if (album.kind != CoverFlowCollectionKind.playlist)
        album
      else
        album.copyWith(
          coverUri:
              album.coverUri ??
              playlists
                  .where((playlist) => localPlaylistId(playlist) == album.id)
                  .firstOrNull
                  ?.songs
                  .firstOrNull
                  ?.thumbnailPath,
        ),
  ];
});

final localCoverFlowAlbumModelsProvider = Provider<List<AlbumModel>>((ref) {
  final favorites = ref.watch(coverFlowFavoritesControllerProvider).local;
  final ids = favorites.map((album) => album.id).toSet();
  return ref
      .watch(albumDetailsProvider)
      .where(
        (album) => ids.contains(
          CoverFlowAlbum.localId(album.albumArtistName, album.albumName),
        ),
      )
      .toList();
});

final localCoverFlowPlaylistModelsProvider = Provider<List<PlaylistModel>>((
  ref,
) {
  final favorites = ref.watch(coverFlowFavoritesControllerProvider).local;
  final ids = favorites
      .where((album) => album.kind == CoverFlowCollectionKind.playlist)
      .map((album) => album.id)
      .toSet();
  return ref
      .watch(playlistsProvider)
      .where((playlist) => ids.contains(localPlaylistId(playlist)))
      .toList();
});

final localCoverFlowSongsProvider = Provider<List<MusicMetadata>>(
  (ref) => [
    for (final album in ref.watch(localCoverFlowAlbumModelsProvider))
      ...album.albumSongs,
    for (final playlist in ref.watch(localCoverFlowPlaylistModelsProvider))
      ...playlist.songs,
  ],
);

String localPlaylistId(PlaylistModel playlist) => playlist.key == null
    ? 'local-playlist-on-the-go'
    : 'local-playlist-${playlist.key}';

class CoverFlowFavoritesController extends Notifier<CoverFlowFavorites> {
  static const localKey = 'coverFlow.local';
  static const neteaseKey = 'coverFlow.netease';

  @override
  CoverFlowFavorites build() {
    final preferences = ref
        .read(sharedPreferencesWithCacheProvider)
        .requireValue;
    List<CoverFlowAlbum> read(String key) {
      final value = preferences.getString(key);
      if (value == null) return const [];
      try {
        return sortCoverFlowAlbums(
          (jsonDecode(value) as List<dynamic>).map(
            (item) =>
                CoverFlowAlbum.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      } on Object {
        return const [];
      }
    }

    return CoverFlowFavorites(local: read(localKey), netease: read(neteaseKey));
  }

  Future<bool> toggleLocal(AlbumModel album) => toggle(
    CoverFlowAlbum(
      source: CoverFlowAlbumSource.local,
      id: CoverFlowAlbum.localId(album.albumArtistName, album.albumName),
      title: album.albumName,
      firstArtist: CoverFlowAlbum.firstPerformer(album.albumArtistName),
      coverUri: album.albumArtPath,
    ),
  );

  Future<bool> toggleLocalPlaylist(PlaylistModel playlist) => toggle(
    CoverFlowAlbum(
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

  Future<bool> toggleNetease(NeteaseCollection album) => toggle(
    CoverFlowAlbum(
      source: CoverFlowAlbumSource.netease,
      id: album.id,
      title: album.title,
      firstArtist: CoverFlowAlbum.firstPerformer(album.subtitle),
      coverUri: album.coverUrl,
      kind: switch (album.kind) {
        NeteaseCollectionKind.album => CoverFlowCollectionKind.album,
        NeteaseCollectionKind.playlist => CoverFlowCollectionKind.playlist,
        NeteaseCollectionKind.podcast => CoverFlowCollectionKind.podcast,
      },
    ),
  );

  Future<void> hydrateNeteaseCovers(
    Iterable<NeteaseCollection> collections,
  ) async {
    final covers = {
      for (final collection in collections)
        '${collection.kind.name}:${collection.id}': collection.coverUrl,
    };
    var changed = false;
    final updated = <CoverFlowAlbum>[];
    for (final album in state.netease) {
      final cover = covers['${album.kind.name}:${album.id}'];
      if (cover != null && cover.isNotEmpty && album.coverUri != cover) {
        changed = true;
        updated.add(album.copyWith(coverUri: cover));
      } else {
        updated.add(album);
      }
    }
    if (!changed) return;
    state = CoverFlowFavorites(local: state.local, netease: updated);
    await ref
        .read(sharedPreferencesWithCacheProvider)
        .requireValue
        .setString(
          neteaseKey,
          jsonEncode(updated.map((item) => item.toJson()).toList()),
        );
  }

  Future<bool> toggle(CoverFlowAlbum album) async {
    state = state.toggle(album);
    final key = album.source == CoverFlowAlbumSource.local
        ? localKey
        : neteaseKey;
    await ref
        .read(sharedPreferencesWithCacheProvider)
        .requireValue
        .setString(
          key,
          jsonEncode(
            state.forSource(album.source).map((item) => item.toJson()).toList(),
          ),
        );
    await ref.read(backupServiceProvider).writeAutomaticBackup();
    return state.contains(album);
  }
}
