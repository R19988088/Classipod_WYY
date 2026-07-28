import 'package:classipod/features/now_playing/widgets/album_reflective_art.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cover and reflection use one proportional geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 150,
            height: 200,
            child: AlbumReflectiveArt(
              imageWidth: 200,
              heroTag: 'geometry-test',
            ),
          ),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    expect(images.first.width, images.last.width);
    expect(images.first.fit, BoxFit.cover);
    expect(images.last.fit, BoxFit.cover);
    expect(images.last.height, images.first.height! / 3);
  });
}
