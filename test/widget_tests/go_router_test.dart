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
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
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

  testWidgets('Sleep timer button cycles through 60, 120, and off', (
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
    expect(button, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.hourglass), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(find.text('60'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.hourglass), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(find.text('120'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(find.text('60'), findsNothing);
    expect(find.text('120'), findsNothing);
    expect(find.byIcon(CupertinoIcons.hourglass), findsOneWidget);

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
