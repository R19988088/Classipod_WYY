import 'package:classipod/features/settings/models/app_theme.dart';
import 'package:classipod/features/settings/models/click_wheel_sensitivity.dart';
import 'package:classipod/features/settings/models/click_wheel_size.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/netease_audio_format.dart';
import 'package:classipod/features/settings/models/netease_flac_quality.dart';
import 'package:classipod/features/settings/models/netease_mp3_bitrate.dart';
import 'package:classipod/features/settings/models/repeat_mode.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';

class SettingsPreferencesModel {
  final String languageLocaleCode;
  final DeviceColor deviceColor;
  final ClickWheelSize clickWheelSize;
  final ClickWheelSensitivity clickWheelSensitivity;
  final bool isTouchScreenEnabled;
  final RepeatMode repeatMode;
  final bool vibrate;
  final bool clickWheelSound;
  final VolumeMode volumeMode;
  final bool splitScreenEnabled;
  final bool immersiveMode;
  final bool fetchOnlineMusic;
  final AppTheme appTheme;
  final MusicSource musicSource;
  final NeteaseAudioFormat neteaseAudioFormat;
  final NeteaseMp3Bitrate neteaseMp3Bitrate;
  final NeteaseFlacQuality neteaseFlacQuality;

  SettingsPreferencesModel({
    required this.languageLocaleCode,
    required this.deviceColor,
    required this.clickWheelSize,
    required this.clickWheelSensitivity,
    required this.isTouchScreenEnabled,
    required this.repeatMode,
    required this.vibrate,
    required this.clickWheelSound,
    required this.volumeMode,
    required this.splitScreenEnabled,
    required this.immersiveMode,
    required this.appTheme,
    required this.musicSource,
    this.neteaseAudioFormat = NeteaseAudioFormat.mp3,
    this.neteaseMp3Bitrate = NeteaseMp3Bitrate.kbps320,
    this.neteaseFlacQuality = NeteaseFlacQuality.lossless,
    this.fetchOnlineMusic = false,
  });

  SettingsPreferencesModel copyWith({
    String? languageLocaleCode,
    DeviceColor? deviceColor,
    ClickWheelSize? clickWheelSize,
    ClickWheelSensitivity? clickWheelSensitivity,
    bool? isTouchScreenEnabled,
    RepeatMode? repeatMode,
    bool? vibrate,
    bool? clickWheelSound,
    VolumeMode? volumeMode,
    bool? splitScreenEnabled,
    bool? immersiveMode,
    bool? fetchOnlineMusic,
    AppTheme? appTheme,
    MusicSource? musicSource,
    NeteaseAudioFormat? neteaseAudioFormat,
    NeteaseMp3Bitrate? neteaseMp3Bitrate,
    NeteaseFlacQuality? neteaseFlacQuality,
  }) {
    return SettingsPreferencesModel(
      languageLocaleCode: languageLocaleCode ?? this.languageLocaleCode,
      deviceColor: deviceColor ?? this.deviceColor,
      clickWheelSize: clickWheelSize ?? this.clickWheelSize,
      clickWheelSensitivity:
          clickWheelSensitivity ?? this.clickWheelSensitivity,
      isTouchScreenEnabled: isTouchScreenEnabled ?? this.isTouchScreenEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      vibrate: vibrate ?? this.vibrate,
      clickWheelSound: clickWheelSound ?? this.clickWheelSound,
      volumeMode: volumeMode ?? this.volumeMode,
      splitScreenEnabled: splitScreenEnabled ?? this.splitScreenEnabled,
      immersiveMode: immersiveMode ?? this.immersiveMode,
      appTheme: appTheme ?? this.appTheme,
      fetchOnlineMusic: fetchOnlineMusic ?? this.fetchOnlineMusic,
      musicSource: musicSource ?? this.musicSource,
      neteaseAudioFormat: neteaseAudioFormat ?? this.neteaseAudioFormat,
      neteaseMp3Bitrate: neteaseMp3Bitrate ?? this.neteaseMp3Bitrate,
      neteaseFlacQuality: neteaseFlacQuality ?? this.neteaseFlacQuality,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SettingsPreferencesModel &&
        other.languageLocaleCode == languageLocaleCode &&
        other.deviceColor == deviceColor &&
        other.clickWheelSize == clickWheelSize &&
        other.clickWheelSensitivity == clickWheelSensitivity &&
        other.isTouchScreenEnabled == isTouchScreenEnabled &&
        other.repeatMode == repeatMode &&
        other.vibrate == vibrate &&
        other.clickWheelSound == clickWheelSound &&
        other.volumeMode == volumeMode &&
        other.splitScreenEnabled == splitScreenEnabled &&
        other.immersiveMode == immersiveMode &&
        other.fetchOnlineMusic == fetchOnlineMusic &&
        other.musicSource == musicSource &&
        other.neteaseAudioFormat == neteaseAudioFormat &&
        other.neteaseMp3Bitrate == neteaseMp3Bitrate &&
        other.neteaseFlacQuality == neteaseFlacQuality &&
        other.appTheme == appTheme;
  }

  @override
  int get hashCode => Object.hash(
    languageLocaleCode,
    deviceColor,
    clickWheelSize,
    clickWheelSensitivity,
    isTouchScreenEnabled,
    repeatMode,
    vibrate,
    clickWheelSound,
    volumeMode,
    splitScreenEnabled,
    immersiveMode,
    appTheme,
    fetchOnlineMusic,
    musicSource,
    neteaseAudioFormat,
    neteaseMp3Bitrate,
    neteaseFlacQuality,
  );
}
