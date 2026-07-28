import 'dart:io';

import 'package:classipod/core/models/device_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory music;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('classipod_music_boundary_');
    music = Directory('${sandbox.path}/Music')..createSync();
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  test('allows only Music and its real subdirectories', () {
    final album = Directory('${music.path}/Album')..createSync();
    final similarlyNamed = Directory('${sandbox.path}/MusicBackup')
      ..createSync();

    expect(
      DeviceDirectory.isWithinMusicDirectory(music.path, music.path),
      true,
    );
    expect(
      DeviceDirectory.isWithinMusicDirectory(music.path, album.path),
      true,
    );
    expect(
      DeviceDirectory.isWithinMusicDirectory(music.path, sandbox.path),
      false,
    );
    expect(
      DeviceDirectory.isWithinMusicDirectory(music.path, similarlyNamed.path),
      false,
    );
    expect(DeviceDirectory.isWithinMusicDirectory(music.path, ''), false);
  });

  test('rejects a selected symlink that leaves Music', () {
    final outside = Directory('${sandbox.path}/Outside')..createSync();
    final link = Link('${music.path}/OutsideLink')..createSync(outside.path);

    expect(
      DeviceDirectory.isWithinMusicDirectory(music.path, link.path),
      false,
    );
  });
}
