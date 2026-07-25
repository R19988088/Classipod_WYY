// ignore_for_file: depend_on_referenced_packages

import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/repository/settings_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new installations default to Netease and a large click wheel',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      final repository = SettingsPreferencesRepository(preferences);

      expect(repository.getMusicSource(), MusicSource.netease.name);
      expect(repository.getClickWheelSize(), ClickWheelSize.large.name);
    },
  );
}
