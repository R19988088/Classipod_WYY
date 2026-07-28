import 'dart:math';

import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('white noise categories keep the requested display order', () {
    expect(WhiteNoiseCategory.values.map((category) => category.title), [
      '猫呼噜',
      '雨',
      '水',
      '林',
      '风',
      '室内',
      '环境',
      '冥想',
      '噪音',
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

  test('rain category exposes four procedural weather scenes', () {
    expect(WhiteNoiseCategory.rain.sounds, [
      WhiteNoiseSound.drizzle,
      WhiteNoiseSound.heavyRain,
      WhiteNoiseSound.storm,
      WhiteNoiseSound.thunder,
    ]);
    expect(WhiteNoiseCategory.rain.sounds.map((sound) => sound.title), [
      '小雨',
      '大雨',
      '暴风雨',
      '电闪雷鸣',
    ]);
    expect(
      WhiteNoiseCategory.rain.sounds.every((sound) => !sound.isRecorded),
      isTrue,
    );
  });

  test('water category uses creek river sea and tsunami', () {
    expect(WhiteNoiseCategory.water.sounds, [
      WhiteNoiseSound.stream,
      WhiteNoiseSound.river,
      WhiteNoiseSound.ocean,
      WhiteNoiseSound.tsunami,
    ]);
    expect(WhiteNoiseCategory.water.sounds.map((sound) => sound.title), [
      '小溪',
      '长江',
      '大海',
      '海啸',
    ]);
    expect(
      WhiteNoiseCategory.water.sounds.every((sound) => !sound.isRecorded),
      isTrue,
    );
  });

  test('forest category adds rainforest and uses only synthesis', () {
    expect(WhiteNoiseCategory.forest.sounds, [
      WhiteNoiseSound.forest,
      WhiteNoiseSound.birds,
      WhiteNoiseSound.rainforest,
    ]);
    expect(
      WhiteNoiseCategory.forest.sounds.every((sound) => !sound.isRecorded),
      isTrue,
    );
  });

  test('wind category distinguishes breeze wind and gale', () {
    expect(WhiteNoiseCategory.wind.sounds, [
      WhiteNoiseSound.breeze,
      WhiteNoiseSound.wind,
      WhiteNoiseSound.gale,
    ]);
    expect(WhiteNoiseCategory.wind.sounds.map((sound) => sound.title), [
      '微风',
      '风声',
      '狂风',
    ]);
  });

  test('indoor category adds three procedural train environments', () {
    expect(WhiteNoiseCategory.indoor.sounds, [
      WhiteNoiseSound.fan,
      WhiteNoiseSound.subway,
      WhiteNoiseSound.train,
      WhiteNoiseSound.oldLocomotive,
      WhiteNoiseSound.ticking,
    ]);
  });

  test('environment category contains fire cafe and temple', () {
    expect(WhiteNoiseCategory.warm.sounds, [
      WhiteNoiseSound.fire,
      WhiteNoiseSound.cafe,
      WhiteNoiseSound.temple,
    ]);
  });

  test('restored train and cafe use the recorded loops from the baseline', () {
    expect(WhiteNoiseSound.values.where((sound) => sound.isRecorded), [
      WhiteNoiseSound.train,
      WhiteNoiseSound.cafe,
    ]);
    expect(
      WhiteNoiseSound.train.assetPath,
      'assets/audio/white_noise/train.mp3',
    );
    expect(WhiteNoiseSound.cafe.assetPath, 'assets/audio/white_noise/cafe.mp3');
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

  test('removed insect sound is not offered', () {
    expect(
      WhiteNoiseSound.values.map((sound) => sound.name),
      isNot(contains('insects')),
    );
  });

  test('removed indoor sounds are not offered', () {
    final names = WhiteNoiseSound.values.map((sound) => sound.name);
    expect(names, isNot(contains('airConditioner')));
    expect(names, isNot(contains('pages')));
  });

  test('cat purr category owns both purr simulations', () {
    expect(WhiteNoiseSound.purr.title, '呼呼声');
    expect(WhiteNoiseSound.catPurr.title, '猫呼噜');
    expect(WhiteNoiseCategory.catPurr.sounds, [
      WhiteNoiseSound.catPurr,
      WhiteNoiseSound.purr,
    ]);
    expect(
      WhiteNoiseCategory.warm.sounds,
      isNot(contains(WhiteNoiseSound.purr)),
    );
    expect(
      WhiteNoiseCategory.warm.sounds,
      isNot(contains(WhiteNoiseSound.catPurr)),
    );
  });

  test('previous and next categories wrap at both ends', () {
    expect(
      nextWhiteNoiseCategory(WhiteNoiseCategory.noise),
      WhiteNoiseCategory.catPurr,
    );
    expect(
      previousWhiteNoiseCategory(WhiteNoiseCategory.catPurr),
      WhiteNoiseCategory.noise,
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
