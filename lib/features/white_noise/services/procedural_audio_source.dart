// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/native_spatial_rain_renderer.dart';
import 'package:just_audio/just_audio.dart';

const int proceduralSampleRate = 48000;
const int proceduralChannelCount = 2;
const int wavHeaderLength = 44;
const Duration proceduralAudioDuration = Duration(hours: 2);
const int _bytesPerSample = 2;
const int proceduralBytesPerFrame = proceduralChannelCount * _bytesPerSample;
const int _proceduralFrameCount = proceduralSampleRate * 2 * 60 * 60;
const int _pcmDataLength = _proceduralFrameCount * proceduralBytesPerFrame;
const int proceduralWavLength = wavHeaderLength + _pcmDataLength;
const int _streamChunkLength = 32 * 1024;

class ProceduralAudioSource extends StreamAudioSource {
  ProceduralAudioSource(this.sound, {required this.seed, super.tag});

  final WhiteNoiseSound sound;
  final int seed;

  late final Uint8List _header = _createWavHeader();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final clippedStart = (start ?? 0).clamp(0, proceduralWavLength);
    final clippedEnd = (end ?? proceduralWavLength).clamp(
      clippedStart,
      proceduralWavLength,
    );

    return StreamAudioResponse(
      sourceLength: proceduralWavLength,
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
      final renderStart = offset;
      final renderEnd = chunkEnd;
      final renderSound = sound;
      final renderSeed = seed;
      final chunk = await Isolate.run(
        () => ProceduralAudioSource(
          renderSound,
          seed: renderSeed,
        )._renderChunk(renderStart, renderEnd),
      );
      yield chunk;
      offset = chunkEnd;
    }
  }

  Uint8List _renderChunk(int start, int end) {
    final chunk = Uint8List(end - start);
    final nativeRain = _renderNativeRainRange(start, end);
    var cachedSampleIndex = -1;
    var cachedSample = 0;
    for (var index = 0; index < chunk.length; index++) {
      final absoluteOffset = start + index;
      if (absoluteOffset < wavHeaderLength) {
        chunk[index] = _header[absoluteOffset];
        continue;
      }
      if (nativeRain != null) {
        chunk[index] = nativeRain.byteAt(absoluteOffset);
        continue;
      }
      final pcmOffset = absoluteOffset - wavHeaderLength;
      final sampleIndex = pcmOffset ~/ _bytesPerSample;
      if (sampleIndex != cachedSampleIndex) {
        final frame = sampleIndex ~/ proceduralChannelCount;
        final channel = sampleIndex % proceduralChannelCount;
        cachedSample = _pcmSample(frame, channel);
        cachedSampleIndex = sampleIndex;
      }
      chunk[index] = pcmOffset.isEven
          ? cachedSample & 0xff
          : (cachedSample >> 8) & 0xff;
    }
    return chunk;
  }

  _NativeRainRange? _renderNativeRainRange(int start, int end) {
    final pcmStart = max(start, wavHeaderLength) - wavHeaderLength;
    final pcmEnd = max(end, wavHeaderLength) - wavHeaderLength;
    if (pcmStart >= pcmEnd) return null;
    final firstFrame = pcmStart ~/ proceduralBytesPerFrame;
    final lastFrame =
        (pcmEnd + proceduralBytesPerFrame - 1) ~/ proceduralBytesPerFrame;
    final bytes = renderNativeSpatialRain(
      sound: sound,
      seed: seed,
      startFrame: firstFrame,
      frameCount: lastFrame - firstFrame,
    );
    return bytes == null
        ? null
        : _NativeRainRange(firstFrame: firstFrame, bytes: bytes);
  }

  int _pcmSample(int frame, int channel) {
    final time = frame / proceduralSampleRate;
    final value = _wave(time, frame, channel).clamp(-1.0, 1.0);
    return (value * 32767).round();
  }

  double _wave(double time, int frame, int channel) {
    final white = _wideNoise(frame, channel, 1, 101);
    final pink = _pinkNoise(frame, channel, 211);
    final brown = _wideNoise(frame, channel, 512, 307);

    return switch (sound) {
      WhiteNoiseSound.white => white * 0.28,
      WhiteNoiseSound.drizzle => _drizzle(time, frame, channel),
      WhiteNoiseSound.heavyRain => _heavyRain(time, frame, channel),
      WhiteNoiseSound.storm => _storm(time, frame, channel),
      WhiteNoiseSound.thunder => _lightningStorm(time, frame, channel),
      WhiteNoiseSound.stream => _stream(time, frame, channel),
      WhiteNoiseSound.river => _river(time, frame, channel),
      WhiteNoiseSound.ocean => _ocean(time, frame, channel),
      WhiteNoiseSound.tsunami => _tsunami(time, frame, channel),
      WhiteNoiseSound.forest => _forest(time, frame, channel),
      WhiteNoiseSound.birds =>
        pink * 0.025 + _birdPhrase(time, frame, channel) * 0.42,
      WhiteNoiseSound.rainforest => _rainforest(time, frame, channel),
      WhiteNoiseSound.breeze => _windScene(time, frame, channel, 0.28),
      WhiteNoiseSound.wind => _windScene(time, frame, channel, 0.58),
      WhiteNoiseSound.gale => _windScene(time, frame, channel, 0.94),
      WhiteNoiseSound.fan => _fan(time, frame, channel),
      WhiteNoiseSound.subway => _subway(time, frame, channel),
      WhiteNoiseSound.train => _train(time, frame, channel),
      WhiteNoiseSound.oldLocomotive => _oldLocomotive(time, frame, channel),
      WhiteNoiseSound.ticking => _tick(time, channel) * 0.36,
      WhiteNoiseSound.fire => _fire(time, frame, channel),
      WhiteNoiseSound.cafe => _cafe(time, frame, channel),
      WhiteNoiseSound.temple => _temple(time, frame, channel),
      WhiteNoiseSound.purr => _purr(time, frame, channel, false),
      WhiteNoiseSound.singingBowl => _singingBowl(time, channel) * 0.30,
      WhiteNoiseSound.hum =>
        sin(2 * pi * 73 * time + channel * 0.03) * 0.10 +
            sin(2 * pi * 109 * time + channel * 0.05) * 0.045 +
            brown * 0.07,
      WhiteNoiseSound.catPurr => _catPurrOriginal(time, frame, channel),
    };
  }

  double _drizzle(double time, int frame, int channel) {
    final fine = _wideNoise(frame, channel, 2, 503);
    final body = _wideNoise(frame, channel, 32, 509);
    final drops =
        _eventNoise(time, frame, channel, 0.43, 0.020, 521) * 0.22 +
        _eventNoise(time, frame, channel, 0.71, 0.034, 523) * 0.16;
    final drift = 0.72 + 0.28 * _slowDrift(frame, 4, 527);
    return (fine - body) * 0.16 * drift + drops;
  }

  double _heavyRain(double time, int frame, int channel) {
    final sheet = _pinkNoise(frame, channel, 601);
    final hiss = _wideNoise(frame, channel, 2, 607);
    final roof = _wideNoise(frame, channel, 24, 613);
    final intensity = 0.70 + 0.30 * _slowDrift(frame, 3, 617);
    final drops = _eventNoise(time, frame, channel, 0.19, 0.016, 619);
    return (sheet * 0.28 + (hiss - roof) * 0.10) * intensity + drops * 0.12;
  }

  double _storm(double time, int frame, int channel) {
    final rain = _heavyRain(time, frame, channel) * 0.82;
    final gust =
        _wideNoise(frame, channel, 420, 701) *
        (0.10 + 0.18 * _slowDrift(frame, 6, 709));
    return rain + gust + _thunder(time, frame, channel, 17, 719) * 0.24;
  }

  double _lightningStorm(double time, int frame, int channel) {
    final distantRain = _pinkNoise(frame, channel, 743) * 0.15;
    final wind = _wideNoise(frame, channel, 560, 751) * 0.10;
    return distantRain + wind + _thunder(time, frame, channel, 8.7, 757) * 0.78;
  }

  double _thunder(
    double time,
    int frame,
    int channel,
    double interval,
    int salt,
  ) {
    final slot = (time / interval).floor();
    return _thunderEvent(time, frame, channel, interval, slot, salt) +
        _thunderEvent(time, frame, channel, interval, slot - 1, salt);
  }

  double _thunderEvent(
    double time,
    int frame,
    int channel,
    double interval,
    int slot,
    int salt,
  ) {
    final start = interval * (0.12 + 0.62 * _unitNoise(slot, salt));
    final pan = _noise(slot, salt + 3) * 0.82;
    final stereoDelay = channel == 0
        ? max(0.0, pan) * 0.012
        : max(0.0, -pan) * 0.012;
    final local = time - slot * interval - start - stereoDelay;
    if (local < 0 || local >= 5.6) return 0;
    final panGain = _panGain(pan, channel);
    final decay = exp(-local * (0.48 + 0.20 * _unitNoise(slot, salt + 5)));
    final rumble =
        _wideNoise(frame, channel, 700, salt + 11 + slot * 7) * 0.72 +
        sin(2 * pi * (35 + 18 * _unitNoise(slot, salt + 13)) * local) * 0.18;
    final snap = local < 0.026
        ? _wideNoise(frame, channel, 1, salt + 17 + slot * 11) *
              exp(-local * 145)
        : 0.0;
    final tearing = local < 0.24
        ? (_wideNoise(frame, channel, 1, salt + 19 + slot * 13) -
                  _wideNoise(frame, channel, 17, salt + 23 + slot * 13)) *
              exp(-local * 13) *
              (0.58 + 0.42 * pow(max(0.0, sin(2 * pi * 37 * local)), 2))
        : 0.0;
    final strikeStrength = 0.82 + 0.38 * _unitNoise(slot, salt + 29);
    return (rumble * decay + (snap * 1.15 + tearing * 0.62) * strikeStrength) *
        panGain;
  }

  double _stream(double time, int frame, int channel) {
    final current = _pinkNoise(frame, channel, 809) * 0.17;
    final sparkle =
        (_wideNoise(frame, channel, 2, 811) -
            _wideNoise(frame, channel, 18, 821)) *
        0.11;
    final bubbles = _eventNoise(time, frame, channel, 0.36, 0.055, 823);
    return current + sparkle + bubbles * 0.13;
  }

  double _river(double time, int frame, int channel) {
    final depth = _spaciousNoise(frame, channel, 860, 907) * 0.30;
    final flow = _pinkNoise(frame, channel, 911) * 0.31;
    final broadCurrent = _spaciousNoise(frame, channel, 85, 913) * 0.17;
    final surface =
        (_wideNoise(frame, channel, 3, 919) -
            _wideNoise(frame, channel, 30, 929)) *
        0.10;
    final drift =
        0.82 +
        0.24 * _slowDrift(frame, 7, 937) +
        0.12 * _slowDrift(frame, 19, 941);
    return (depth + flow + broadCurrent + surface) * drift;
  }

  double _ocean(double time, int frame, int channel) {
    final depth =
        _spaciousNoise(frame, channel, 1100, 1009) *
        (0.12 + 0.08 * _slowDrift(frame, 17, 1013));
    final nearWaves = _oceanWave(time, frame, channel, 6.8, 1019) * 0.34;
    final farWaves = _oceanWave(time + 2.7, frame, channel, 10.3, 1051) * 0.20;
    return depth + nearWaves + farWaves;
  }

  double _oceanWave(
    double time,
    int frame,
    int channel,
    double interval,
    int salt,
  ) {
    final slot = (time / interval).floor();
    var result = 0.0;
    for (final waveSlot in [slot, slot - 1]) {
      final start = interval * (0.04 + 0.34 * _unitNoise(waveSlot, salt));
      final local = time - waveSlot * interval - start;
      final duration = 4.2 + 1.5 * _unitNoise(waveSlot, salt + 3);
      if (local < 0 || local >= duration) continue;
      final crest = 0.82 + 0.54 * _unitNoise(waveSlot, salt + 5);
      final rise = local < crest
          ? pow(sin(pi * local / (2 * crest)), 1.55)
          : exp(
              -(local - crest) * (0.44 + 0.18 * _unitNoise(waveSlot, salt + 7)),
            );
      final foamLocal = local - crest * 0.48;
      final foamEnvelope = foamLocal <= 0
          ? 0.0
          : pow(min(foamLocal / 0.52, 1.0), 1.3) * exp(-foamLocal * 0.48);
      final pan = _noise(waveSlot, salt + 11) * 0.48;
      final body = _spaciousNoise(frame, channel, 520, salt + waveSlot * 17);
      final foam =
          _pinkNoise(frame, channel, salt + 13 + waveSlot * 19) * 0.72 +
          (_wideNoise(frame, channel, 2, salt + 17 + waveSlot * 23) -
                  _wideNoise(frame, channel, 22, salt + 19 + waveSlot * 23)) *
              0.28;
      result +=
          (body * rise * 0.55 + foam * foamEnvelope) * _panGain(pan, channel);
    }
    return result;
  }

  double _tsunami(double time, int frame, int channel) {
    final swell = _swell(time * 0.72, frame, 1103);
    final mass = _wideNoise(frame, channel, 1100, 1109) * (0.24 + 0.24 * swell);
    final roar = _pinkNoise(frame, channel, 1117) * (0.18 + 0.22 * swell);
    final crash = _waterCrash(time, frame, channel, 8.5, 1123) * 0.30;
    return mass + roar + crash;
  }

  double _swell(double time, int frame, int salt) {
    final phase =
        2 * pi * (0.075 * time + 0.10 * sin(2 * pi * 0.013 * time)) +
        _noise(seed, salt);
    final shaped = (sin(phase) + 1) / 2;
    return (0.18 + 0.82 * pow(shaped, 1.7)) *
        (0.78 + 0.22 * _slowDrift(frame, 9, salt + 7));
  }

  double _waterCrash(
    double time,
    int frame,
    int channel,
    double interval,
    int salt,
  ) {
    final slot = (time / interval).floor();
    var result = 0.0;
    for (final eventSlot in [slot, slot - 1]) {
      final start = interval * (0.10 + 0.60 * _unitNoise(eventSlot, salt));
      final local = time - eventSlot * interval - start;
      if (local < 0 || local >= 2.8) continue;
      final pan = _noise(eventSlot, salt + 3) * 0.72;
      final envelope = sin(pi * min(local / 0.34, 1.0)) * exp(-local * 0.72);
      result +=
          _pinkNoise(frame, channel, salt + eventSlot * 17) *
          envelope *
          _panGain(pan, channel);
    }
    return result;
  }

  double _forest(double time, int frame, int channel) {
    final air = _wideNoise(frame, channel, 700, 1201) * 0.075;
    final leaves = _pinkNoise(frame, channel, 1213) * 0.055;
    return air + leaves + _birdPhrase(time, frame, channel) * 0.26;
  }

  double _rainforest(double time, int frame, int channel) {
    final rain = _drizzle(time, frame, channel) * 0.56;
    final canopy = _pinkNoise(frame, channel, 1301) * 0.10;
    final birds =
        _birdPhrase(
          time,
          frame,
          channel,
          salt: 1319,
          interval: 12.5,
          probability: 0.58,
        ) *
        0.16;
    final insects = _insectPhrase(time, channel, 1327) * 0.075;
    return rain + canopy + birds + insects;
  }

  double _birdPhrase(
    double time,
    int frame,
    int channel, {
    int salt = 1409,
    double interval = 2.9,
    double probability = 1.0,
  }) {
    final slot = (time / interval).floor();
    if (_unitNoise(slot, salt + 31) > probability) return 0;
    final start = 0.28 + (interval - 1.42) * _unitNoise(slot, salt);
    final local = time - slot * interval - start;
    if (local < 0 || local >= 1.25) return 0;
    final direct = _birdPhraseSample(local, slot, channel, salt);
    final nearReflection =
        _birdPhraseSample(local - 0.065, slot, 1 - channel, salt) * 0.20;
    final farReflection =
        _birdPhraseSample(local - 0.145, slot, channel, salt) * 0.09;
    final breath = 0.88 + 0.12 * _wideNoise(frame, channel, 9, salt + 37);
    return (direct + nearReflection + farReflection) * breath;
  }

  double _birdPhraseSample(double local, int slot, int channel, int salt) {
    if (local < 0) return 0;
    final noteCount = 2 + (4 * _unitNoise(slot, salt + 3)).floor();
    final phraseLength = 0.42 + 0.38 * _unitNoise(slot, salt + 5);
    if (local >= phraseLength) return 0;
    final noteLength = phraseLength / noteCount;
    final note = min((local / noteLength).floor(), noteCount - 1);
    final noteTime = local - note * noteLength;
    final activeLength =
        noteLength * (0.72 + 0.16 * _unitNoise(note, salt + slot));
    if (noteTime >= activeLength) return 0;
    final envelope = pow(sin(pi * noteTime / activeLength), 1.7);
    final noteSeed = slot * 7 + note;
    final base = 1180 + 980 * _unitNoise(noteSeed, salt + 7);
    final sweep = 760 * _noise(noteSeed, salt + 11);
    final phase =
        2 *
        pi *
        (base * noteTime + 0.5 * sweep * noteTime * noteTime / activeLength);
    final pan = _noise(slot, salt + 13) * 0.90;
    return (sin(phase) + 0.18 * sin(phase * 2.01)) *
        envelope *
        _panGain(pan, channel);
  }

  double _insectPhrase(double time, int channel, int salt) {
    const interval = 1.7;
    final slot = (time / interval).floor();
    final start = 0.15 + 0.90 * _unitNoise(slot, salt);
    final local = time - slot * interval - start;
    if (local < 0 || local >= 0.48) return 0;
    final tremolo = pow(max(0.0, sin(2 * pi * 18 * local)), 2);
    final frequency = 3100 + 1700 * _unitNoise(slot, salt + 3);
    final pan = _noise(slot, salt + 5) * 0.94;
    return sin(2 * pi * frequency * local) *
        tremolo *
        sin(pi * local / 0.48) *
        _panGain(pan, channel);
  }

  double _fire(double time, int frame, int channel) {
    final bed = _wideNoise(frame, channel, 460, 1501) * 0.105;
    final flame =
        _pinkNoise(frame, channel, 1511) *
        (0.045 + 0.055 * _slowDrift(frame, 2, 1513));
    const interval = 0.12;
    final slot = (time / interval).floor();
    final chance = _unitNoise(slot, 1523);
    if (chance < 0.58) return bed + flame;
    final local = time - slot * interval;
    final pan = _noise(slot, 1529) * 0.88;
    final crack =
        _wideNoise(frame, channel, 1, 1531 + slot * 13) *
        exp(-local * (42 + 60 * _unitNoise(slot, 1537))) *
        _panGain(pan, channel);
    return bed + flame + crack * 0.30;
  }

  double _fan(double time, int frame, int channel) {
    final drift = _slowDrift(frame, 8, 1601) - 0.5;
    final motorFrequency = 47.5 + 1.2 * drift;
    final phase =
        2 * pi * motorFrequency * time +
        0.18 * sin(2 * pi * 0.17 * time) +
        channel * 0.035;
    final motor = sin(phase) * 0.035 + sin(phase * 2.02) * 0.014;
    final blades = 0.72 + 0.28 * sin(2 * pi * (6.4 + drift * 0.3) * time);
    final air =
        (_wideNoise(frame, channel, 120, 1613) * 0.13 +
            _pinkNoise(frame, channel, 1619) * 0.055) *
        blades;
    final room = _wideNoise(frame - 613 - channel * 97, channel, 260, 1621);
    return motor + air + room * 0.045;
  }

  double _windScene(double time, int frame, int channel, double intensity) {
    final gust =
        0.36 +
        0.42 * _slowDrift(frame, 7, 1643) +
        0.22 * _slowDrift(frame, 19, 1657);
    final low = _spaciousNoise(frame, channel, 760, 1663) * 0.24;
    final middle = _spaciousNoise(frame, channel, 90, 1667) * 0.14;
    final air =
        (_wideNoise(frame, channel, 3, 1669) -
            _wideNoise(frame, channel, 28, 1679)) *
        0.075;
    final whistlePhase =
        2 * pi * (410 + 170 * _slowDrift(frame, 5, 1693)) * time +
        channel * 0.11;
    final whistle = intensity > 0.75
        ? sin(whistlePhase) * pow(_slowDrift(frame, 11, 1697), 5) * 0.028
        : 0.0;
    final pressure = low * (0.24 + intensity * 0.76);
    return (pressure + middle * intensity + air * intensity * intensity) *
            gust *
            (0.62 + intensity * 0.48) +
        whistle;
  }

  double _subway(double time, int frame, int channel) {
    final speed = 0.72 + 0.20 * _slowDrift(frame, 13, 2003);
    final tunnel =
        _spaciousNoise(frame, channel, 620, 2011) * 0.20 +
        _spaciousNoise(frame, channel, 95, 2017) * 0.10;
    final inverterPhase =
        2 * pi * (118 + 55 * sin(2 * pi * 0.024 * time)) * time +
        channel * 0.025;
    final inverter =
        sin(inverterPhase) * 0.026 + sin(inverterPhase * 2.01) * 0.012;
    final rail = _railClatter(time, frame, channel, 4.7 * speed, 2027) * 0.18;
    final airflow =
        (_wideNoise(frame, channel, 3, 2039) -
            _wideNoise(frame, channel, 35, 2041)) *
        0.075;
    final squeal = _railSqueal(time, channel, 17.0, 2053) * 0.055;
    return tunnel + inverter + rail + airflow + squeal;
  }

  double _train(double time, int frame, int channel) {
    final engineDrift =
        0.63 +
        0.25 * _slowDrift(frame, 5, 2101) +
        0.20 * _slowDrift(frame, 17, 2103);
    final rumblePhase =
        2 *
        pi *
        (68 * time +
            3.8 * sin(2 * pi * 0.037 * time) +
            1.7 * sin(2 * pi * 0.113 * time + _noise(seed, 2107)));
    final tonalRumble = sin(rumblePhase) * 0.040 * engineDrift;
    final brownRumble =
        _spaciousNoise(frame, channel, 760, 2111) * 0.20 * engineDrift;
    final engineNoise =
        (_spaciousNoise(frame, channel, 60, 2113) * 0.11 +
            _pinkNoise(frame, channel, 2117) * 0.055) *
        (0.62 +
            0.28 * _slowDrift(frame, 3, 2121) +
            0.18 * _slowDrift(frame, 11, 2123));
    final mechanicalPhaseDrift =
        3.1 * sin(2 * pi * 0.031 * time + _noise(seed, 2125)) +
        1.4 * sin(2 * pi * 0.083 * time + _noise(seed, 2127));
    final rattle =
        (sin(2 * pi * 196 * time + mechanicalPhaseDrift + channel * 0.04) *
                0.018 +
            sin(
                  2 * pi * 247 * time -
                      mechanicalPhaseDrift * 0.7 +
                      channel * 0.07,
                ) *
                0.012 +
            sin(
                  2 * pi * 313 * time +
                      mechanicalPhaseDrift * 0.4 +
                      channel * 0.09,
                ) *
                0.008) *
        engineDrift;
    final rail = _railClatter(time, frame, channel, 3.35, 2131) * 0.22;
    final hiss =
        (_wideNoise(frame, channel, 2, 2141) -
            _wideNoise(frame, channel, 18, 2143)) *
        0.032;
    final carriageGroan = _railSqueal(time + 3.1, channel, 22.7, 2153) * 0.024;
    final journeyLevel =
        0.48 +
        0.46 * _slowDrift(frame, 2, 2161) +
        0.30 * _slowDrift(frame, 7, 2167) +
        0.12 * _slowDrift(frame, 19, 2173);
    return (tonalRumble + brownRumble + engineNoise + rattle + hiss) *
            journeyLevel +
        rail +
        carriageGroan;
  }

  double _oldLocomotive(double time, int frame, int channel) {
    final tempo = 2.35 + 0.45 * _slowDrift(frame, 12, 2203);
    final chuffCycles =
        tempo * time + 0.28 * sin(2 * pi * 0.047 * time + _noise(seed, 2207));
    final chuffPhase = chuffCycles - chuffCycles.floorToDouble();
    final chuffEnvelope = chuffPhase < 0.34
        ? pow(sin(pi * chuffPhase / 0.34), 1.3)
        : 0.0;
    final steam =
        (_pinkNoise(frame, channel, 2213) * 0.22 +
            _wideNoise(frame, channel, 3, 2221) * 0.07) *
        chuffEnvelope;
    final boiler = _spaciousNoise(frame, channel, 850, 2237) * 0.17;
    final rods = _railClatter(time, frame, channel, tempo * 2, 2239) * 0.22;
    final longHiss =
        (_wideNoise(frame, channel, 2, 2243) -
            _wideNoise(frame, channel, 24, 2251)) *
        (0.025 + 0.035 * _slowDrift(frame, 9, 2257));
    final whistle = _steamWhistle(time, channel, 29, 2267) * 0.075;
    return steam + boiler + rods + longHiss + whistle;
  }

  double _railClatter(
    double time,
    int frame,
    int channel,
    double rate,
    int salt,
  ) {
    final cycles =
        rate * time +
        0.21 * sin(2 * pi * 0.071 * time + _noise(seed, salt)) +
        0.09 * sin(2 * pi * 0.019 * time + _noise(seed, salt + 2));
    final phase = cycles - cycles.floorToDouble();
    final event = cycles.floor();
    if (_unitNoise(event, salt + 5) < 0.14) return 0;
    final duration = 0.052 + 0.045 * _unitNoise(event, salt + 9);
    if (phase >= duration) return 0;
    final envelope = exp(-phase * (52 + 34 * _unitNoise(event, salt + 11)));
    final impactFrequency = 620 + 520 * _unitNoise(event, salt + 13);
    final click =
        _wideNoise(frame, channel, 1, salt + 3) * 0.65 +
        sin(2 * pi * impactFrequency * phase / rate) * 0.35;
    final pan = _noise(event, salt + 7) * 0.55;
    final strength = 0.54 + 0.72 * _unitNoise(event, salt + 17);
    return click * envelope * strength * _panGain(pan, channel);
  }

  double _railSqueal(double time, int channel, double interval, int salt) {
    final slot = (time / interval).floor();
    final start = interval * (0.18 + 0.55 * _unitNoise(slot, salt));
    final local = time - slot * interval - start;
    if (local < 0 || local >= 2.4) return 0;
    final envelope = sin(pi * local / 2.4) * (0.65 + 0.35 * sin(23 * local));
    final base = 1450 + 750 * _unitNoise(slot, salt + 3);
    final pan = _noise(slot, salt + 5) * 0.75;
    return (sin(2 * pi * base * local) * 0.65 +
            sin(2 * pi * base * 2.18 * local) * 0.35) *
        envelope *
        _panGain(pan, channel);
  }

  double _steamWhistle(double time, int channel, double interval, int salt) {
    final slot = (time / interval).floor();
    final start = interval * (0.18 + 0.54 * _unitNoise(slot, salt));
    final local = time - slot * interval - start;
    if (local < 0 || local >= 2.2) return 0;
    final envelope = pow(sin(pi * local / 2.2), 0.72);
    final base = 420 + 70 * _unitNoise(slot, salt + 3);
    return (sin(2 * pi * base * local + channel * 0.07) +
            0.42 * sin(2 * pi * base * 1.51 * local + channel * 0.11)) *
        envelope;
  }

  double _cafe(double time, int frame, int channel) {
    final rumble = _spaciousNoise(frame, channel, 720, 2309) * 0.075;
    final restaurant =
        (_wideNoise(frame, channel, 18, 2311) -
            _wideNoise(frame, channel, 110, 2317)) *
        (0.10 + 0.05 * _slowDrift(frame, 8, 2321));
    final chatter =
        (_wideNoise(frame, channel, 5, 2333) -
            _wideNoise(frame, channel, 38, 2339)) *
        (0.075 + 0.055 * _slowDrift(frame, 5, 2341));
    final babble =
        (_wideNoise(frame, channel, 3, 2347) -
            _wideNoise(frame, channel, 15, 2351)) *
        (0.045 + 0.04 * _slowDrift(frame, 3, 2357));
    final room = _spaciousNoise(frame - 1103, channel, 140, 2371) * 0.045;
    final clink = _cafeClink(time, channel, 3.7, 2377) * 0.11;
    final table = _eventNoise(time, frame, channel, 2.4, 0.12, 2381) * 0.055;
    final kitchen = _eventNoise(time, frame, channel, 5.3, 0.24, 2383) * 0.045;
    return rumble +
        restaurant +
        chatter +
        babble +
        room +
        clink +
        table +
        kitchen;
  }

  double _cafeClink(double time, int channel, double interval, int salt) {
    final slot = (time / interval).floor();
    final start = interval * (0.12 + 0.70 * _unitNoise(slot, salt));
    final local = time - slot * interval - start;
    if (local < 0 || local >= 0.75) return 0;
    final base = 1350 + 900 * _unitNoise(slot, salt + 3);
    final envelope = exp(-local * 7.2);
    final pan = _noise(slot, salt + 7) * 0.88;
    return (sin(2 * pi * base * local) +
            0.55 * sin(2 * pi * base * 1.43 * local) +
            0.28 * sin(2 * pi * base * 2.17 * local)) *
        envelope *
        _panGain(pan, channel);
  }

  double _temple(double time, int frame, int channel) {
    final openAir = _spaciousNoise(frame, channel, 920, 2401) * 0.045;
    final distantWind = _spaciousNoise(frame, channel, 180, 2411) * 0.035;
    final bell = _templeBell(time, channel, 13.0, 2417) * 0.17;
    final wood = _woodBlock(time, channel, 7.3, 2423) * 0.08;
    final chant =
        (sin(2 * pi * 108 * time + channel * 0.05) * 0.012 +
            sin(2 * pi * 162 * time + channel * 0.08) * 0.008) *
        (0.45 + 0.55 * _slowDrift(frame, 11, 2437));
    return openAir + distantWind + bell + wood + chant;
  }

  double _templeBell(double time, int channel, double interval, int salt) {
    final slot = (time / interval).floor();
    var result = 0.0;
    for (final bellSlot in [slot, slot - 1]) {
      final start = interval * (0.10 + 0.54 * _unitNoise(bellSlot, salt));
      final local = time - bellSlot * interval - start;
      if (local < 0 || local >= 11.5) continue;
      final base = 168 + 34 * _unitNoise(bellSlot, salt + 3);
      final pan = _noise(bellSlot, salt + 5) * 0.54;
      const ratios = [1.0, 2.01, 2.42, 3.0, 4.16, 5.43];
      const gains = [1.0, 0.62, 0.44, 0.31, 0.20, 0.13];
      var modes = 0.0;
      for (var index = 0; index < ratios.length; index++) {
        final decay = exp(-local * (0.22 + index * 0.055));
        modes +=
            sin(
              2 * pi * base * ratios[index] * local + channel * index * 0.025,
            ) *
            gains[index] *
            decay;
      }
      result += modes * _panGain(pan, channel);
    }
    return result;
  }

  double _woodBlock(double time, int channel, double interval, int salt) {
    final slot = (time / interval).floor();
    final start = interval * (0.16 + 0.58 * _unitNoise(slot, salt));
    final local = time - slot * interval - start;
    if (local < 0 || local >= 0.55) return 0;
    final base = 540 + 90 * _unitNoise(slot, salt + 3);
    final pan = _noise(slot, salt + 5) * 0.45;
    return (sin(2 * pi * base * local) +
            0.35 * sin(2 * pi * base * 2.71 * local)) *
        exp(-local * 12) *
        _panGain(pan, channel);
  }

  double _catPurrOriginal(double time, int frame, int channel) {
    final cyclePhase =
        0.34 * time +
        0.42 * sin(2 * pi * 0.019 * time + _noise(seed, 2503)) +
        0.11 * sin(2 * pi * 0.071 * time + _noise(seed, 2511));
    final progress = cyclePhase - cyclePhase.floorToDouble();
    final inhaleFraction = 0.43 + 0.035 * _slowDrift(frame, 13, 2521);
    final inhale = progress < inhaleFraction;
    final phaseProgress = inhale
        ? progress / inhaleFraction
        : (progress - inhaleFraction) / (1 - inhaleFraction);
    final envelope = inhale
        ? _shapeEnvelope(
            phaseProgress,
            const [0, 0.10, 0.46, 0.84, 1],
            const [0.04, 0.34, 1, 0.72, 0.06],
          )
        : _shapeEnvelope(
            phaseProgress,
            const [0, 0.08, 0.58, 0.90, 1],
            const [0.08, 0.84, 0.78, 0.28, 0.04],
          );
    final pulseCycles =
        27.6 * time +
        4.6 * sin(2 * pi * 0.049 * time + _noise(seed, 2531)) +
        0.42 * sin(2 * pi * 0.37 * time + _noise(seed, 2539));
    final pulse = pow(max(0.0, sin(2 * pi * pulseCycles)), 1.35);
    final common = inhale
        ? _wideNoise(frame, 0, 7, 2543) - _wideNoise(frame, 0, 62, 2543)
        : _wideNoise(frame, 0, 9, 2551) - _wideNoise(frame, 0, 78, 2551);
    final side = inhale
        ? _wideNoise(frame, channel, 8, 2557) -
              _wideNoise(frame, channel, 70, 2557)
        : _wideNoise(frame, channel, 11, 2579) -
              _wideNoise(frame, channel, 86, 2579);
    final texture = common * 0.78 + side * 0.20;
    return texture * envelope * (0.16 + 1.08 * pulse) * 0.58;
  }

  double _shapeEnvelope(
    double progress,
    List<double> times,
    List<double> levels,
  ) {
    for (var index = 1; index < times.length; index++) {
      if (progress <= times[index]) {
        final span = times[index] - times[index - 1];
        final amount = ((progress - times[index - 1]) / span).clamp(0.0, 1.0);
        final smooth = amount * amount * (3 - 2 * amount);
        return levels[index - 1] * (1 - smooth) + levels[index] * smooth;
      }
    }
    return levels.last;
  }

  double _purr(double time, int frame, int channel, bool catStyle) {
    final breathCycles =
        0.285 * time +
        0.19 * sin(2 * pi * 0.031 * time + _noise(seed, 1709)) +
        0.08 * sin(2 * pi * 0.011 * time + _noise(seed, 1721));
    final breathPhase = 2 * pi * breathCycles;
    final inhale = (sin(breathPhase) + 1) / 2;
    final breathShape = catStyle ? pow(inhale, 0.72) : pow(inhale, 1.18);
    final breathDrift = 0.76 + 0.24 * _slowDrift(frame, 4, 1723);
    final breath = (0.07 + 0.93 * breathShape) * breathDrift;

    final pulseCycles = catStyle
        ? 28.0 * time +
              5.2 * sin(2 * pi * 0.052 * time + _noise(seed, 1729)) +
              0.38 * sin(2 * pi * 0.37 * time + _noise(seed, 1733)) +
              0.18 * _wideNoise(frame, 0, proceduralSampleRate ~/ 3, 1747)
        : 25.8 * time +
              0.74 * sin(2 * pi * 0.41 * time + _noise(seed, 1733)) +
              0.39 * sin(2 * pi * 0.137 * time + _noise(seed, 1741)) +
              0.18 * _wideNoise(frame, 0, proceduralSampleRate ~/ 3, 1747);
    final closure = pow(max(0.0, sin(2 * pi * pulseCycles)), 1.45);
    final common = _pinkNoise(frame, 0, catStyle ? 1753 : 1759);
    final side = _pinkNoise(frame, channel, catStyle ? 1777 : 1783);
    final texture = catStyle
        ? common * 0.72 + side * 0.22
        : common * 0.52 + side * 0.34;
    final body = _wideNoise(
      frame,
      channel,
      catStyle ? 54 : 82,
      catStyle ? 1789 : 1801,
    );
    final pulseTexture = catStyle
        ? 0.14 + 1.05 * closure
        : 0.34 + 0.66 * closure;
    return (texture * 0.24 + body * 0.09) * breath * pulseTexture * 1.55;
  }

  double _eventNoise(
    double time,
    int frame,
    int channel,
    double interval,
    double duration,
    int salt,
  ) {
    final slot = (time / interval).floor();
    final start = interval * (0.08 + 0.70 * _unitNoise(slot, salt));
    final local = time - slot * interval - start;
    if (local < 0 || local >= duration) return 0;
    final envelope = pow(sin(pi * local / duration), 1.35);
    final pan = _noise(slot, salt + 3) * 0.92;
    return _noise(frame, salt + slot * 17) * envelope * _panGain(pan, channel);
  }

  double _tick(double time, int channel) {
    final local = time - time.floorToDouble() - channel * 0.0007;
    if (local < 0 || local >= 0.035) return 0;
    return sin(2 * pi * 2200 * local) * exp(-local * 110);
  }

  double _singingBowl(double time, int channel) {
    final strike = (time / 11.5).floor();
    final local = time - strike * 11.5;
    final base = 228 + 16 * _unitNoise(strike, 1901);
    final envelope = exp(-local * 0.28);
    return (sin(2 * pi * base * local + channel * 0.04) +
            0.42 * sin(2 * pi * base * 2.01 * local + channel * 0.09)) *
        envelope;
  }

  double _pinkNoise(int frame, int channel, int salt) {
    return (_wideNoise(frame, channel, 2, salt) +
            _wideNoise(frame, channel, 8, salt + 3) +
            _wideNoise(frame, channel, 32, salt + 5) +
            _wideNoise(frame, channel, 128, salt + 7)) /
        4;
  }

  double _wideNoise(int frame, int channel, int step, int salt) {
    final common = _smoothNoise(frame, step, salt);
    final side = _smoothNoise(frame, step, salt + 101 + channel * 211);
    return common * 0.72 + side * 0.48;
  }

  double _spaciousNoise(int frame, int channel, int step, int salt) {
    final direct = _wideNoise(frame, channel, step, salt);
    final nearDelay = channel == 0 ? 719 : 1103;
    final farDelay = channel == 0 ? 1877 : 1451;
    final near = _wideNoise(frame - nearDelay, 1 - channel, step, salt + 17);
    final far = _wideNoise(frame - farDelay, channel, step, salt + 29);
    return direct * 0.68 + near * 0.23 + far * 0.13;
  }

  double _slowDrift(int frame, int seconds, int salt) {
    return (_smoothNoise(frame, proceduralSampleRate * seconds, salt) + 1) / 2;
  }

  double _smoothNoise(int frame, int step, int salt) {
    final left = frame ~/ step;
    final fraction = (frame % step) / step;
    final eased = fraction * fraction * (3 - 2 * fraction);
    return _noise(left, salt) * (1 - eased) + _noise(left + 1, salt) * eased;
  }

  double _unitNoise(int index, int salt) => (_noise(index, salt) + 1) / 2;

  double _noise(int index, int salt) {
    var value = (index ^ seed ^ (sound.index * 0x9e3779b9) ^ salt) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x7feb352d) & 0xffffffff;
    value = ((value ^ (value >> 15)) * 0x846ca68b) & 0xffffffff;
    value = (value ^ (value >> 16)) & 0xffffffff;
    return value / 0x7fffffff - 1.0;
  }

  double _panGain(double pan, int channel) {
    final angle = (pan + 1) * pi / 4;
    return channel == 0 ? cos(angle) : sin(angle);
  }

  Uint8List _createWavHeader() {
    final header = ByteData(wavHeaderLength);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, _pcmDataLength + 36, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, proceduralChannelCount, Endian.little);
    header.setUint32(24, proceduralSampleRate, Endian.little);
    header.setUint32(
      28,
      proceduralSampleRate * proceduralBytesPerFrame,
      Endian.little,
    );
    header.setUint16(32, proceduralBytesPerFrame, Endian.little);
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

final class _NativeRainRange {
  const _NativeRainRange({required this.firstFrame, required this.bytes});

  final int firstFrame;
  final Uint8List bytes;

  int byteAt(int absoluteWavOffset) {
    final pcmOffset = absoluteWavOffset - wavHeaderLength;
    return bytes[pcmOffset - firstFrame * proceduralBytesPerFrame];
  }
}
