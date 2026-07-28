import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/providers/android_tv_provider.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/device/widgets/device_controls.dart';
import 'package:classipod/features/device/widgets/device_frame.dart';
import 'package:classipod/features/device/widgets/remote_control_scope.dart';
import 'package:classipod/features/device/widgets/sleep_timer_button.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/app_theme.dart';
import 'package:classipod/features/settings/models/click_wheel_sensitivity.dart';
import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/repeat_mode.dart';
import 'package:classipod/features/settings/models/settings_preferences_model.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';
import 'package:classipod/l10n/generated/app_localizations.dart';
import 'package:flutter/cupertino.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsController extends SettingsPreferencesControllerNotifier {
  @override
  SettingsPreferencesModel build() => SettingsPreferencesModel(
    languageLocaleCode: 'zh',
    deviceColor: DeviceColor.silver,
    clickWheelSize: ClickWheelSize.large,
    clickWheelSensitivity: ClickWheelSensitivity.medium,
    isTouchScreenEnabled: true,
    repeatMode: RepeatMode.off,
    vibrate: false,
    clickWheelSound: false,
    volumeMode: VolumeMode.app,
    splitScreenEnabled: false,
    immersiveMode: false,
    appTheme: AppTheme.light,
    musicSource: MusicSource.netease,
  );
}

class _ButtonsController extends DeviceButtonsServiceNotifier {
  @override
  DeviceAction? build() => null;

  @override
  Future<void> setDeviceAction(DeviceAction action) async => state = action;
}

const _contentKey = ValueKey('device-frame-content');

Widget _app({required bool isTelevision}) => ProviderScope(
  overrides: [
    androidTvProvider.overrideWith((ref) async => isTelevision),
    settingsPreferencesControllerProvider.overrideWith(_SettingsController.new),
    deviceButtonsServiceProvider.overrideWith(_ButtonsController.new),
  ],
  child: const CupertinoApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DeviceFrame(
      child: ColoredBox(key: _contentKey, color: CupertinoColors.white),
    ),
  ),
);

void main() {
  testWidgets('television uses full screen without touch controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(_app(isTelevision: true));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceControls), findsNothing);
    expect(find.byType(SleepTimerButton), findsNothing);
    expect(
      tester.getSize(find.byType(RemoteControlScope)),
      const Size(1280, 720),
    );
    expect(
      tester.getSize(find.byKey(_contentKey)),
      const Size(1280 / 1.5, 720 / 1.5),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeviceFrame)),
    );
    expect(
      container.read(deviceButtonsServiceProvider),
      DeviceAction.rotateForward,
    );
  });

  testWidgets('phone keeps the existing touch controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 812));
    await tester.pumpWidget(_app(isTelevision: false));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceControls), findsOne);
    expect(find.byType(SleepTimerButton), findsOne);
    expect(tester.getSize(find.byKey(_contentKey)).width, lessThan(300));
  });
}
