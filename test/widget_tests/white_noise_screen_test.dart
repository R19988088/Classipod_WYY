import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/now_playing/widgets/album_reflective_art.dart';
import 'package:classipod/features/white_noise/controllers/white_noise_controller.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/screens/white_noise_player_screen.dart';
import 'package:classipod/features/white_noise/screens/white_noise_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class _NowPlayingController extends NowPlayingDetailsNotifier {
  @override
  NowPlayingModel build() => NowPlayingModel(
    currentIndex: 0,
    isPlaying: false,
    nowPlayingType: NowPlayingType.songs,
    metadataList: const [],
    isShuffleEnabled: false,
    loopMode: LoopMode.off,
  );
}

class _WhiteNoiseController extends WhiteNoiseController {
  int rerollCount = 0;

  @override
  WhiteNoiseSession? build() => WhiteNoiseSession(
    category: WhiteNoiseCategory.rain,
    sound: WhiteNoiseSound.drizzle,
    startedAt: DateTime(2026, 7, 27),
  );

  @override
  Future<void> reroll() async {
    rerollCount++;
  }
}

class _DeviceButtonsController extends DeviceButtonsServiceNotifier {
  @override
  DeviceAction? build() => null;

  set action(DeviceAction action) => state = action;
}

void main() {
  testWidgets('all recorded loops are included in the Flutter asset bundle', (
    tester,
  ) async {
    for (final sound in WhiteNoiseSound.values.where(
      (sound) => sound.isRecorded,
    )) {
      final bytes = await rootBundle.load(sound.assetPath!);
      expect(bytes.lengthInBytes, greaterThan(400000));
    }
  });

  testWidgets('every category has a distinct bundled cover', (tester) async {
    expect(
      WhiteNoiseCategory.values.map((category) => category.imagePath).toSet(),
      hasLength(WhiteNoiseCategory.values.length),
    );
    for (final category in WhiteNoiseCategory.values) {
      final bytes = await rootBundle.load(category.imagePath);
      expect(bytes.lengthInBytes, greaterThan(1000));
    }
  });

  testWidgets('shows exactly nine category entries with stable Hero tags', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowPlayingDetailsProvider.overrideWith(_NowPlayingController.new),
        ],
        child: const CupertinoApp(home: WhiteNoiseScreen()),
      ),
    );
    await tester.pump();

    for (final category in WhiteNoiseCategory.values) {
      expect(find.text(category.title), findsOneWidget);
    }
    expect(
      tester.widgetList<Hero>(find.byType(Hero)).map((hero) => hero.tag),
      WhiteNoiseCategory.values.map((category) => category.heroTag),
    );
  });

  testWidgets('player reuses the category Hero tag with a flip entrance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowPlayingDetailsProvider.overrideWith(_NowPlayingController.new),
          whiteNoiseControllerProvider.overrideWith(_WhiteNoiseController.new),
        ],
        child: const CupertinoApp(home: WhiteNoisePlayerScreen()),
      ),
    );
    await tester.pump();

    final artwork = tester.widget<AlbumReflectiveArt>(
      find.byType(AlbumReflectiveArt),
    );
    expect(artwork.heroTag, WhiteNoiseCategory.rain.heroTag);
    expect(artwork.flipOnEnter, isTrue);
    expect(artwork.assetPath, WhiteNoiseCategory.rain.imagePath);
  });

  testWidgets('center button randomizes the current category once', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: Routes.whiteNoisePlayer.toString(),
      routes: [
        GoRoute(
          path: Routes.whiteNoisePlayer.toString(),
          name: Routes.whiteNoisePlayer.name,
          builder: (_, _) => const WhiteNoisePlayerScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowPlayingDetailsProvider.overrideWith(_NowPlayingController.new),
          whiteNoiseControllerProvider.overrideWith(_WhiteNoiseController.new),
          deviceButtonsServiceProvider.overrideWith(
            _DeviceButtonsController.new,
          ),
        ],
        child: CupertinoApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WhiteNoisePlayerScreen)),
    );
    final controller =
        container.read(whiteNoiseControllerProvider.notifier)
            as _WhiteNoiseController;
    final buttons =
        container.read(deviceButtonsServiceProvider.notifier)
            as _DeviceButtonsController;

    buttons.action = DeviceAction.select;
    await tester.pump();

    expect(controller.rerollCount, 1);
  });
}
