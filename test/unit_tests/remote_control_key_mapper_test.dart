import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/remote_control_key_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('remote control key mapping', () {
    test('maps directional keys to wheel navigation', () {
      expect(
        remoteActionForKey(LogicalKeyboardKey.arrowUp),
        DeviceAction.rotateBackward,
      );
      expect(
        remoteActionForKey(LogicalKeyboardKey.arrowLeft),
        DeviceAction.rotateBackward,
      );
      expect(
        remoteActionForKey(LogicalKeyboardKey.arrowDown),
        DeviceAction.rotateForward,
      );
      expect(
        remoteActionForKey(LogicalKeyboardKey.arrowRight),
        DeviceAction.rotateForward,
      );
    });

    test('maps confirm and cancel keys', () {
      for (final key in [
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.gameButtonA,
      ]) {
        expect(remoteActionForKey(key), DeviceAction.select);
      }
      expect(remoteActionForKey(LogicalKeyboardKey.escape), DeviceAction.menu);
      expect(remoteActionForKey(LogicalKeyboardKey.goBack), DeviceAction.menu);
    });

    test('maps the remote menu key to the original center action', () {
      expect(
        remoteActionForKey(LogicalKeyboardKey.contextMenu),
        DeviceAction.playbackOptions,
      );
    });

    test('ignores unrelated keys', () {
      expect(remoteActionForKey(LogicalKeyboardKey.keyA), isNull);
    });
  });
}
