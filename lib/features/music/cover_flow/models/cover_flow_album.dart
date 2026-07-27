enum CoverFlowAlbumSource { local, netease }

enum CoverFlowCollectionKind { album, playlist, podcast }

class CoverFlowAlbum {
  const CoverFlowAlbum({
    required this.source,
    required this.id,
    required this.title,
    required this.firstArtist,
    this.coverUri,
    this.kind = CoverFlowCollectionKind.album,
  });

  final CoverFlowAlbumSource source;
  final String id;
  final String title;
  final String firstArtist;
  final String? coverUri;
  final CoverFlowCollectionKind kind;

  CoverFlowAlbum copyWith({String? coverUri}) => CoverFlowAlbum(
    source: source,
    id: id,
    title: title,
    firstArtist: firstArtist,
    coverUri: coverUri ?? this.coverUri,
    kind: kind,
  );

  String get heroTag => source == CoverFlowAlbumSource.netease
      ? '$title-$firstArtist'
      : 'cover-flow-${source.name}-${kind.name}-$id';

  static String localId(String firstArtist, String title) =>
      '${firstArtist.trim().toLowerCase()}\u0000${title.trim().toLowerCase()}';

  static String firstPerformer(String performers) =>
      performers.split(RegExp(r'\s*/\s*')).first.trim();

  Map<String, Object?> toJson() => {
    'source': source.name,
    'id': id,
    'title': title,
    'firstArtist': firstArtist,
    'coverUri': coverUri,
    'kind': kind.name,
  };

  factory CoverFlowAlbum.fromJson(Map<String, dynamic> json) => CoverFlowAlbum(
    source: CoverFlowAlbumSource.values.byName(json['source'] as String),
    id: json['id'] as String,
    title: json['title'] as String,
    firstArtist: firstPerformer(json['firstArtist'] as String),
    coverUri: json['coverUri'] as String?,
    kind: CoverFlowCollectionKind.values.byName(
      json['kind'] as String? ?? CoverFlowCollectionKind.album.name,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CoverFlowAlbum &&
      other.source == source &&
      other.kind == kind &&
      other.id == id;

  @override
  int get hashCode => Object.hash(source, kind, id);
}

List<CoverFlowAlbum> sortCoverFlowAlbums(Iterable<CoverFlowAlbum> albums) {
  final sorted = albums.toList();
  sorted.sort((a, b) {
    final artist = a.firstArtist.toLowerCase().compareTo(
      b.firstArtist.toLowerCase(),
    );
    if (artist != 0) return artist;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return sorted;
}

class CoverFlowFavorites {
  const CoverFlowFavorites({this.local = const [], this.netease = const []});

  final List<CoverFlowAlbum> local;
  final List<CoverFlowAlbum> netease;

  List<CoverFlowAlbum> forSource(CoverFlowAlbumSource source) =>
      source == CoverFlowAlbumSource.local ? local : netease;

  bool contains(CoverFlowAlbum album) =>
      forSource(album.source).contains(album);

  CoverFlowFavorites toggle(CoverFlowAlbum album) {
    final updated = [...forSource(album.source)];
    if (!updated.remove(album)) updated.add(album);
    final sorted = sortCoverFlowAlbums(updated);
    return album.source == CoverFlowAlbumSource.local
        ? CoverFlowFavorites(local: sorted, netease: netease)
        : CoverFlowFavorites(local: local, netease: sorted);
  }

  Map<String, Object> toJson() => {
    'local': local.map((album) => album.toJson()).toList(),
    'netease': netease.map((album) => album.toJson()).toList(),
  };

  factory CoverFlowFavorites.fromJson(Map<String, dynamic> json) {
    List<CoverFlowAlbum> decode(String key) => sortCoverFlowAlbums(
      (json[key] as List<dynamic>? ?? const []).map(
        (value) =>
            CoverFlowAlbum.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    return CoverFlowFavorites(
      local: decode('local'),
      netease: decode('netease'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoverFlowFavorites &&
      _listsEqual(other.local, local) &&
      _listsEqual(other.netease, netease);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(local), Object.hashAll(netease));

  static bool _listsEqual(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
