import 'dart:async';

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/custom_screen_elements/custom_page_screen.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/now_playing/widgets/album_reflective_art.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CoverFlowScreen extends ConsumerStatefulWidget {
  const CoverFlowScreen({super.key});

  @override
  ConsumerState createState() => _CoverFlowScreenState();
}

class _CoverFlowScreenState extends ConsumerState<CoverFlowScreen>
    with CustomPageScreen {
  int _wheelTarget = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_hydrateNeteaseCovers());
  }

  Future<void> _hydrateNeteaseCovers() async {
    final settings = ref.read(settingsPreferencesControllerProvider);
    if (settings.musicSource == MusicSource.local) return;
    try {
      final service = ref.read(neteaseServiceProvider);
      final collections = await Future.wait([
        service.library(NeteaseCollectionKind.album),
        service.library(NeteaseCollectionKind.playlist),
        service.library(NeteaseCollectionKind.podcast),
      ]);
      await ref
          .read(coverFlowFavoritesControllerProvider.notifier)
          .hydrateNeteaseCovers(collections.expand((items) => items));
    } on Object {
      // The existing shelf remains usable while offline.
    }
  }

  @override
  String get routeName => Routes.coverFlow.name;

  @override
  double get viewPortFraction => .54;

  @override
  List<CoverFlowAlbum> get displayItems =>
      ref.read(currentCoverFlowAlbumsProvider);

  @override
  void onSelectPressed() => _chooseAlbum(selectedDisplayItem);

  void _chooseAlbum(int index) {
    final albumDetail = ref
        .read(currentCoverFlowAlbumsProvider)
        .elementAt(index);
    unawaited(
      context.pushNamed(Routes.coverFlowSelection.name, extra: albumDetail),
    );
  }

  @override
  Future<void> rotateForward() => _animateWheel(1);

  @override
  Future<void> rotateBackward() => _animateWheel(-1);

  Future<void> _animateWheel(int delta) async {
    final current = pageController.hasClients
        ? (pageController.page ?? _wheelTarget.toDouble()).round()
        : _wheelTarget;
    _wheelTarget = (_wheelTarget == current ? current : _wheelTarget) + delta;
    _wheelTarget = _wheelTarget.clamp(0, displayItems.length - 1);
    await pageController.animateToPage(
      _wheelTarget,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentCoverFlowAlbumsProvider);
    if (displayItems.isEmpty) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            StatusBar(title: Routes.coverFlow.title(context)),
            const Expanded(
              child: EmptyStateWidget(emptyDescription: '长按专辑可加入 Cover Flow'),
            ),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(title: Routes.coverFlow.title(context)),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 230,
                  child: AnimatedBuilder(
                    animation: pageController,
                    builder: (context, child) {
                      final page = pageController.hasClients
                          ? pageController.page ?? currentPage
                          : currentPage;
                      return PageView.builder(
                        controller: pageController,
                        itemCount: displayItems.length,
                        onPageChanged: (index) => _wheelTarget = index,
                        itemBuilder: (context, index) {
                          final double relativePosition = index - page;
                          return _RetainedCoverPage(
                            child: GestureDetector(
                              onTap: relativePosition == 0
                                  ? () => _chooseAlbum(index)
                                  : () async => pageController.animateToPage(
                                      index,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.ease,
                                    ),
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.003)
                                  ..scaleByDouble(
                                    (1 - relativePosition.abs()).clamp(
                                          0.2,
                                          0.6,
                                        ) +
                                        0.4,
                                    (1 - relativePosition.abs()).clamp(
                                          0.2,
                                          0.6,
                                        ) +
                                        0.4,
                                    (1 - relativePosition.abs()).clamp(
                                          0.2,
                                          0.6,
                                        ) +
                                        0.4,
                                    1,
                                  )
                                  ..rotateY(relativePosition * 0.9),
                                alignment: relativePosition >= 0
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: AlbumReflectiveArt(
                                  imageWidth: 230 *
                                      ref
                                          .read(settingsPreferencesControllerProvider)
                                          .coverRatio,
                                  thumbnailPath: displayItems[index].coverUri,
                                  isOnDevice:
                                      displayItems[index].source ==
                                      CoverFlowAlbumSource.local,
                                  heroTag: displayItems[index].heroTag,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          displayItems[selectedDisplayItem].title,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          displayItems[selectedDisplayItem].firstArtist,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RetainedCoverPage extends StatefulWidget {
  const _RetainedCoverPage({required this.child});

  final Widget child;

  @override
  State<_RetainedCoverPage> createState() => _RetainedCoverPageState();
}

class _RetainedCoverPageState extends State<_RetainedCoverPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
