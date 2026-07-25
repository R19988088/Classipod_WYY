import 'dart:async';

import 'package:classipod/core/services/audio_player_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sleepTimerControllerProvider =
    NotifierProvider<SleepTimerController, int>(SleepTimerController.new);

class SleepTimerController extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void setMinutes(int minutes) {
    if (minutes != 60 && minutes != 120) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    state = state == minutes ? 0 : minutes;
    _timer?.cancel();
    _timer = state == 0
        ? null
        : Timer(Duration(minutes: state), () {
            state = 0;
            _timer = null;
            unawaited(ref.read(audioPlayerServiceProvider.notifier).pause());
          });
  }
}
