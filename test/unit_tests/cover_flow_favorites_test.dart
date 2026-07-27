import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local and Netease Cover Flow favorites remain independent', () {
    const local = CoverFlowAlbum(
      source: CoverFlowAlbumSource.local,
      id: 'local-id',
      title: 'Local Album',
      firstArtist: 'Local Artist',
    );
    const netease = CoverFlowAlbum(
      source: CoverFlowAlbumSource.netease,
      id: '42',
      title: 'Cloud Album',
      firstArtist: 'Cloud Artist',
    );
    var favorites = const CoverFlowFavorites();

    favorites = favorites.toggle(local).toggle(netease);

    expect(favorites.forSource(CoverFlowAlbumSource.local), [local]);
    expect(favorites.forSource(CoverFlowAlbumSource.netease), [netease]);
    expect(
      favorites.toggle(local).forSource(CoverFlowAlbumSource.local),
      isEmpty,
    );
    expect(favorites.toggle(local).forSource(CoverFlowAlbumSource.netease), [
      netease,
    ]);
  });

  test('favorites sort by first performer then album title', () {
    const albums = [
      CoverFlowAlbum(
        source: CoverFlowAlbumSource.netease,
        id: '3',
        title: 'Beta',
        firstArtist: 'Artist B',
      ),
      CoverFlowAlbum(
        source: CoverFlowAlbumSource.netease,
        id: '2',
        title: 'Zulu',
        firstArtist: 'Artist A',
      ),
      CoverFlowAlbum(
        source: CoverFlowAlbumSource.netease,
        id: '1',
        title: 'Alpha',
        firstArtist: 'Artist A',
      ),
    ];

    expect(sortCoverFlowAlbums(albums).map((album) => album.id), [
      '1',
      '2',
      '3',
    ]);
  });

  test('only the first performer participates in Cover Flow grouping', () {
    expect(CoverFlowAlbum.firstPerformer('Artist A / Artist B'), 'Artist A');
    expect(CoverFlowAlbum.firstPerformer('Solo Artist'), 'Solo Artist');
  });

  test('favorite descriptors survive JSON persistence', () {
    const favorites = CoverFlowFavorites(
      local: [
        CoverFlowAlbum(
          source: CoverFlowAlbumSource.local,
          id: 'local-id',
          title: 'Local Album',
          firstArtist: 'Local Artist',
          coverUri: '/cover.jpg',
        ),
      ],
      netease: [
        CoverFlowAlbum(
          source: CoverFlowAlbumSource.netease,
          id: '42',
          title: 'Cloud Album',
          firstArtist: 'Cloud Artist',
          coverUri: 'https://example.invalid/cover.jpg',
        ),
      ],
    );

    expect(CoverFlowFavorites.fromJson(favorites.toJson()), favorites);
  });

  test('playlist and podcast collection kinds survive persistence', () {
    const favorites = CoverFlowFavorites(
      netease: [
        CoverFlowAlbum(
          source: CoverFlowAlbumSource.netease,
          id: 'playlist-1',
          title: 'Mix',
          firstArtist: 'Creator',
          kind: CoverFlowCollectionKind.playlist,
        ),
        CoverFlowAlbum(
          source: CoverFlowAlbumSource.netease,
          id: 'podcast-1',
          title: 'Show',
          firstArtist: 'Host',
          kind: CoverFlowCollectionKind.podcast,
        ),
      ],
    );

    final restored = CoverFlowFavorites.fromJson(favorites.toJson());
    expect(restored.netease.map((album) => album.kind), [
      CoverFlowCollectionKind.playlist,
      CoverFlowCollectionKind.podcast,
    ]);
  });
}
