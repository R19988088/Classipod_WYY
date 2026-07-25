import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({super.key});

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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

    return SizedBox(
      width: 120,
      height: 36,
      child: Row(
        children: [
          CupertinoButton(
            key: const ValueKey('sleep-timer'),
            minimumSize: const Size(44, 36),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Icon(CupertinoIcons.hourglass, size: 20, color: color),
          ),
          AnimatedOpacity(
            key: const ValueKey('sleep-timer-options-opacity'),
            duration: const Duration(milliseconds: 200),
            opacity: _expanded ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_expanded,
              child: Row(
                key: const ValueKey('sleep-timer-options'),
                children: [
                  _DurationButton(
                    key: const ValueKey('sleep-timer-60'),
                    minutes: 60,
                    selected: minutes == 60,
                    color: color,
                    onPressed: () => ref
                        .read(sleepTimerControllerProvider.notifier)
                        .setMinutes(60),
                  ),
                  _DurationButton(
                    key: const ValueKey('sleep-timer-120'),
                    minutes: 120,
                    selected: minutes == 120,
                    color: color,
                    onPressed: () => ref
                        .read(sleepTimerControllerProvider.notifier)
                        .setMinutes(120),
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

class _DurationButton extends StatelessWidget {
  const _DurationButton({
    super.key,
    required this.minutes,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final int minutes;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: SizedBox(
      width: 38,
      height: 36,
      child: Center(
        child: Text(
          '$minutes',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );
}
