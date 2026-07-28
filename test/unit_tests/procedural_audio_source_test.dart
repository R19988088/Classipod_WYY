import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/procedural_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

const expectedProceduralWavLength =
    wavHeaderLength +
    proceduralSampleRate * proceduralBytesPerFrame * 2 * 60 * 60;

Future<List<int>> readResponse(
  ProceduralAudioSource source, [
  int? start,
  int? end,
]) async {
  final response = await source.request(start, end);
  return response.stream.expand((chunk) => chunk).toList();
}

Future<double> meanSampleDelta(WhiteNoiseSound sound) async {
  final bytes = await readResponse(
    ProceduralAudioSource(sound, seed: 19),
    wavHeaderLength,
    wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame,
  );
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  var previous = _sampleAt(data, 0);
  var totalDelta = 0;
  final frameCount = bytes.length ~/ proceduralBytesPerFrame;
  for (var frame = 1; frame < frameCount; frame++) {
    final sample = _sampleAt(data, frame);
    totalDelta += (sample - previous).abs();
    previous = sample;
  }
  return totalDelta / (frameCount - 1);
}

Future<List<double>> rmsWindows(
  WhiteNoiseSound sound, {
  required int seconds,
  int windowMilliseconds = 250,
}) async {
  final bytes = await readResponse(
    ProceduralAudioSource(sound, seed: 67),
    wavHeaderLength,
    wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame * seconds,
  );
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final framesPerWindow =
      proceduralSampleRate *
      windowMilliseconds ~/
      Duration.millisecondsPerSecond;
  final frameCount = bytes.length ~/ proceduralBytesPerFrame;
  final levels = <double>[];
  for (
    var windowStart = 0;
    windowStart + framesPerWindow <= frameCount;
    windowStart += framesPerWindow
  ) {
    var energy = 0.0;
    for (
      var frame = windowStart;
      frame < windowStart + framesPerWindow;
      frame++
    ) {
      final sample = _sampleAt(data, frame);
      energy += sample * sample;
    }
    levels.add(sqrt(energy / framesPerWindow));
  }
  return levels;
}

int _sampleAt(ByteData data, int frame, [int channel = 0]) => data.getInt16(
  (frame * proceduralChannelCount + channel) * 2,
  Endian.little,
);

int _dominantPulseFrequency(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  const envelopeRate = 1000;
  const samplesPerBucket = proceduralSampleRate ~/ envelopeRate;
  final frameCount = bytes.length ~/ proceduralBytesPerFrame;
  final envelope = <double>[];
  for (
    var bucketStart = 0;
    bucketStart + samplesPerBucket <= frameCount;
    bucketStart += samplesPerBucket
  ) {
    var total = 0.0;
    for (
      var frame = bucketStart;
      frame < bucketStart + samplesPerBucket;
      frame++
    ) {
      total += _sampleAt(data, frame).abs();
    }
    envelope.add(total / samplesPerBucket);
  }
  final mean = envelope.reduce((left, right) => left + right) / envelope.length;
  final centered = envelope.map((value) => value - mean).toList();
  var bestFrequency = 0;
  var bestCorrelation = double.negativeInfinity;
  for (var frequency = 20; frequency <= 35; frequency++) {
    final lag = (envelopeRate / frequency).round();
    var cross = 0.0;
    for (var index = lag; index < centered.length; index++) {
      cross += centered[index] * centered[index - lag];
    }
    if (cross > bestCorrelation) {
      bestCorrelation = cross;
      bestFrequency = frequency;
    }
  }
  return bestFrequency;
}

