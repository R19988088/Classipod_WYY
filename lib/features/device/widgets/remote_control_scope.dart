import 'dart:async';

import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/device/services/remote_control_key_mapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteControlScope extends ConsumerStatefulWidget {
  final Widget child;

  const RemoteControlScope({super.key, required this.child});

  @override
  ConsumerState<RemoteControlScope> createState() => _RemoteControlScopeState();
}

class _RemoteControlScopeState extends ConsumerState<RemoteControlScope> {
  final _focusNode = FocusNode(debugLabel: 'Android TV remote');

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final action = remoteActionForKey(event.logicalKey);
    if (action == null) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent &&
        action != DeviceAction.rotateForward &&
        action != DeviceAction.rotateBackward) {
      return KeyEventResult.handled;
    }
    unawaited(
      ref.read(deviceButtonsServiceProvider.notifier).setDeviceAction(action),
    );
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    focusNode: _focusNode,
    onKeyEvent: _handleKeyEvent,
    child: widget.child,
  );
}
