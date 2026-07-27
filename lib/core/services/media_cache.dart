import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const neteaseImageHeaders = <String, String>{
  'Referer': 'https://music.163.com/',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 10; Classipod) '
      'AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36',
};

class PersistentCoverCache {
  PersistentCoverCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'classipod-cover-cache',
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 10000,
    ),
  );
}
