import 'package:classipod/features/music/album/models/album_model.dart';
import 'package:classipod/features/music/album/widgets/album_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('album cover uses the supplied Hero tag', (tester) async {
    const heroTag = 'album-hero';
    await tester.pumpWidget(
      CupertinoApp(
        home: AlbumListTile(
          albumDetails: AlbumModel(
            albumName: 'Album',
            albumArtistName: 'Artist',
            albumSongs: const [],
          ),
          isSelected: true,
          heroTag: heroTag,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );

    expect(find.byType(Hero), findsOneWidget);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, heroTag);
  });
}
