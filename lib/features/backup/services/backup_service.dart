import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:classipod/features/backup/models/classipod_backup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final backupServiceProvider = Provider<BackupService>((_) => BackupService());

class BackupService {
  static const extension = 'classipod-backup';
  static const automaticFileName = 'classipod-auto.$extension';
  Timer? _automaticBackupTimer;

  void scheduleAutomaticBackup() {
    _automaticBackupTimer?.cancel();
    _automaticBackupTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        await writeAutomaticBackup();
      } on Object {
        // Automatic backup retries after the next persisted change.
      }
    });
  }

  Future<File> _automaticFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$automaticFileName');
  }

  Future<void> writeAutomaticBackup() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    final preferences = SharedPreferencesAsync();
    final backup = ClassipodBackup.fromPreferences(await preferences.getAll());
    await (await _automaticFile()).writeAsString(backup.encode(), flush: true);
  }

  Future<ClassipodBackup?> readAutomaticBackup() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
    final file = await _automaticFile();
    if (!await file.exists()) return null;
    return ClassipodBackup.decode(await file.readAsString());
  }

  Future<bool> exportSelectedFile() async {
    final preferences = SharedPreferencesAsync();
    final bytes = Uint8List.fromList(
      utf8.encode(
        ClassipodBackup.fromPreferences(await preferences.getAll()).encode(),
      ),
    );
    final path = await FilePicker.saveFile(
      dialogTitle: '选择备份保存位置',
      fileName: 'classipod-backup.$extension',
      type: FileType.custom,
      allowedExtensions: const [extension],
      bytes: bytes,
    );
    return path != null;
  }

  Future<ClassipodBackup?> pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择 ClassiPod 备份',
      type: FileType.custom,
      allowedExtensions: const [extension],
      withData: true,
    );
    final selected = result?.files.single;
    if (selected == null) return null;
    final bytes = selected.bytes;
    if (bytes != null) return ClassipodBackup.decode(utf8.decode(bytes));
    final path = selected.path;
    if (path == null) throw const FormatException('无法读取所选备份文件');
    return ClassipodBackup.decode(await File(path).readAsString());
  }

  Future<void> restore(ClassipodBackup backup) async {
    final preferences = SharedPreferencesAsync();
    final restoredPreferences = backup.preferencesForRestore();
    for (final value in restoredPreferences.values) {
      if (value is! String &&
          value is! bool &&
          value is! int &&
          value is! double &&
          (value is! List || value.any((item) => item is! String))) {
        throw const FormatException('备份包含不受支持的设置值');
      }
    }
    for (final key in const [
      'netease.cookies',
      'netease.profile',
      'coverFlow.local',
      'coverFlow.netease',
    ]) {
      await preferences.remove(key);
    }
    for (final entry in restoredPreferences.entries) {
      final value = entry.value;
      switch (value) {
        case String():
          await preferences.setString(entry.key, value);
        case bool():
          await preferences.setBool(entry.key, value);
        case int():
          await preferences.setInt(entry.key, value);
        case double():
          await preferences.setDouble(entry.key, value);
        case List():
          await preferences.setStringList(entry.key, value.cast<String>());
        default:
          throw const FormatException('备份包含不受支持的设置值');
      }
    }
    await (await SharedPreferences.getInstance()).reload();
    await writeAutomaticBackup();
  }
}
