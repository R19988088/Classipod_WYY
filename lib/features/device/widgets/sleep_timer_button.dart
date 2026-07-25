import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(sleepTimerControllerProvider);
    final style = ref.watch(
      settingsPreferencesControllerProvider.select(
        (settings) => settings.deviceColor.style,
      ),
    );
    final frameColor = style.solidFrameColor ?? style.frameGradientColors.last;
    final color = frameColor.computeLuminance() < 0.35
        ? CupertinoColors.white
        : style.controlBackgroundColor.computeLuminance() < 0.65
        ? style.controlBackgroundColor
        : style.buttonAccentColor;

    return CupertinoButton(
      key: const ValueKey('sleep-timer'),
      minimumSize: const Size(78, 36),
      padding: EdgeInsets.zero,
      onPressed: () => ref.read(sleepTimerControllerProvider.notifier).cycle(),
      child: SizedBox(
        width: 78,
        height: 36,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: minutes == 0
              ? const SizedBox.shrink(key: ValueKey('sleep-timer-hidden'))
              : Row(
                  key: ValueKey(minutes),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.hourglass, size: 18, color: color),
                    const SizedBox(width: 5),
                    Text(
                      '$minutes',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
