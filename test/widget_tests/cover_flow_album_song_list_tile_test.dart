import 'package:classipod/features/music/cover_flow/widgets/cover_flow_album_song_list_tile.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CJK title and duration share one forced text line', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CoverFlowAlbumSongListTile(
            songName: '投身',
            songDuration: const Duration(minutes: 3, seconds: 26),
            isSelected: true,
            isCurrentlyPlaying: false,
            onTap: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('投身'));
    final duration = tester.widget<Text>(find.text('3:26'));

    expect(title.style?.fontFamily, 'sans-serif');
    expect(duration.style?.fontFamily, title.style?.fontFamily);
    expect(title.strutStyle?.forceStrutHeight, isTrue);
    expect(duration.strutStyle, title.strutStyle);
    expect(title.textHeightBehavior, duration.textHeightBehavior);
  });

  testWidgets('CJK collection title and creator share one forced text line', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SettingsListTile(
            text: '中文歌单',
            value: '日本語作者',
            isSelected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('中文歌单'));
    final creator = tester.widget<Text>(find.text('日本語作者'));

    expect(title.style?.fontFamily, 'sans-serif');
    expect(creator.style?.fontFamily, title.style?.fontFamily);
    expect(title.strutStyle?.forceStrutHeight, isTrue);
    expect(creator.strutStyle, title.strutStyle);
    expect(title.textHeightBehavior, creator.textHeightBehavior);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
