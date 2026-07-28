import 'dart:io';

import 'package:classipod/core/constants/constants.dart';

class DeviceDirectory {
  final Directory documentsDirectory;

  DeviceDirectory({required this.documentsDirectory});

  String get musicFolderPath {
    if (Platform.isAndroid) {
      return Constants.androidDefaultMusicFolderPath;
    } else if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) return '$home\\Music';
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return '$home${Platform.pathSeparator}Music';
      }
    }

    final pathList = documentsDirectory.path.split(Platform.pathSeparator);
    pathList[pathList.length - 1] = 'Music';
    return pathList.join(Platform.pathSeparator);
  }

  static bool isWithinMusicDirectory(String musicRoot, String candidate) {
    if (musicRoot.isEmpty || candidate.isEmpty) return false;
    try {
      var resolvedRoot = Directory(musicRoot).resolveSymbolicLinksSync();
      var resolvedCandidate = Directory(candidate).resolveSymbolicLinksSync();
      if (Platform.isWindows) {
        resolvedRoot = resolvedRoot.toLowerCase();
        resolvedCandidate = resolvedCandidate.toLowerCase();
      }
      if (resolvedCandidate == resolvedRoot) return true;
      final rootPrefix = resolvedRoot.endsWith(Platform.pathSeparator)
          ? resolvedRoot
          : '$resolvedRoot${Platform.pathSeparator}';
      return resolvedCandidate.startsWith(rootPrefix);
    } on FileSystemException {
      return false;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceDirectory &&
        other.documentsDirectory.path == documentsDirectory.path;
  }

  @override
  int get hashCode => documentsDirectory.path.hashCode;

  @override
  String toString() {
    return 'DeviceDirectory(documentsDirectory: ${documentsDirectory.path})';
  }
}
