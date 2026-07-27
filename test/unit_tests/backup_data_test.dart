import 'package:classipod/features/backup/models/classipod_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup round trip includes settings, login and both favorite sets', () {
    final backup = ClassipodBackup.fromPreferences({
      'deviceColor': 'black',
      'clickWheelSize': 'large',
      'netease.cookies': '{"MUSIC_U":"token"}',
      'netease.profile': '{"id":"7","nickname":"User"}',
      'coverFlow.local': '[{"id":"local"}]',
      'coverFlow.netease': '[{"id":"42"}]',
    }, createdAt: DateTime.utc(2026, 7, 26));

    final restored = ClassipodBackup.decode(backup.encode());

    expect(restored.version, 1);
    expect(restored.settings['deviceColor'], 'black');
    expect(restored.netease['cookies'], '{"MUSIC_U":"token"}');
    expect(restored.coverFlow['local'], '[{"id":"local"}]');
    expect(restored.coverFlow['netease'], '[{"id":"42"}]');
    expect(restored.preferencesForRestore(), {
      'deviceColor': 'black',
      'clickWheelSize': 'large',
      'netease.cookies': '{"MUSIC_U":"token"}',
      'netease.profile': '{"id":"7","nickname":"User"}',
      'coverFlow.local': '[{"id":"local"}]',
      'coverFlow.netease': '[{"id":"42"}]',
    });
  });

  test('backup rejects unsupported versions', () {
    expect(
      () => ClassipodBackup.decode('{"version":2,"createdAt":"now"}'),
      throwsFormatException,
    );
  });
}
