import 'package:classipod/core/widgets/marquee_text.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('title and value use fixed 7:3 scrolling columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: SizedBox(
          width: 300,
          child: SettingsListTile(
            text: 'A very long title that must scroll',
            value: 'A very long artist that must scroll',
            isSelected: false,
            onTap: _noop,
          ),
        ),
      ),
    );

    final columns = tester.widgetList<Expanded>(find.byType(Expanded)).toList();
    final marquee = tester
        .widgetList<MarqueeText>(find.byType(MarqueeText))
        .toList();

    expect(columns.map((column) => column.flex), [7, 3]);
    expect(marquee, hasLength(2));
    expect(marquee[0].style?.fontSize, 16);
    expect(marquee[1].style?.fontSize, 16);
    expect(marquee[1].textAlign, TextAlign.right);
    expect(find.byType(FittedBox), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _noop() {}
