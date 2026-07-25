import 'package:classipod/features/device/widgets/device_screen.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/app_theme.dart';
import 'package:classipod/features/settings/models/click_wheel_sensitivity.dart';
import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/repeat_mode.dart';
import 'package:classipod/features/settings/models/settings_preferences_model.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';
import 'package:flutter/cupertino.dart' hide RepeatMode;
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

void main() {
  testWidgets('inner screen has 5px corners without layout spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsPreferencesControllerProvider.overrideWith(
            _SettingsController.new,
          ),
        ],
        child: const CupertinoApp(
          home: SizedBox(
            width: 300,
            child: DeviceScreen(
              child: ColoredBox(color: CupertinoColors.white),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.padding, isNull);
    expect(container.child, isA<ClipRRect>());
    final clip = container.child! as ClipRRect;
    expect(clip.borderRadius, BorderRadius.circular(5));
  });
}
