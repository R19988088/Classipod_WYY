# 白噪音模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在现有播放器中增加八类白噪音模式，以按需算法流或内置循环 MP3 播放，并在两小时后暂停。

**架构：** `white_noise` feature 声明类型目录、算法 WAV 流、播放会话控制器和两个页面。算法源按 WAV 字节范围实时计算确定性采样；MP3 使用现有 `AudioPlayer` 单曲循环。专用控制器复用全局播放器和睡眠定时器，负责类型切换及两小时会话状态。

**技术栈：** Flutter、Riverpod、GoRouter、just_audio `StreamAudioSource`、audio_service `MediaItem`、Flutter Widget tests。

---

## 文件结构

- 创建 `lib/features/white_noise/models/white_noise_sound.dart`：八类与 26 种声音目录、随机解析。
- 创建 `lib/features/white_noise/services/procedural_audio_source.dart`：两小时 WAV 范围流和声音算法。
- 创建 `lib/features/white_noise/controllers/white_noise_controller.dart`：播放器会话、类型切换、计时与元数据。
- 创建 `lib/features/white_noise/screens/white_noise_screen.dart`：八类列表和 Hero 起点。
- 创建 `lib/features/white_noise/screens/white_noise_player_screen.dart`：专用播放页、Hero 终点和设备控制。
- 修改 `lib/core/services/audio_player_service.dart`：接受自定义 `AudioSource` 和对应元数据。
- 修改 `lib/features/device/controllers/sleep_timer_controller.dart`：支持直接启动 120 分钟。
- 修改 `lib/features/menu/screens/main_menu_screen.dart`：调整菜单顺序并加入白噪音。
- 修改 `lib/core/navigation/routes.dart`：注册列表和播放页路由。
- 修改 `pubspec.yaml`：声明白噪音 MP3 资源目录。
- 创建 `assets/audio/white_noise/*.mp3` 和 `assets/audio/white_noise/AUDIO_CREDITS.md`：八个循环录音及来源。
- 创建对应 unit/widget tests。

### 任务 1：声音目录与随机范围

**文件：**
- 创建：`test/unit_tests/white_noise_sound_test.dart`
- 创建：`lib/features/white_noise/models/white_noise_sound.dart`

- [x] 编写测试，断言八类顺序、噪音固定为 white、其他类解析结果属于自身候选、前后索引首尾循环。
- [x] 运行 `flutter test --no-pub test/unit_tests/white_noise_sound_test.dart --suppress-analytics`，确认因类型缺失失败。
- [x] 实现 `WhiteNoiseCategory`、`WhiteNoiseSound`、`resolveSound`、`nextCategory` 和 `previousCategory`。
- [x] 重跑测试并确认通过。

### 任务 2：按范围生成的两小时算法流

**文件：**
- 创建：`test/unit_tests/procedural_audio_source_test.dart`
- 创建：`lib/features/white_noise/services/procedural_audio_source.dart`

- [x] 编写测试，验证 WAV 头、两小时总字节数、任意大偏移范围长度、同种子可重复、不同声音采样不同及越界裁剪。
- [x] 运行目标测试，确认因音源缺失失败。
- [x] 实现 44.1 kHz 单声道 16-bit PCM WAV 头和分块 `request(start, end)`。
- [x] 使用绝对采样位置的哈希噪声、频带插值、周期包络和确定性事件槽近似 18 种合成声音。
- [x] 重跑测试并确认通过。

### 任务 3：睡眠定时与白噪音播放会话

**文件：**
- 修改：`test/unit_tests/sleep_timer_controller_test.dart`
- 创建：`test/unit_tests/white_noise_controller_test.dart`
- 修改：`lib/features/device/controllers/sleep_timer_controller.dart`
- 修改：`lib/core/services/audio_player_service.dart`
- 创建：`lib/features/white_noise/controllers/white_noise_controller.dart`

- [x] 先写测试，验证 `start(120)`、算法源不循环、MP3 单曲循环、选择时立即播放、前后类别切换和普通队列被替换。
- [x] 运行目标测试，确认新增行为失败。
- [x] 给睡眠定时器增加 `start(int minutes)`，`cycle()` 复用该入口。
- [x] 给播放器服务增加 `setCustomAudioSource`，在播放器加载前同步 `NowPlayingModel` 元数据。
- [x] 实现白噪音控制器，注入随机数和音源工厂以便测试。
- [x] 重跑目标测试并确认通过。

### 任务 4：菜单、路由、列表与 Hero 播放页

**文件：**
- 创建：`test/widget_tests/white_noise_screen_test.dart`
- 修改：`test/widget_tests/main_menu_screen_test.dart`
- 修改：`lib/features/menu/screens/main_menu_screen.dart`
- 修改：`lib/core/navigation/routes.dart`
- 创建：`lib/features/white_noise/screens/white_noise_screen.dart`
- 创建：`lib/features/white_noise/screens/white_noise_player_screen.dart`

- [x] 编写 Widget 测试，验证菜单顺序、八类文本、稳定 Hero tag，以及点击与 Select 调用同一播放入口。
- [x] 运行目标测试，确认路由和页面缺失导致失败。
- [x] 把推荐移至播客下方，并在设置上方加入白噪音入口。
- [x] 实现八类列表，列表项使用 `SettingsListTile.heroTag`。
- [x] 实现播放页，使用相同 tag 的 `AlbumReflectiveArt` 获得现有 Y 轴翻转，并把前后按钮交给白噪音控制器。
- [x] 注册两条 GoRouter 路由并重跑 Widget 测试。

### 任务 5：录音资源与发布元数据

**文件：**
- 创建：`assets/audio/white_noise/breeze.mp3`
- 创建：`assets/audio/white_noise/cafe.mp3`
- 创建：`assets/audio/white_noise/fire.mp3`
- 创建：`assets/audio/white_noise/forest.mp3`
- 创建：`assets/audio/white_noise/hrain.mp3`
- 创建：`assets/audio/white_noise/ocean.mp3`
- 创建：`assets/audio/white_noise/stream.mp3`
- 创建：`assets/audio/white_noise/train.mp3`
- 创建：`assets/audio/white_noise/AUDIO_CREDITS.md`
- 修改：`pubspec.yaml`

- [x] 复制已核验的八个循环 MP3，并记录逐文件 CC0/公有领域来源。
- [x] 用 `afinfo` 检查八个文件均可解码且为单声道。
- [x] 运行 `flutter pub get --suppress-analytics` 并确认资源被 Flutter 收集。

### 任务 6：集成验证

**文件：**
- 修改：仅修复本功能暴露的问题。

- [x] 运行 `dart format lib/features/white_noise lib/core/services/audio_player_service.dart lib/features/device/controllers/sleep_timer_controller.dart lib/features/menu/screens/main_menu_screen.dart lib/core/navigation/routes.dart test/unit_tests test/widget_tests`。
- [x] 运行白噪音相关目标测试并确认全部通过。
- [x] 运行 `flutter test --no-pub --coverage --suppress-analytics`。
- [x] 运行 `flutter analyze --suppress-analytics`。
- [x] 检查 `git diff --check`、资源总字节数和最终工作区差异，确保没有覆盖用户已有改动。
