enum NeteaseMp3Bitrate {
  kbps128(128000, '128 kbps'),
  kbps192(192000, '192 kbps'),
  kbps320(320000, '320 kbps');

  const NeteaseMp3Bitrate(this.apiValue, this.title);

  final int apiValue;
  final String title;

  NeteaseMp3Bitrate get next {
    final index = NeteaseMp3Bitrate.values.indexOf(this);
    return NeteaseMp3Bitrate.values[(index + 1) % values.length];
  }

  static NeteaseMp3Bitrate fromName(String value) {
    return NeteaseMp3Bitrate.values
            .where((item) => item.name == value)
            .firstOrNull ??
        NeteaseMp3Bitrate.kbps320;
  }
}
