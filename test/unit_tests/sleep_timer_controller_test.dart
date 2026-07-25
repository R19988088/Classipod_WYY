import 'package:classipod/features/device/controllers/sleep_timer_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep timer cycles through hidden, 60, 120, and hidden', () {
    expect(nextSleepTimerMinutes(0), 60);
    expect(nextSleepTimerMinutes(60), 120);
    expect(nextSleepTimerMinutes(120), 0);
  });
}
