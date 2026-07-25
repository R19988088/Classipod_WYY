import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android uses the same media_kit audio backend as the reference app',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final startup = File(
        'lib/features/app_startup/controllers/app_startup_controller.dart',
      ).readAsStringSync();
      final justAudioPubspec = File(
        'third_party/just_audio/pubspec.yaml',
      ).readAsStringSync();

      expect(pubspec, contains('media_kit_libs_android_audio:'));
      expect(startup, contains('android: Platform.isAndroid'));
      expect(
        justAudioPubspec,
        isNot(contains('android:\n        package: com.ryanheise.just_audio')),
      );
    },
  );
}
