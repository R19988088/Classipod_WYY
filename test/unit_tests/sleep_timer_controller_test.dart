import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep timer cycles through hidden, 60, 120, and hidden', () {
    expect(nextSleepTimerMinutes(0), 60);
    expect(nextSleepTimerMinutes(60), 120);
    expect(nextSleepTimerMinutes(120), 0);
  });

  test('sleep timer can start directly at 120 minutes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(sleepTimerControllerProvider.notifier).start(120);

    expect(container.read(sleepTimerControllerProvider), 120);
  });
}
