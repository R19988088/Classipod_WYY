import 'dart:convert';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/procedural_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> readResponse(
  ProceduralAudioSource source, [
  int? start,
  int? end,
]) async {
  final response = await source.request(start, end);
  return response.stream.expand((chunk) => chunk).toList();
}

void main() {
  test('declares a two hour mono PCM WAV without materializing it', () async {
    final source = ProceduralAudioSource(WhiteNoiseSound.white, seed: 7);
    final response = await source.request(0, wavHeaderLength);
    final header = await response.stream.expand((chunk) => chunk).toList();

    expect(response.sourceLength, twoHourWavLength);
    expect(response.contentLength, wavHeaderLength);
    expect(ascii.decode(header.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(header.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(header.sublist(12, 16)), 'fmt ');
    expect(ascii.decode(header.sublist(36, 40)), 'data');
  });

  test('serves a range near the end without generating its prefix', () async {
    final source = ProceduralAudioSource(WhiteNoiseSound.waterfall, seed: 11);
    const start = twoHourWavLength - 4096;
    final response = await source.request(start, twoHourWavLength);
    final bytes = await response.stream.expand((chunk) => chunk).toList();

    expect(response.offset, start);
    expect(response.contentLength, 4096);
    expect(bytes, hasLength(4096));
    expect(bytes.toSet().length, greaterThan(16));
  });

  test('same seed and range return identical samples', () async {
    final first = ProceduralAudioSource(WhiteNoiseSound.birds, seed: 42);
    final second = ProceduralAudioSource(WhiteNoiseSound.birds, seed: 42);
    const start = wavHeaderLength + 44100 * 2 * 17;

    expect(
      await readResponse(first, start, start + 8192),
      await readResponse(second, start, start + 8192),
    );
  });

  test('different sound algorithms produce different samples', () async {
    final white = ProceduralAudioSource(WhiteNoiseSound.white, seed: 9);
    final ticking = ProceduralAudioSource(WhiteNoiseSound.ticking, seed: 9);
    const start = wavHeaderLength + 44100 * 2 * 5;

    expect(
      await readResponse(white, start, start + 4096),
      isNot(await readResponse(ticking, start, start + 4096)),
    );
  });

  test('clips invalid and out of bounds ranges', () async {
    final source = ProceduralAudioSource(WhiteNoiseSound.hum, seed: 3);
    final response = await source.request(
      twoHourWavLength - 10,
      twoHourWavLength + 1000,
    );

    expect(response.contentLength, 10);
    expect(
      await response.stream.expand((chunk) => chunk).toList(),
      hasLength(10),
    );

    final empty = await source.request(twoHourWavLength + 1);
    expect(empty.contentLength, 0);
    expect(await empty.stream.expand((chunk) => chunk).toList(), isEmpty);
  });
}
