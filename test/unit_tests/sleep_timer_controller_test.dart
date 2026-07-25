import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep timer selects a duration and tapping it again turns it off', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(sleepTimerControllerProvider.notifier);

    controller.setMinutes(60);
    expect(container.read(sleepTimerControllerProvider), 60);

    controller.setMinutes(120);
    expect(container.read(sleepTimerControllerProvider), 120);

    controller.setMinutes(120);
    expect(container.read(sleepTimerControllerProvider), 0);
  });
}
