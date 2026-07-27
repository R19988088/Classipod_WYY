import 'package:classipod/features/netease/screens/netease_recommendations_screen.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recommendation rows use the shared collection Hero contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(home: NeteaseRecommendationsScreen()),
      ),
    );

    final tags = tester
        .widgetList<SettingsListTile>(find.byType(SettingsListTile))
        .map((tile) => tile.heroTag)
        .whereType<String>()
        .toSet();
    expect(tags, {
      neteaseRecommendationHeroTag(NeteaseRecommendationKind.daily),
      neteaseRecommendationHeroTag(NeteaseRecommendationKind.privateRadar),
    });
    expect(find.byType(ListView), findsOneWidget);
  });
}
