import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/media_cache.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NeteaseLibraryScreen extends ConsumerStatefulWidget {
  const NeteaseLibraryScreen({super.key, required this.kind});

  final NeteaseCollectionKind kind;

  @override
  ConsumerState<NeteaseLibraryScreen> createState() =>
      _NeteaseLibraryScreenState();
}

class _NeteaseLibraryScreenState extends ConsumerState<NeteaseLibraryScreen>
    with CustomScreen {
  List<NeteaseCollection> _collections = const [];
  String? _error;
  bool _loading = true;

  @override
  String get routeName => Routes.neteaseLibrary.name;

  @override
  List<Object?> get displayItems =>
      _collections.isEmpty ? const [null] : _collections;

  String get _title => switch (widget.kind) {
    NeteaseCollectionKind.album => '专辑',
    NeteaseCollectionKind.playlist => '歌单',
    NeteaseCollectionKind.podcast => '播客',
  };

  @override
  Future<void> onSelectPressed() async {
    if (_collections.isEmpty) {
      await _load();
      return;
    }
    _open(_collections[selectedDisplayItem]);
  }

  @override
  Future<void> onSelectLongPress() async {
    if (_collections.isEmpty) {
      return;
    }
    await _toggleCoverFlow(_collections[selectedDisplayItem]);
  }

  Future<void> _toggleCoverFlow(NeteaseCollection collection) async {
    setState(() => selectedDisplayItem = _collections.indexOf(collection));
    await ref
        .read(coverFlowFavoritesControllerProvider.notifier)
        .toggleNetease(collection);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final collections = await ref
          .read(neteaseServiceProvider)
          .library(widget.kind);
      if (!mounted) return;
      await ref
          .read(coverFlowFavoritesControllerProvider.notifier)
          .hydrateNeteaseCovers(collections);
      setState(() {
        _collections = collections;
        selectedDisplayItem = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(NeteaseCollection collection) {
    setState(() => selectedDisplayItem = _collections.indexOf(collection));
    unawaited(
      context.pushNamed(
        Routes.coverFlowSelection.name,
        extra: CoverFlowAlbum(
          source: CoverFlowAlbumSource.netease,
          id: collection.id,
          title: collection.title,
          firstArtist: CoverFlowAlbum.firstPerformer(collection.subtitle),
          coverUri: collection.coverUrl,
          kind: switch (collection.kind) {
            NeteaseCollectionKind.album => CoverFlowCollectionKind.album,
            NeteaseCollectionKind.playlist => CoverFlowCollectionKind.playlist,
            NeteaseCollectionKind.podcast => CoverFlowCollectionKind.podcast,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = ref
        .watch(coverFlowFavoritesControllerProvider)
        .netease
        .map((album) => album.id)
        .toSet();
    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: _title),
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
                  if (_collections.isEmpty) {
                    return SettingsListTile(
                      text: _loading ? '正在加载…' : _error ?? '暂无内容',
                      value: _loading ? null : '选择重试',
                      isSelected: true,
                      onTap: () => unawaited(_load()),
                    );
                  }
                  final collection = _collections[index];
                  final heroTag = CoverFlowAlbum(
                    source: CoverFlowAlbumSource.netease,
                    id: collection.id,
                    title: collection.title,
                    firstArtist: CoverFlowAlbum.firstPerformer(
                      collection.subtitle,
                    ),
                    kind: switch (collection.kind) {
                      NeteaseCollectionKind.album =>
                        CoverFlowCollectionKind.album,
                      NeteaseCollectionKind.playlist =>
                        CoverFlowCollectionKind.playlist,
                      NeteaseCollectionKind.podcast =>
                        CoverFlowCollectionKind.podcast,
                    },
                  ).heroTag;
                  return SettingsListTile(
                    heroTag: heroTag,
                    leading: collection.coverUrl.isEmpty
                        ? null
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: collection.coverUrl,
                              httpHeaders: neteaseImageHeaders,
                              cacheManager: PersistentCoverCache.instance,
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                              memCacheWidth: 104,
                              errorWidget: (_, _, _) =>
                                  const SizedBox(width: 26, height: 26),
                            ),
                          ),
                    text: collection.title,
                    value: collection.subtitle.isEmpty
                        ? collection.trackCount == null
                              ? null
                              : '${collection.trackCount} 首'
                        : '${favoriteIds.contains(collection.id) ? '★ ' : ''}${collection.subtitle}',
                    isSelected: selectedDisplayItem == index,
                    onTap: () => _open(collection),
                    onLongPress: () async {
                      await ref
                          .read(deviceButtonsServiceProvider.notifier)
                          .buttonPressVibrate();
                      await _toggleCoverFlow(collection);
                    },
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
