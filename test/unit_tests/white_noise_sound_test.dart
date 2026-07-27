import 'dart:math';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('white noise categories keep the requested display order', () {
    expect(WhiteNoiseCategory.values.map((category) => category.title), [
      '噪音',
      '雨',
      '水',
      '林',
      '风',
      '室内',
      '暖',
      '冥想',
    ]);
  });

  test('noise always resolves to white noise', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(
        resolveWhiteNoiseSound(WhiteNoiseCategory.noise, Random(seed)),
        WhiteNoiseSound.white,
      );
    }
  });

  test('random sounds stay inside their category', () {
    for (final category in WhiteNoiseCategory.values.skip(1)) {
      for (var seed = 0; seed < 100; seed++) {
        expect(
          category.sounds,
          contains(resolveWhiteNoiseSound(category, Random(seed))),
        );
      }
    }
  });

  test('previous and next categories wrap at both ends', () {
    expect(
      nextWhiteNoiseCategory(WhiteNoiseCategory.meditation),
      WhiteNoiseCategory.noise,
    );
    expect(
      previousWhiteNoiseCategory(WhiteNoiseCategory.noise),
      WhiteNoiseCategory.meditation,
    );
    expect(
      nextWhiteNoiseCategory(WhiteNoiseCategory.rain),
      WhiteNoiseCategory.water,
    );
    expect(
      previousWhiteNoiseCategory(WhiteNoiseCategory.water),
      WhiteNoiseCategory.rain,
    );
  });
}
