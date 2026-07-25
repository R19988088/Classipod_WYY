import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/widgets/display_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/menu/controller/split_screen_controller.dart';
import 'package:classipod/features/menu/models/split_screen_type.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:classipod/features/tutorial/controller/tutorial_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _MainMenuDisplayItems {
  music,
  albums,
  playlists,
  podcasts,
  settings,
  shuffleSongs,
  nowPlaying;

  String title(BuildContext context) {
    switch (this) {
      case music:
        return context.localization.musicMenuScreenTitle;
      case albums:
        return '专辑';
      case playlists:
        return '歌单';
      case podcasts:
        return '播客';
      case settings:
        return context.localization.settingsScreenTitle;
      case shuffleSongs:
        return context.localization.shuffleSongsMenuTitle;
      case nowPlaying:
        return context.localization.nowPlayingScreenTitle;
    }
  }
}

class MainMenuScreen extends ConsumerStatefulWidget {
  final bool showTutorial;

  const MainMenuScreen({super.key, this.showTutorial = false});

  @override
  ConsumerState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.menu.name;

  @override
  List<_MainMenuDisplayItems> get displayItems =>
      ref.read(settingsPreferencesControllerProvider).musicSource ==
          MusicSource.local
      ? const [
          _MainMenuDisplayItems.music,
          _MainMenuDisplayItems.settings,
          _MainMenuDisplayItems.shuffleSongs,
          _MainMenuDisplayItems.nowPlaying,
        ]
      : const [
          _MainMenuDisplayItems.albums,
          _MainMenuDisplayItems.playlists,
          _MainMenuDisplayItems.podcasts,
          _MainMenuDisplayItems.settings,
          _MainMenuDisplayItems.shuffleSongs,
          _MainMenuDisplayItems.nowPlaying,
        ];

  @override
  void onMenuButtonPressed() {
    return;
  }

  @override
  Future<void> onSelectPressed() =>
      _navigateToScreen(displayItems[selectedDisplayItem]);

  Future<void> _navigateToScreen(_MainMenuDisplayItems menuItem) async {
    setState(() => selectedDisplayItem = displayItems.indexOf(menuItem));
    switch (menuItem) {
      case _MainMenuDisplayItems.music:
        context.goNamed(Routes.musicMenu.name);
        break;
      case _MainMenuDisplayItems.albums:
        _openLibrary(NeteaseCollectionKind.album);
        break;
      case _MainMenuDisplayItems.playlists:
        _openLibrary(NeteaseCollectionKind.playlist);
        break;
      case _MainMenuDisplayItems.podcasts:
        _openLibrary(NeteaseCollectionKind.podcast);
        break;
      case _MainMenuDisplayItems.nowPlaying:
        await _navigateToNowPlayingScreen();
        break;
      case _MainMenuDisplayItems.settings:
        context.goNamed(Routes.settings.name);
        break;
      case _MainMenuDisplayItems.shuffleSongs:
        await ref.read(audioPlayerServiceProvider.notifier).shuffleAllSongs();
        await _navigateToNowPlayingScreen();
        break;
    }
  }

  void _openLibrary(NeteaseCollectionKind kind) {
    context.goNamed(
      Routes.neteaseLibrary.name,
      pathParameters: {'kind': kind.name},
    );
  }

  Future<void> _navigateToNowPlayingScreen() async {
    unawaited(ref.read(splitScreenViewControllerProvider).closeSplitView());
    await context.pushNamed(Routes.nowPlaying.name, extra: Routes.menu.name);
    unawaited(ref.read(splitScreenViewControllerProvider).openSplitView());
  }

  Future<void> _changeSplitScreenType() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    switch (displayItems[selectedDisplayItem]) {
      case _MainMenuDisplayItems.music:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.albumArt;
        break;
      case _MainMenuDisplayItems.albums:
      case _MainMenuDisplayItems.playlists:
      case _MainMenuDisplayItems.podcasts:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.netease;
        break;
      case _MainMenuDisplayItems.settings:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.settings;
        break;
      case _MainMenuDisplayItems.shuffleSongs:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.shuffle;
        break;
      case _MainMenuDisplayItems.nowPlaying:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.nowPlaying;
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorialControllerProvider.notifier).playMenuTutorial();
    });
  }

  @override
  void didUpdateWidget(covariant MainMenuScreen oldWidget) {
    if (widget.showTutorial) {
      ref.read(tutorialControllerProvider.notifier).playMenuTutorial();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      settingsPreferencesControllerProvider.select(
        (settings) => settings.musicSource,
      ),
    );
    unawaited(_changeSplitScreenType());
    if (!ref.read(splitScreenViewControllerProvider).isScreenVisible) {
      unawaited(ref.read(splitScreenViewControllerProvider).openSplitView());
    }

    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: Routes.menu.title(context)),
          Expanded(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length,
                prototypeItem: const DisplayListTile(
                  text: '',
                  isSelected: false,
                ),
                itemBuilder: (context, index) {
                  return DisplayListTile(
                    key: ValueKey(displayItems[index]),
                    text: displayItems[index].title(context),
                    isSelected: selectedDisplayItem == index,
                    onTap: () async => _navigateToScreen(displayItems[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
