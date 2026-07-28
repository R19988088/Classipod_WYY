import 'dart:typed_data';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/native_spatial_rain_renderer_stub.dart'
    if (dart.library.ffi) 'package:classipod/features/white_noise/services/native_spatial_rain_renderer_ffi.dart'
    as implementation;

int? nativeSpatialRainSceneIndex(WhiteNoiseSound sound) => switch (sound) {
  WhiteNoiseSound.drizzle => 0,
  WhiteNoiseSound.heavyRain => 1,
  WhiteNoiseSound.storm => 2,
  WhiteNoiseSound.thunder => 3,
  _ => null,
};

Uint8List? renderNativeSpatialRain({
  required WhiteNoiseSound sound,
  required int seed,
  required int startFrame,
  required int frameCount,
}) {
  final scene = nativeSpatialRainSceneIndex(sound);
  if (scene == null) return null;
  return implementation.renderNativeSpatialRain(
    scene: scene,
    seed: seed,
    startFrame: startFrame,
    frameCount: frameCount,
  );
}
