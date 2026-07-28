import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const androidDeviceChannel = MethodChannel('com.adeeteya.classipod/device');

final androidTvProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    return await androidDeviceChannel.invokeMethod<bool>('isTelevision') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
});
