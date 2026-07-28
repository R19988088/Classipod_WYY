import 'package:classipod/features/device/models/device_action.dart';
import 'package:flutter/services.dart';

DeviceAction? remoteActionForKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowLeft) {
    return DeviceAction.rotateBackward;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowRight) {
    return DeviceAction.rotateForward;
  }
  if (key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA) {
    return DeviceAction.select;
  }
  if (key == LogicalKeyboardKey.contextMenu) {
    return DeviceAction.playbackOptions;
  }
  if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
    return DeviceAction.menu;
  }
  return null;
}
