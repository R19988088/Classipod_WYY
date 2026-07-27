import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/music/cover_flow/models/cover_flow_album.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArtistAlbumsScreen extends ConsumerStatefulWidget {
  const ArtistAlbumsScreen({super.key, required this.artistName});

  final String artistName;

  @override
  ConsumerState createState() => _ArtistAlbumsScreenState();
}

class _ArtistAlbumsScreenState extends ConsumerState<ArtistAlbumsScreen>
    with CustomScreen {
  bool get _allArtists => widget.artistName == '_';

  @override
  String get routeName => Uri.encodeComponent(widget.artistName);

  @override
  List<CoverFlowAlbum> get displayItems => ref
      .read(currentCoverFlowAlbumsProvider)
      .where((album) => _allArtists || album.firstArtist == widget.artistName)
      .toList();

  @override
  void onSelectPressed() => _open(displayItems[selectedDisplayItem]);

  void _open(CoverFlowAlbum album) {
    setState(() => selectedDisplayItem = displayItems.indexOf(album));
    unawaited(context.pushNamed(Routes.coverFlowSelection.name, extra: album));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentCoverFlowAlbumsProvider);
    return CupertinoPageScaffold(
      child: Column(
        children: [
          StatusBar(
            title: _allArtists
                ? context.localization.allAlbums
                : widget.artistName,
          ),
          Flexible(
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
                itemBuilder: (context, index) => SettingsListTile(
                  text: displayItems[index].title,
                  value: displayItems[index].firstArtist,
                  heroTag: displayItems[index].heroTag,
                  isSelected: selectedDisplayItem == index,
                  onTap: () => _open(displayItems[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
