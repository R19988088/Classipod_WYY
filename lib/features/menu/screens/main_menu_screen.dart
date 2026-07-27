import 'dart:async';

import 'package:classipod/core/alerts/dialogs.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/widgets/display_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/menu/controller/split_screen_controller.dart';
import 'package:classipod/features/menu/models/split_screen_type.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/models/settings_preferences_model.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:classipod/features/tutorial/controller/tutorial_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _MainMenuDisplayItems {
  music,
  coverFlow,
  artists,
  albums,
  recommendations,
  playlists,
  podcasts,
  settings,
  shuffleSongs,
  nowPlaying;

  String title(BuildContext context) {
    switch (this) {
      case music:
        return context.localization.musicMenuScreenTitle;
      case coverFlow:
        return context.localization.coverFlowScreenTitle;
      case artists:
        return context.localization.artistsScreenTitle;
      case albums:
        return '专辑';
      case recommendations:
        return '推荐';
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
          _MainMenuDisplayItems.coverFlow,
          _MainMenuDisplayItems.artists,
          _MainMenuDisplayItems.settings,
          _MainMenuDisplayItems.shuffleSongs,
          _MainMenuDisplayItems.nowPlaying,
        ]
      : const [
          _MainMenuDisplayItems.coverFlow,
          _MainMenuDisplayItems.artists,
          _MainMenuDisplayItems.albums,
          _MainMenuDisplayItems.recommendations,
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
      case _MainMenuDisplayItems.coverFlow:
        unawaited(ref.read(splitScreenViewControllerProvider).closeSplitView());
        await context.pushNamed(Routes.coverFlow.name);
        unawaited(ref.read(splitScreenViewControllerProvider).openSplitView());
        break;
      case _MainMenuDisplayItems.artists:
        context.goNamed(Routes.artists.name);
        break;
      case _MainMenuDisplayItems.albums:
        _openLibrary(NeteaseCollectionKind.album);
        break;
      case _MainMenuDisplayItems.recommendations:
        context.goNamed(Routes.neteaseRecommendations.name);
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
        try {
          if (await _shuffleCoverFlowSongs()) {
            await _navigateToNowPlayingScreen();
          } else if (mounted) {
            await Dialogs.showInfoDialog(
              context: context,
              title: '随机播放',
              content: '请先长按专辑加入当前音源的 Cover Flow。',
            );
          }
        } catch (error) {
          if (mounted) {
            await Dialogs.showInfoDialog(
              context: context,
              title: '随机播放失败',
              content: '$error',
            );
          }
        }
        break;
    }
  }

  Future<bool> _shuffleCoverFlowSongs() async {
    final favorites = ref.read(currentCoverFlowAlbumsProvider);
    if (favorites.isEmpty) return false;
    final settings = ref.read(settingsPreferencesControllerProvider);
    final metadata = settings.musicSource == MusicSource.local
        ? ref.read(localCoverFlowSongsProvider).toList()
        : await _loadNeteaseFavoriteTracks(favorites, settings);
    if (metadata.isEmpty) return false;
    final player = ref.read(audioPlayerServiceProvider.notifier);
    await player.setAudioSource(musicMetadataList: metadata);
    await player.setShuffleMode(true);
    await ref.read(audioPlayerProvider).shuffle();
    await player.nextSong();
    unawaited(player.play());
    return true;
  }

  Future<List<MusicMetadata>> _loadNeteaseFavoriteTracks(
    List<CoverFlowAlbum> albums,
    SettingsPreferencesModel settings,
  ) async {
    final service = ref.read(neteaseServiceProvider);
    final lists = await Future.wait([
      for (final album in albums)
        service.tracks(
          NeteaseCollection(
            id: album.id,
            kind: switch (album.kind) {
              CoverFlowCollectionKind.album => NeteaseCollectionKind.album,
              CoverFlowCollectionKind.playlist =>
                NeteaseCollectionKind.playlist,
              CoverFlowCollectionKind.podcast => NeteaseCollectionKind.podcast,
            },
            title: album.title,
            subtitle: album.firstArtist,
            coverUrl: album.coverUri ?? '',
          ),
        ),
    ]);
    final tracksById = {
      for (final track in lists.expand((tracks) => tracks)) track.id: track,
    };
    return service.playableTracks(
      tracksById.values.toList(),
      format: settings.neteaseAudioFormat,
      mp3Bitrate: settings.neteaseMp3Bitrate,
      flacQuality: settings.neteaseFlacQuality,
    );
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
      case _MainMenuDisplayItems.coverFlow:
      case _MainMenuDisplayItems.artists:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.albumArt;
        break;
      case _MainMenuDisplayItems.albums:
      case _MainMenuDisplayItems.playlists:
      case _MainMenuDisplayItems.podcasts:
        ref.read(splitScreenControllerProvider.notifier).changeSplitScreenType =
            SplitScreenType.netease;
        break;
      case _MainMenuDisplayItems.recommendations:
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
