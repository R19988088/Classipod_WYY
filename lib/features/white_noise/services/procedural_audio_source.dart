// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:just_audio/just_audio.dart';

const int proceduralSampleRate = 44100;
const int wavHeaderLength = 44;
const Duration proceduralAudioDuration = Duration(hours: 2);
const int _proceduralAudioSeconds = 2 * 60 * 60;
const int _bytesPerSample = 2;
const int _pcmDataLength =
    proceduralSampleRate * _bytesPerSample * _proceduralAudioSeconds;
const int twoHourWavLength = wavHeaderLength + _pcmDataLength;
const int _streamChunkLength = 16 * 1024;

class ProceduralAudioSource extends StreamAudioSource {
  ProceduralAudioSource(this.sound, {required this.seed, super.tag});

  final WhiteNoiseSound sound;
  final int seed;

  late final Uint8List _header = _createWavHeader();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final clippedStart = (start ?? 0).clamp(0, twoHourWavLength);
    final clippedEnd = (end ?? twoHourWavLength).clamp(
      clippedStart,
      twoHourWavLength,
    );

    return StreamAudioResponse(
      sourceLength: twoHourWavLength,
      contentLength: clippedEnd - clippedStart,
      offset: clippedStart,
      contentType: 'audio/wav',
      stream: _bytes(clippedStart, clippedEnd),
    );
  }

  Stream<List<int>> _bytes(int start, int end) async* {
    var offset = start;
    while (offset < end) {
      final chunkEnd = min(offset + _streamChunkLength, end);
      final chunk = Uint8List(chunkEnd - offset);
      for (var index = 0; index < chunk.length; index++) {
        final absoluteOffset = offset + index;
        if (absoluteOffset < wavHeaderLength) {
          chunk[index] = _header[absoluteOffset];
          continue;
        }
        final pcmOffset = absoluteOffset - wavHeaderLength;
        final sample = _pcmSample(pcmOffset ~/ _bytesPerSample);
        chunk[index] = pcmOffset.isEven ? sample & 0xff : (sample >> 8) & 0xff;
      }
      yield chunk;
      offset = chunkEnd;
      await Future<void>.delayed(Duration.zero);
    }
  }

  int _pcmSample(int sampleIndex) {
    final value = _wave(
      sampleIndex / proceduralSampleRate,
      sampleIndex,
    ).clamp(-1.0, 1.0);
    return (value * 32767).round();
  }

  double _wave(double time, int sampleIndex) {
    final white = _noise(sampleIndex);
    final pink =
        (_smoothNoise(sampleIndex, 2) +
            _smoothNoise(sampleIndex, 8) +
            _smoothNoise(sampleIndex, 32) +
            _smoothNoise(sampleIndex, 128)) /
        4;
    final brown = _smoothNoise(sampleIndex, 512);

    return switch (sound) {
      WhiteNoiseSound.white => white * 0.32,
      WhiteNoiseSound.drizzle =>
        (white - _smoothNoise(sampleIndex, 20)) * 0.20 +
            _eventNoise(time, 0.7, 0.035) * 0.34,
      WhiteNoiseSound.heavyRain => pink * 0.38 + white * 0.12,
      WhiteNoiseSound.thunder =>
        pink * 0.16 + _eventTone(time, 19, 2.8, 58) * 0.52,
      WhiteNoiseSound.ocean =>
        brown * (0.20 + 0.18 * _slowSine(time, 0.09)) + pink * 0.08,
      WhiteNoiseSound.stream =>
        pink * 0.22 + (white - _smoothNoise(sampleIndex, 10)) * 0.12,
      WhiteNoiseSound.waterfall => pink * 0.38 + white * 0.10,
      WhiteNoiseSound.forest =>
        pink * 0.16 + _eventTone(time, 8, 0.16, 1350) * 0.16,
      WhiteNoiseSound.birds => pink * 0.025 + _birdPhrase(time) * 0.34,
      WhiteNoiseSound.insects =>
        sin(2 * pi * 4300 * time) * (0.08 + 0.07 * _slowSine(time, 6.2)) +
            pink * 0.025,
      WhiteNoiseSound.breeze =>
        brown * (0.17 + 0.08 * _slowSine(time, 0.06)) + pink * 0.05,
      WhiteNoiseSound.wind =>
        brown * (0.26 + 0.13 * _slowSine(time, 0.13)) + pink * 0.08,
      WhiteNoiseSound.snow =>
        pink * 0.08 + _eventNoise(time, 2.7, 0.018) * 0.12,
      WhiteNoiseSound.fan => brown * 0.20 + sin(2 * pi * 55 * time) * 0.055,
      WhiteNoiseSound.airConditioner =>
        brown * 0.17 + sin(2 * pi * 120 * time) * 0.04,
      WhiteNoiseSound.train => brown * 0.25 + sin(2 * pi * 3.1 * time) * 0.035,
      WhiteNoiseSound.subway => brown * 0.28 + sin(2 * pi * 48 * time) * 0.045,
      WhiteNoiseSound.pages => _eventNoise(time, 7, 0.65) * 0.32,
      WhiteNoiseSound.ticking => _tick(time) * 0.38,
      WhiteNoiseSound.fire =>
        brown * 0.12 + _eventNoise(time, 0.42, 0.028) * 0.48,
      WhiteNoiseSound.cafe =>
        pink * 0.13 + _eventTone(time, 6.5, 0.09, 1750) * 0.10,
      WhiteNoiseSound.purr =>
        brown * (0.15 + 0.13 * _slowSine(time, 26)) +
            sin(2 * pi * 48 * time) * 0.035,
      WhiteNoiseSound.singingBowl => _singingBowl(time) * 0.34,
      WhiteNoiseSound.hum =>
        sin(2 * pi * 73 * time) * 0.12 +
            sin(2 * pi * 109 * time) * 0.055 +
            brown * 0.08,
    };
  }

  double _noise(int index, [int salt = 0]) {
    var value = (index ^ seed ^ (sound.index * 0x9e3779b9) ^ salt) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x7feb352d) & 0xffffffff;
    value = ((value ^ (value >> 15)) * 0x846ca68b) & 0xffffffff;
    value = (value ^ (value >> 16)) & 0xffffffff;
    return value / 0x7fffffff - 1.0;
  }

  double _smoothNoise(int index, int step) {
    final left = index ~/ step;
    final fraction = (index % step) / step;
    final eased = fraction * fraction * (3 - 2 * fraction);
    return _noise(left, step) * (1 - eased) + _noise(left + 1, step) * eased;
  }

  double _slowSine(double time, double frequency) {
    return (sin(2 * pi * frequency * time) + 1) / 2;
  }

  double _eventNoise(double time, double interval, double duration) {
    final slot = (time / interval).floor();
    final start = interval * (0.15 + 0.65 * ((_noise(slot, 71) + 1) / 2));
    final local = time - slot * interval - start;
    if (local < 0 || local >= duration) return 0;
    final envelope = sin(pi * local / duration);
    final sampleIndex = (time * proceduralSampleRate).floor();
    return _noise(sampleIndex, slot) * envelope;
  }

  double _eventTone(
    double time,
    double interval,
    double duration,
    double frequency,
  ) {
    final slot = (time / interval).floor();
    final start = interval * (0.2 + 0.55 * ((_noise(slot, 103) + 1) / 2));
    final local = time - slot * interval - start;
    if (local < 0 || local >= duration) return 0;
    final envelope = sin(pi * local / duration);
    return sin(2 * pi * frequency * local) * envelope;
  }

  double _birdPhrase(double time) {
    final slot = (time / 3).floor();
    final start = 0.4 + 1.6 * ((_noise(slot, 211) + 1) / 2);
    final local = time - slot * 3 - start;
    if (local < 0 || local >= 0.42) return 0;
    final note = (local / 0.14).floor();
    final noteTime = local - note * 0.14;
    final envelope = sin(pi * noteTime / 0.14);
    final frequency = 1250 + note * 260 + 420 * noteTime / 0.14;
    return sin(2 * pi * frequency * noteTime) * envelope;
  }

  double _tick(double time) {
    final local = time - time.floorToDouble();
    if (local >= 0.035) return 0;
    return sin(2 * pi * 2200 * local) * exp(-local * 110);
  }

  double _singingBowl(double time) {
    final local = time % 12;
    final envelope = exp(-local * 0.28);
    return (sin(2 * pi * 236 * local) + 0.42 * sin(2 * pi * 472 * local)) *
        envelope;
  }

  Uint8List _createWavHeader() {
    final header = ByteData(wavHeaderLength);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, _pcmDataLength + 36, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, proceduralSampleRate, Endian.little);
    header.setUint32(28, proceduralSampleRate * _bytesPerSample, Endian.little);
    header.setUint16(32, _bytesPerSample, Endian.little);
    header.setUint16(34, 16, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, _pcmDataLength, Endian.little);
    return header.buffer.asUint8List();
  }

  void _writeAscii(ByteData data, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}
