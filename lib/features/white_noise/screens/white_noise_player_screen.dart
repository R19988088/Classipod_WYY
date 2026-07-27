import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/extensions/go_router_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/widgets/marquee_text.dart';
import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/now_playing/widgets/album_reflective_art.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:classipod/features/white_noise/controllers/white_noise_controller.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WhiteNoisePlayerScreen extends ConsumerStatefulWidget {
  const WhiteNoisePlayerScreen({super.key});

  @override
  ConsumerState<WhiteNoisePlayerScreen> createState() =>
      _WhiteNoisePlayerScreenState();
}

class _WhiteNoisePlayerScreenState
    extends ConsumerState<WhiteNoisePlayerScreen> {
  Future<void> _handleDeviceAction(_, DeviceAction? action) async {
    if (action == null ||
        context.router.locationNamed != Routes.whiteNoisePlayer.name) {
      return;
    }
    switch (action) {
      case DeviceAction.menu:
        context.pop();
      case DeviceAction.seekForward:
        await ref.read(whiteNoiseControllerProvider.notifier).next();
      case DeviceAction.seekBackward:
        await ref.read(whiteNoiseControllerProvider.notifier).previous();
      case DeviceAction.rotateForward:
        await ref
            .read(settingsPreferencesControllerProvider.notifier)
            .increaseVolume();
      case DeviceAction.rotateBackward:
        await ref
            .read(settingsPreferencesControllerProvider.notifier)
            .decreaseVolume();
      case DeviceAction.select:
      case DeviceAction.selectLongPress:
      case DeviceAction.seekForwardLongPress:
      case DeviceAction.seekBackwardLongPress:
      case DeviceAction.playPause:
      case DeviceAction.longPressEnd:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(whiteNoiseControllerProvider);
    final timerMinutes = ref.watch(sleepTimerControllerProvider);
    ref.listen(deviceButtonsServiceProvider, _handleDeviceAction);

    if (session == null) {
      return const CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: '白噪音'),
            Expanded(child: Center(child: Text('请选择一种白噪音'))),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Column(
        children: [
          const StatusBar(title: '白噪音'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 190,
                    width: 145,
                    child: AlbumReflectiveArt(
                      imageWidth: 180,
                      tiltedImage: true,
                      flipOnEnter: true,
                      assetPath: Assets.noiseImage,
                      heroTag: session.category.heroTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        MarqueeText(
                          session.sound.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.category.title,
                          style: context.appTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.appSecondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          timerMinutes == 0 ? '不限时' : '$timerMinutes 分钟',
                          style: context.appTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.appSecondaryTextColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${session.category.index + 1} / '
                          '${WhiteNoiseCategory.values.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
