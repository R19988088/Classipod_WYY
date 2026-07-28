import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:classipod/features/white_noise/services/native_spatial_rain_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps only the four spatial rain scenes to native scene IDs', () {
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.drizzle), 0);
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.heavyRain), 1);
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.storm), 2);
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.thunder), 3);
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.white), isNull);
    expect(nativeSpatialRainSceneIndex(WhiteNoiseSound.ocean), isNull);
  });
}
