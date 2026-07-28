import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:classipod/core/constants/constants.dart';
import 'package:classipod/core/constants/online_audio_files_metadata.dart';
import 'package:classipod/core/models/device_directory.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/providers/device_directory_provider.dart';
import 'package:classipod/core/repositories/metadata_reader_repository.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

final audioFilesServiceProvider =
    AsyncNotifierProvider<
      AudioFilesServiceNotifier,
      UnmodifiableListView<MusicMetadata>
    >(AudioFilesServiceNotifier.new);

class AudioFilesServiceNotifier
    extends AsyncNotifier<UnmodifiableListView<MusicMetadata>> {
  @override
  Future<UnmodifiableListView<MusicMetadata>> build() async {
    return getAudioFilesMetadata();
  }

  Future<UnmodifiableListView<MusicMetadata>> getAudioFilesMetadata() async {
    state = const AsyncLoading();
    try {
      if (ref.read(settingsPreferencesControllerProvider).fetchOnlineMusic) {
        return UnmodifiableListView(onlineDemoAudioFilesMetaData);
      }
      if (ref.read(settingsPreferencesControllerProvider).musicSource !=
          MusicSource.local) {
        return UnmodifiableListView([]);
      }
      // Fetch metadata from local files
      if (ref
          .read(settingsPreferencesControllerProvider)
          .localMusicFolderPath
          .isEmpty) {
        return UnmodifiableListView([]);
      }
      final Box<MusicMetadata> metadataBox = Hive.box<MusicMetadata>(
        Constants.metadataBoxName,
      );
      // Startup only reads metadata already imported by an explicit user
      // action. Directory traversal must never happen from a provider build.
      return UnmodifiableListView(metadataBox.values);
    } catch (e) {
      return UnmodifiableListView([]);
    }
  }

  /// Imports the selected local folder. This is the only directory scan entry.
  Future<void> scanSelectedFolder() async {
    if (ref.read(settingsPreferencesControllerProvider).musicSource !=
        MusicSource.local) {
      return;
    }
    final configuredFolder = ref
        .read(settingsPreferencesControllerProvider)
        .localMusicFolderPath;
    final musicRoot = ref
        .read(deviceDirectoryProvider)
        .requireValue
        .musicFolderPath;
    final selectedFolder =
        DeviceDirectory.isWithinMusicDirectory(musicRoot, configuredFolder)
        ? configuredFolder
        : musicRoot;
    if (!DeviceDirectory.isWithinMusicDirectory(musicRoot, selectedFolder)) {
      return;
    }
    final metadataBox = Hive.box<MusicMetadata>(Constants.metadataBoxName);
    final result = Platform.isIOS
        ? await _pickFiles()
        : await compute(
            ref
                .read(metadataReaderRepositoryProvider)
                .extractMetadataFromDirectory,
            selectedFolder,
          );
    await metadataBox.clear();
    await metadataBox.addAll(result);
  }

  Future<List<MusicMetadata>> _pickFiles() async {
    final pickedFiles = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Pick Song Files',
    );
    if (pickedFiles == null || pickedFiles.files.isEmpty) return const [];
    return compute(
      ref.read(metadataReaderRepositoryProvider).extractMetadataFromFiles,
      pickedFiles.files.map((file) => file.path!).toList(),
    );
  }
}
