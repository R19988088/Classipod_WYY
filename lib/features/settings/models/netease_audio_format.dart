enum NeteaseAudioFormat {
  mp3,
  flac;

  String get title => switch (this) {
    mp3 => 'MP3',
    flac => 'FLAC',
  };

  NeteaseAudioFormat get next => switch (this) {
    mp3 => flac,
    flac => mp3,
  };

  static NeteaseAudioFormat fromName(String value) {
    return NeteaseAudioFormat.values
            .where((item) => item.name == value)
            .firstOrNull ??
        NeteaseAudioFormat.mp3;
  }
}