void main() {
  test('uses Android native 48 kHz output rate', () {
    expect(proceduralSampleRate, 48000);
  });

  test('declares one continuous two hour stereo PCM WAV', () async {
    final source = ProceduralAudioSource(WhiteNoiseSound.white, seed: 7);
    final response = await source.request(0, wavHeaderLength);
    final header = await response.stream.expand((chunk) => chunk).toList();

    expect(response.sourceLength, expectedProceduralWavLength);
    expect(response.contentLength, wavHeaderLength);
    expect(ascii.decode(header.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(header.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(header.sublist(12, 16)), 'fmt ');
    expect(ascii.decode(header.sublist(36, 40)), 'data');
    final data = ByteData.sublistView(Uint8List.fromList(header));
    expect(data.getUint16(22, Endian.little), proceduralChannelCount);
    expect(data.getUint16(32, Endian.little), proceduralBytesPerFrame);
    expect(proceduralAudioDuration, const Duration(hours: 2));
  });

  test(
    'serves a range near the session end without generating its prefix',
    () async {
      final source = ProceduralAudioSource(WhiteNoiseSound.tsunami, seed: 11);
      const start = expectedProceduralWavLength - 4096;
      final response = await source.request(start, expectedProceduralWavLength);
      final bytes = await response.stream.expand((chunk) => chunk).toList();

      expect(response.offset, start);
      expect(response.contentLength, 4096);
      expect(bytes, hasLength(4096));
      expect(bytes.toSet().length, greaterThan(16));
    },
  );

  test('same seed and range return identical samples', () async {
    final first = ProceduralAudioSource(WhiteNoiseSound.birds, seed: 42);
    final second = ProceduralAudioSource(WhiteNoiseSound.birds, seed: 42);
    const start =
        wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame * 17;

    expect(
      await readResponse(first, start, start + 8192),
      await readResponse(second, start, start + 8192),
    );
  });

  test('different sound algorithms produce different samples', () async {
    final white = ProceduralAudioSource(WhiteNoiseSound.white, seed: 9);
    final ticking = ProceduralAudioSource(WhiteNoiseSound.ticking, seed: 9);
    const start =
        wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame * 5;

    expect(
      await readResponse(white, start, start + 4096),
      isNot(await readResponse(ticking, start, start + 4096)),
    );
  });

  test('river carries more continuous energy than the creek', () async {
    final stream = await rmsWindows(WhiteNoiseSound.stream, seconds: 4);
    final river = await rmsWindows(WhiteNoiseSound.river, seconds: 4);
    final streamMean =
        stream.reduce((left, right) => left + right) / stream.length;
    final riverMean =
        river.reduce((left, right) => left + right) / river.length;

    expect(riverMean, greaterThan(streamMean * 1.25));
  });

  test('lightning storm contains an audible close strike transient', () async {
    final levels =
        await rmsWindows(
            WhiteNoiseSound.thunder,
            seconds: 12,
            windowMilliseconds: 20,
          )
          ..sort();
    final background = levels[levels.length ~/ 2];

    expect(levels.last, greaterThan(background * 2.6));
  });

  test('train loudness does not repeat one fixed mechanical cycle', () async {
    final levels = await rmsWindows(
      WhiteNoiseSound.train,
      seconds: 12,
      windowMilliseconds: 500,
    );
    final normalized = levels.map((level) => (level / 200).round()).toSet();

    expect(normalized.length, greaterThanOrEqualTo(6));
  });

  test('purr includes stable broadband texture', () async {
    expect(await meanSampleDelta(WhiteNoiseSound.purr), greaterThan(5));
  });

  test('purr is not locked to the original fixed 26 Hz rhythm', () async {
    const start =
        wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame;
    final bytes = await readResponse(
      ProceduralAudioSource(WhiteNoiseSound.purr, seed: 29),
      start,
      start + proceduralSampleRate * proceduralBytesPerFrame,
    );
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    var peakTotal = 0;
    var peakCount = 0;
    var troughTotal = 0;
    var troughCount = 0;
    for (var index = 0; index < proceduralSampleRate; index++) {
      final phase = sin(2 * pi * 26 * index / proceduralSampleRate);
      final sample = _sampleAt(data, index).abs();
      if (phase > 0.8) {
        peakTotal += sample;
        peakCount++;
      } else if (phase < -0.8) {
        troughTotal += sample;
        troughCount++;
      }
    }

    expect((peakTotal / peakCount) / (troughTotal / troughCount), lessThan(2));
  });

  test('purr simulations do not contain a dominant tonal buzz', () async {
    for (final sound in [WhiteNoiseSound.purr, WhiteNoiseSound.catPurr]) {
      const start =
          wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame * 2;
      final bytes = await readResponse(
        ProceduralAudioSource(sound, seed: 31),
        start,
        start + proceduralSampleRate * proceduralBytesPerFrame,
      );
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      final samples = [
        for (var index = 0; index < proceduralSampleRate; index++)
          _sampleAt(data, index).toDouble(),
      ];
      var strongestCorrelation = 0.0;
      for (var frequency = 21; frequency <= 30; frequency++) {
        final lag = (proceduralSampleRate / frequency).round();
        var cross = 0.0;
        var leftEnergy = 0.0;
        var rightEnergy = 0.0;
        for (var index = lag; index < samples.length; index++) {
          final left = samples[index];
          final right = samples[index - lag];
          cross += left * right;
          leftEnergy += left * left;
          rightEnergy += right * right;
        }
        final correlation = cross / sqrt(leftEnergy * rightEnergy);
        strongestCorrelation = max(strongestCorrelation, correlation.abs());
      }

      expect(strongestCorrelation, lessThan(0.65), reason: sound.name);
    }
  });

  test('purr has clearly audible multi-second breathing dynamics', () async {
    const start =
        wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame;
    final bytes = await readResponse(
      ProceduralAudioSource(WhiteNoiseSound.purr, seed: 37),
      start,
      start + proceduralSampleRate * proceduralBytesPerFrame * 6,
    );
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    const windowSamples = proceduralSampleRate ~/ 5;
    final levels = <double>[];
    for (
      var windowStart = 0;
      windowStart < proceduralSampleRate * 6;
      windowStart += windowSamples
    ) {
      var energy = 0.0;
      for (
        var index = windowStart;
        index < windowStart + windowSamples;
        index++
      ) {
        final sample = _sampleAt(data, index);
        energy += sample * sample;
      }
      levels.add(sqrt(energy / windowSamples));
    }

    expect(levels.reduce(max) / levels.reduce(min), greaterThan(3));
  });

  test(
    'cat purr uses a distinct alternating inhale and exhale texture',
    () async {
      final huffing = ProceduralAudioSource(WhiteNoiseSound.purr, seed: 41);
      final catPurr = ProceduralAudioSource(WhiteNoiseSound.catPurr, seed: 41);
      const start =
          wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame;

      expect(
        await readResponse(
          catPurr,
          start,
          start + proceduralSampleRate * proceduralBytesPerFrame * 2,
        ),
        isNot(
          await readResponse(
            huffing,
            start,
            start + proceduralSampleRate * proceduralBytesPerFrame * 2,
          ),
        ),
      );
    },
  );

  test('cat purr has audible breathing-scale level changes', () async {
    const start =
        wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame;
    final bytes = await readResponse(
      ProceduralAudioSource(WhiteNoiseSound.catPurr, seed: 43),
      start,
      start + proceduralSampleRate * proceduralBytesPerFrame * 6,
    );
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    const windowSamples = proceduralSampleRate ~/ 10;
    final levels = <double>[];
    for (
      var windowStart = 0;
      windowStart < proceduralSampleRate * 6;
      windowStart += windowSamples
    ) {
      var energy = 0.0;
      for (
        var index = windowStart;
        index < windowStart + windowSamples;
        index++
      ) {
        final sample = _sampleAt(data, index);
        energy += sample * sample;
      }
      levels.add(sqrt(energy / windowSamples));
    }

    expect(levels.reduce(max) / levels.reduce(min), greaterThan(2.4));
  });

  test(
    'cat purr varies its tissue pulse tempo inside the 25 to 30 Hz band',
    () async {
      final source = ProceduralAudioSource(WhiteNoiseSound.catPurr, seed: 47);
      final frequencies = <int>{};
      for (final second in [2, 17, 41, 73]) {
        final start =
            wavHeaderLength +
            proceduralSampleRate * proceduralBytesPerFrame * second;
        final bytes = await readResponse(
          source,
          start,
          start + proceduralSampleRate * proceduralBytesPerFrame * 2,
        );
        final frequency = _dominantPulseFrequency(bytes);
        expect(frequency, inInclusiveRange(25, 30));
        frequencies.add(frequency);
      }
      expect(frequencies.length, greaterThan(1));
    },
  );

  test(
    'procedural scenes do not repeat the former ten second buffer',
    () async {
      const sounds = [
        WhiteNoiseSound.catPurr,
        WhiteNoiseSound.purr,
        WhiteNoiseSound.heavyRain,
        WhiteNoiseSound.storm,
        WhiteNoiseSound.thunder,
        WhiteNoiseSound.river,
        WhiteNoiseSound.tsunami,
        WhiteNoiseSound.rainforest,
        WhiteNoiseSound.fire,
        WhiteNoiseSound.fan,
        WhiteNoiseSound.subway,
        WhiteNoiseSound.train,
        WhiteNoiseSound.oldLocomotive,
        WhiteNoiseSound.cafe,
        WhiteNoiseSound.breeze,
        WhiteNoiseSound.wind,
        WhiteNoiseSound.gale,
        WhiteNoiseSound.temple,
      ];
      for (final sound in sounds) {
        final source = ProceduralAudioSource(sound, seed: 23);
        const firstStart =
            wavHeaderLength +
            proceduralSampleRate * proceduralBytesPerFrame * 5;
        const secondStart =
            wavHeaderLength +
            proceduralSampleRate * proceduralBytesPerFrame * 15;
        final first = await readResponse(source, firstStart, firstStart + 4096);
        final second = await readResponse(
          source,
          secondStart,
          secondStart + 4096,
        );
        expect(first, isNot(second), reason: sound.name);
      }
    },
  );

  test('new procedural scenes produce a decorrelated stereo field', () async {
    const sounds = [
      WhiteNoiseSound.drizzle,
      WhiteNoiseSound.heavyRain,
      WhiteNoiseSound.storm,
      WhiteNoiseSound.thunder,
      WhiteNoiseSound.stream,
      WhiteNoiseSound.river,
      WhiteNoiseSound.ocean,
      WhiteNoiseSound.tsunami,
      WhiteNoiseSound.forest,
      WhiteNoiseSound.birds,
      WhiteNoiseSound.rainforest,
      WhiteNoiseSound.fire,
      WhiteNoiseSound.fan,
      WhiteNoiseSound.subway,
      WhiteNoiseSound.train,
      WhiteNoiseSound.oldLocomotive,
      WhiteNoiseSound.cafe,
      WhiteNoiseSound.breeze,
      WhiteNoiseSound.wind,
      WhiteNoiseSound.gale,
      WhiteNoiseSound.temple,
    ];
    for (final sound in sounds) {
      final source = ProceduralAudioSource(sound, seed: 59);
      const start =
          wavHeaderLength + proceduralSampleRate * proceduralBytesPerFrame * 7;
      final bytes = await readResponse(
        source,
        start,
        start + proceduralSampleRate * proceduralBytesPerFrame ~/ 4,
      );
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      final frames = bytes.length ~/ proceduralBytesPerFrame;
      var cross = 0.0;
      var leftEnergy = 0.0;
      var rightEnergy = 0.0;
      for (var frame = 0; frame < frames; frame++) {
        final left = _sampleAt(data, frame).toDouble();
        final right = _sampleAt(data, frame, 1).toDouble();
        cross += left * right;
        leftEnergy += left * left;
        rightEnergy += right * right;
      }
      final correlation = cross / sqrt(leftEnergy * rightEnergy);
      expect(leftEnergy, greaterThan(1000000), reason: sound.name);
      expect(rightEnergy, greaterThan(1000000), reason: sound.name);
      expect(correlation.abs(), lessThan(0.985), reason: sound.name);
    }
  });

  test('clips invalid and out of bounds ranges', () async {
    final source = ProceduralAudioSource(WhiteNoiseSound.hum, seed: 3);
    final response = await source.request(
      expectedProceduralWavLength - 10,
      expectedProceduralWavLength + 1000,
    );

    expect(response.contentLength, 10);
    expect(
      await response.stream.expand((chunk) => chunk).toList(),
      hasLength(10),
    );

    final empty = await source.request(expectedProceduralWavLength + 1);
    expect(empty.contentLength, 0);
    expect(await empty.stream.expand((chunk) => chunk).toList(), isEmpty);
  });
}
