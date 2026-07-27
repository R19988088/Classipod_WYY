import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/widgets/display_list_tile.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArtistsSelectionScreen extends ConsumerStatefulWidget {
  const ArtistsSelectionScreen({super.key});

  @override
  ConsumerState createState() => _ArtistsSelectionScreenState();
}

class _ArtistsSelectionScreenState extends ConsumerState<ArtistsSelectionScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.artists.name;

  @override
  int get extraDisplayItems => _isNetease ? 0 : 1;

  @override
  List<String> get displayItems {
    if (_isNetease) {
      return _neteaseArtists.map((artist) => artist.name).toList();
    }
    final artists = ref
        .read(currentCoverFlowAlbumsProvider)
        .map((album) => album.firstArtist)
        .where((artist) => artist.isNotEmpty)
        .toSet()
        .toList();
    artists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return artists;
  }

  bool get _isNetease =>
      ref.read(settingsPreferencesControllerProvider).musicSource ==
      MusicSource.netease;

  List<NeteaseArtist> get _neteaseArtists {
    final artists = [...?ref.read(neteaseArtistsProvider).value];
    artists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return artists;
  }

  @override
  void onSelectPressed() => _selectArtist(selectedDisplayItem);

  void _selectArtist(int index) {
    setState(() => selectedDisplayItem = index);
    if (_isNetease) {
      unawaited(
        context.pushNamed(
          Routes.artistTracks.name,
          extra: _neteaseArtists[index],
        ),
      );
      return;
    }
    context.goNamed(
      Routes.artistAlbums.name,
      pathParameters: {
        'artistName': index == 0 ? '_' : displayItems[index - 1],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final neteaseArtists = _isNetease
        ? ref.watch(neteaseArtistsProvider)
        : null;
    if (!_isNetease) ref.watch(currentCoverFlowAlbumsProvider);
    if (neteaseArtists?.hasError == true) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: Routes.artists.title(context)),
            Expanded(
              child: ListView(
                children: [
                  SettingsListTile(
                    text: '${neteaseArtists!.error}',
                    value: '选择重试',
                    isSelected: true,
                    onTap: () => ref.invalidate(neteaseArtistsProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (neteaseArtists?.isLoading == true) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: Routes.artists.title(context)),
            const Expanded(
              child: EmptyStateWidget(emptyDescription: '正在读取艺术家…'),
            ),
          ],
        ),
      );
    }
    if (displayItems.isEmpty) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: Routes.artists.title(context)),
            Expanded(
              child: EmptyStateWidget(
                emptyDescription: _isNetease
                    ? '网易云中暂无收藏艺术家'
                    : 'Cover Flow 中暂无收藏专辑',
              ),
            ),
          ],
        ),
      );
    }
    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: Routes.artists.title(context)),
          Flexible(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length + extraDisplayItems,
                prototypeItem: const DisplayListTile(
                  text: '',
                  isSelected: false,
                ),
                itemBuilder: (context, index) => DisplayListTile(
                  text: !_isNetease && index == 0
                      ? context.localization.allAlbums
                      : displayItems[index - extraDisplayItems],
                  isSelected: selectedDisplayItem == index,
                  onTap: () => _selectArtist(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
