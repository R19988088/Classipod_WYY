// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:classipod/classipod_app.dart';
import 'package:classipod/core/extensions/go_router_extensions.dart';
import 'package:classipod/core/models/device_directory.dart';
import 'package:classipod/core/navigation/page_not_found_screen.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/providers/device_directory_provider.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/features/app_startup/controllers/app_startup_controller.dart';
import 'package:classipod/features/app_startup/screens/app_startup_screen.dart';
import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ProviderContainer providerContainer = ProviderContainer(
    overrides: [
      deviceDirectoryProvider.overrideWith(
        (_) => DeviceDirectory(
          documentsDirectory: Directory(
            "${Directory.current.path}/test/test_files",
          ),
        ),
      ),
      appStartupControllerProvider.overrideWith((ref) async {
        await ref.read(deviceDirectoryProvider.future);
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        await ref.read(sharedPreferencesWithCacheProvider.future);
        ref
            .read(settingsPreferencesControllerProvider.notifier)
            .setAudioSource(isOnlineAudioSource: false);
      }),
    ],
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return "${Directory.current.path}/test/test_files";
          },
        );
  });

  testWidgets('Initial Location is Splash', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const AppStartupScreen(app: ClassipodApp()),
      ),
    );
    await tester.pumpAndSettle();

    expect('splash', providerContainer.read(routerProvider).locationNamed);
  });

  test('Netease library route keeps the category in one route level', () {
    expect(
      providerContainer
          .read(routerProvider)
          .namedLocation(
            Routes.neteaseLibrary.name,
            pathParameters: {'kind': 'album'},
          ),
      '/menu/neteaseLibrary/album',
    );
  });

  testWidgets('music source applies only after leaving settings', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const AppStartupScreen(app: ClassipodApp()),
      ),
    );
    await tester.pumpAndSettle();
    providerContainer.read(routerProvider).goNamed(Routes.menu.name);
    await tester.pump(const Duration(milliseconds: 100));
    providerContainer.read(routerProvider).goNamed(Routes.settings.name);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      providerContainer.read(routerProvider).locationNamed,
      Routes.settings.name,
    );

    tester
        .widget<SettingsListTile>(find.byType(SettingsListTile).first)
        .onTap();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      providerContainer.read(routerProvider).locationNamed,
      Routes.settings.name,
    );

    providerContainer.read(routerProvider).pop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      providerContainer.read(routerProvider).locationNamed,
      Routes.splash.name,
    );

    await providerContainer
        .read(settingsPreferencesControllerProvider.notifier)
        .toggleMusicSource();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Parameterized route reports its configured route name', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const AppStartupScreen(app: ClassipodApp()),
      ),
    );
    await tester.pumpAndSettle();

    providerContainer
        .read(routerProvider)
        .goNamed(Routes.neteaseLibrary.name, pathParameters: {'kind': 'album'});
    await tester.pumpAndSettle();

    expect(
      providerContainer.read(routerProvider).locationNamed,
      Routes.neteaseLibrary.name,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    providerContainer.read(routerProvider).goNamed(Routes.splash.name);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Sleep timer fades its duration choices in and out', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const AppStartupScreen(app: ClassipodApp()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('sleep-timer'));
    final optionsOpacity = find.byKey(
      const ValueKey('sleep-timer-options-opacity'),
    );
    expect(button, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.hourglass), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(optionsOpacity).opacity, 0);

    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AnimatedOpacity>(optionsOpacity).opacity, 1);
    expect(find.byKey(const ValueKey('sleep-timer-60')), findsOneWidget);
    expect(find.byKey(const ValueKey('sleep-timer-120')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sleep-timer-60')));
    await tester.pump();
    expect(providerContainer.read(sleepTimerControllerProvider), 60);

    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AnimatedOpacity>(optionsOpacity).opacity, 0);
    expect(find.byIcon(CupertinoIcons.hourglass), findsOneWidget);

    providerContainer
        .read(sleepTimerControllerProvider.notifier)
        .setMinutes(60);

    await tester.pumpWidget(const SizedBox.shrink());
    providerContainer.read(routerProvider).goNamed(Routes.splash.name);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Show Page Not Found on Error Screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const AppStartupScreen(app: ClassipodApp()),
      ),
    );
    await tester.pump();
    providerContainer.read(routerProvider).go("moosic/gibberish");
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(PageNotFoundScreen), findsOne);
  });
}
