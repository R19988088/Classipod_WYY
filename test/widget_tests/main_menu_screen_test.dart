import 'package:classipod/features/menu/screens/main_menu_screen.dart';
import 'package:classipod/features/now_playing/models/now_playing_model.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/app_theme.dart';
import 'package:classipod/features/settings/models/click_wheel_sensitivity.dart';
import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/repeat_mode.dart';
import 'package:classipod/features/settings/models/settings_preferences_model.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';
import 'package:classipod/features/tutorial/controller/tutorial_controller.dart';
import 'package:classipod/features/tutorial/models/tutorial_model.dart';
import 'package:classipod/l10n/generated/app_localizations.dart';
import 'package:flutter/cupertino.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

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

class _TutorialController extends TutorialControllerNotifier {
  @override
  TutorialModel build() => TutorialModel(
    isMenuFirstTime: false,
    isNowPlayingFirstTime: false,
    isInputTextBarFirstTime: false,
  );

  @override
  void playMenuTutorial() {}
}

void main() {
  testWidgets('Netease menu places white noise below recommendations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsPreferencesControllerProvider.overrideWith(
            _SettingsController.new,
          ),
          nowPlayingDetailsProvider.overrideWith(_NowPlayingController.new),
          tutorialControllerProvider.overrideWith(_TutorialController.new),
        ],
        child: const CupertinoApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainMenuScreen(),
        ),
      ),
    );
    await tester.pump();

    final podcastY = tester.getTopLeft(find.text('播客')).dy;
    final recommendationsY = tester.getTopLeft(find.text('推荐')).dy;
    final whiteNoiseY = tester.getTopLeft(find.text('白噪音')).dy;
    final settingsY = tester.getTopLeft(find.text('设置')).dy;

    expect(podcastY, lessThan(recommendationsY));
    expect(recommendationsY, lessThan(whiteNoiseY));
    expect(whiteNoiseY, lessThan(settingsY));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
