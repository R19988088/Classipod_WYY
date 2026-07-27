import 'dart:async';

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum NeteaseRecommendationKind { daily, privateRadar }

extension on NeteaseRecommendationKind {
  String get title => switch (this) {
    NeteaseRecommendationKind.daily => '每日推荐',
    NeteaseRecommendationKind.privateRadar => '私人雷达',
  };
}

String neteaseRecommendationHeroTag(NeteaseRecommendationKind kind) =>
    neteaseRecommendationAlbum(kind).heroTag;

CoverFlowAlbum neteaseRecommendationAlbum(NeteaseRecommendationKind kind) {
  return CoverFlowAlbum(
    source: CoverFlowAlbumSource.netease,
    id: kind.name,
    title: kind.title,
    firstArtist: '网易云音乐',
    kind: CoverFlowCollectionKind.playlist,
  );
}

class NeteaseRecommendationSelection {
  const NeteaseRecommendationSelection(this.kind);

  final NeteaseRecommendationKind kind;

  CoverFlowAlbum get album => neteaseRecommendationAlbum(kind);
}

class NeteaseRecommendationsScreen extends ConsumerStatefulWidget {
  const NeteaseRecommendationsScreen({super.key});

  @override
  ConsumerState<NeteaseRecommendationsScreen> createState() =>
      _NeteaseRecommendationsScreenState();
}

class _NeteaseRecommendationsScreenState
    extends ConsumerState<NeteaseRecommendationsScreen>
    with CustomScreen {
  static const _items = NeteaseRecommendationKind.values;

  @override
  String get routeName => Routes.neteaseRecommendations.name;

  @override
  List<NeteaseRecommendationKind> get displayItems => _items;

  @override
  void onSelectPressed() => _open(displayItems[selectedDisplayItem]);

  void _open(NeteaseRecommendationKind kind) {
    setState(() => selectedDisplayItem = displayItems.indexOf(kind));
    unawaited(
      context.pushNamed(
        Routes.coverFlowSelection.name,
        extra: NeteaseRecommendationSelection(kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const StatusBar(title: '推荐'),
          Expanded(
            child: CupertinoScrollbar(
              controller: scrollController,
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayItems.length,
                prototypeItem: SettingsListTile(
                  text: '',
                  isSelected: false,
                  onTap: () {},
                ),
                itemBuilder: (context, index) {
                  final kind = displayItems[index];
                  return SettingsListTile(
                    text: kind.title,
                    value: switch (kind) {
                      NeteaseRecommendationKind.daily => '每日歌曲',
                      NeteaseRecommendationKind.privateRadar => '每日更新',
                    },
                    heroTag: neteaseRecommendationHeroTag(kind),
                    isSelected: selectedDisplayItem == index,
                    onTap: () => _open(kind),
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
