import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  const String expectedValue = 'Le curé de Ambon';
  const String malformedValue = '￾䰀攀 挀甀爀 搀攀 䄀洀戀漀渀';

  test('normalizeMetadataString keeps already valid strings unchanged', () {
    expect(normalizeMetadataString(expectedValue), expectedValue);
  });

  test('normalizeMetadataString repairs swapped UTF-16 metadata strings', () {
    expect(normalizeMetadataString(malformedValue), expectedValue);
  });

  test(
    'MusicMetadata.fromAudioMetadata normalizes malformed metadata fields',
    () {
      final audioMetadata = AudioMetadata(
        album: malformedValue,
        artist: malformedValue,
        title: malformedValue,
        file: File('test.mp3'),
      );

      final metadata = MusicMetadata.fromAudioMetadata(audioMetadata, null, 0);

      expect(metadata.trackName, expectedValue);
      expect(metadata.albumName, expectedValue);
      expect(metadata.albumArtistName, expectedValue);
      expect(metadata.trackArtistNames, [expectedValue]);
    },
  );

  test('remote metadata keeps its network artwork URI', () {
    final source = MusicMetadata(
      filePath: 'https://audio.example/song.mp3',
      thumbnailPath: 'https://image.example/cover.jpg',
      isOnDevice: false,
    ).toAudioSource();
    final item = (source as UriAudioSource).tag as MediaItem;

    expect(item.artUri, Uri.parse('https://image.example/cover.jpg'));
  });
}
