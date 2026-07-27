import 'dart:math';

enum WhiteNoiseCategory {
  noise('噪音'),
  rain('雨'),
  water('水'),
  forest('林'),
  wind('风'),
  indoor('室内'),
  warm('暖'),
  meditation('冥想');

  const WhiteNoiseCategory(this.title);

  final String title;

  List<WhiteNoiseSound> get sounds => switch (this) {
    WhiteNoiseCategory.noise => const [WhiteNoiseSound.white],
    WhiteNoiseCategory.rain => const [
      WhiteNoiseSound.drizzle,
      WhiteNoiseSound.heavyRain,
      WhiteNoiseSound.thunder,
    ],
    WhiteNoiseCategory.water => const [
      WhiteNoiseSound.ocean,
      WhiteNoiseSound.stream,
      WhiteNoiseSound.waterfall,
    ],
    WhiteNoiseCategory.forest => const [
      WhiteNoiseSound.forest,
      WhiteNoiseSound.birds,
      WhiteNoiseSound.insects,
    ],
    WhiteNoiseCategory.wind => const [
      WhiteNoiseSound.breeze,
      WhiteNoiseSound.wind,
      WhiteNoiseSound.snow,
    ],
    WhiteNoiseCategory.indoor => const [
      WhiteNoiseSound.fan,
      WhiteNoiseSound.airConditioner,
      WhiteNoiseSound.train,
      WhiteNoiseSound.subway,
      WhiteNoiseSound.pages,
      WhiteNoiseSound.ticking,
    ],
    WhiteNoiseCategory.warm => const [
      WhiteNoiseSound.fire,
      WhiteNoiseSound.cafe,
      WhiteNoiseSound.purr,
    ],
    WhiteNoiseCategory.meditation => const [
      WhiteNoiseSound.singingBowl,
      WhiteNoiseSound.hum,
    ],
  };

  String get heroTag => 'white-noise-category-$name';
}

enum WhiteNoiseSound {
  white('白噪音'),
  drizzle('小雨'),
  heavyRain('大雨', assetName: 'hrain.mp3'),
  thunder('雷雨'),
  ocean('海浪', assetName: 'ocean.mp3'),
  stream('溪流', assetName: 'stream.mp3'),
  waterfall('瀑布'),
  forest('森林', assetName: 'forest.mp3'),
  birds('鸟鸣'),
  insects('虫鸣'),
  breeze('微风', assetName: 'breeze.mp3'),
  wind('大风'),
  snow('落雪'),
  fan('风扇'),
  airConditioner('空调'),
  train('火车', assetName: 'train.mp3'),
  subway('地铁'),
  pages('翻书'),
  ticking('滴答'),
  fire('篝火', assetName: 'fire.mp3'),
  cafe('咖啡馆', assetName: 'cafe.mp3'),
  purr('猫呼噜'),
  singingBowl('颂钵'),
  hum('低鸣');

  const WhiteNoiseSound(this.title, {this.assetName});

  final String title;
  final String? assetName;

  bool get isRecorded => assetName != null;

  String? get assetPath =>
      assetName == null ? null : 'assets/audio/white_noise/$assetName';
}

WhiteNoiseSound resolveWhiteNoiseSound(
  WhiteNoiseCategory category,
  Random random,
) {
  final sounds = category.sounds;
  return sounds[random.nextInt(sounds.length)];
}

WhiteNoiseCategory nextWhiteNoiseCategory(WhiteNoiseCategory category) {
  return WhiteNoiseCategory.values[(category.index + 1) %
      WhiteNoiseCategory.values.length];
}

WhiteNoiseCategory previousWhiteNoiseCategory(WhiteNoiseCategory category) {
  return WhiteNoiseCategory.values[(category.index -
          1 +
          WhiteNoiseCategory.values.length) %
      WhiteNoiseCategory.values.length];
}
