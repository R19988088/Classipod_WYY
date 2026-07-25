enum NeteaseFlacQuality {
  lossless('无损'),
  hires('Hi-Res'),
  jyeffect('高清环绕'),
  sky('沉浸环绕'),
  jymaster('超清母带');

  const NeteaseFlacQuality(this.title);

  final String title;

  NeteaseFlacQuality get next {
    final index = NeteaseFlacQuality.values.indexOf(this);
    return NeteaseFlacQuality.values[(index + 1) % values.length];
  }

  static NeteaseFlacQuality fromName(String value) {
    return NeteaseFlacQuality.values
            .where((item) => item.name == value)
            .firstOrNull ??
        NeteaseFlacQuality.lossless;
  }
}
