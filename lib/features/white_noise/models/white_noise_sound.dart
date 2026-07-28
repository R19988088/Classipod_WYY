import 'dart:math';

enum WhiteNoiseCategory {
  catPurr('猫呼噜'),
  rain('雨'),
  water('水'),
  forest('林'),
  wind('风'),
  indoor('室内'),
  warm('环境'),
  meditation('冥想'),
  noise('噪音');

  const WhiteNoiseCategory(this.title);

  final String title;

  List<WhiteNoiseSound> get sounds => switch (this) {
    WhiteNoiseCategory.catPurr => const [
      WhiteNoiseSound.catPurr,
      WhiteNoiseSound.purr,
    ],
    WhiteNoiseCategory.rain => const [
      WhiteNoiseSound.drizzle,
      WhiteNoiseSound.heavyRain,
      WhiteNoiseSound.storm,
      WhiteNoiseSound.thunder,
    ],
    WhiteNoiseCategory.water => const [
      WhiteNoiseSound.stream,
      WhiteNoiseSound.river,
      WhiteNoiseSound.ocean,
      WhiteNoiseSound.tsunami,
    ],
    WhiteNoiseCategory.forest => const [
      WhiteNoiseSound.forest,
      WhiteNoiseSound.birds,
      WhiteNoiseSound.rainforest,
    ],
    WhiteNoiseCategory.wind => const [
      WhiteNoiseSound.breeze,
      WhiteNoiseSound.wind,
      WhiteNoiseSound.gale,
    ],
    WhiteNoiseCategory.indoor => const [
      WhiteNoiseSound.fan,
      WhiteNoiseSound.subway,
      WhiteNoiseSound.train,
      WhiteNoiseSound.oldLocomotive,
      WhiteNoiseSound.ticking,
    ],
    WhiteNoiseCategory.warm => const [
      WhiteNoiseSound.fire,
      WhiteNoiseSound.cafe,
      WhiteNoiseSound.temple,
    ],
    WhiteNoiseCategory.meditation => const [
      WhiteNoiseSound.singingBowl,
      WhiteNoiseSound.hum,
    ],
    WhiteNoiseCategory.noise => const [WhiteNoiseSound.white],
  };

  String get heroTag => 'white-noise-category-$name';

  String get imagePath => 'assets/images/white_noise/$name.webp';
}

enum WhiteNoiseSound {
  white('白噪音'),
  drizzle('小雨'),
  heavyRain('大雨'),
  storm('暴风雨'),
  thunder('电闪雷鸣'),
  stream('小溪'),
  river('长江'),
  ocean('大海'),
  tsunami('海啸'),
  forest('森林'),
  birds('鸟鸣'),
  rainforest('雨林'),
  breeze('微风'),
  wind('风声'),
  gale('狂风'),
  fan('风扇'),
  subway('地铁'),
  train('火车', assetName: 'train.mp3'),
  oldLocomotive('老式机车'),
  ticking('滴答'),
  fire('篝火'),
  cafe('咖啡馆', assetName: 'cafe.mp3'),
  temple('寺院'),
  purr('呼呼声'),
  singingBowl('颂钵'),
  hum('低鸣'),
  catPurr('猫呼噜');

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
