import 'dart:io';

import 'package:classipod/core/constants/app_palette.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/services/media_cache.dart';
import 'package:classipod/features/music/playlist/models/playlist_model.dart';
import 'package:flutter/cupertino.dart';

class PlaylistListTile extends StatelessWidget {
  final PlaylistModel playlistModel;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isCoverFlowFavorite;
  final String? coverUri;
  final String? heroTag;

  const PlaylistListTile({
    super.key,
    required this.playlistModel,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.isCoverFlowFavorite = false,
    this.coverUri,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme =
        CupertinoTheme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkTheme
        ? AppPalette.darkListTileBorderColor
        : AppPalette.lightListTileBorderColor;
    final Border? tileBorder = isSelected
        ? null
        : Border(bottom: BorderSide(color: borderColor));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppPalette.selectedTileGradientColor1,
                      AppPalette.selectedTileGradientColor2,
                    ],
                  )
                : null,
            border: tileBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                if (coverUri != null)
                  Hero(
                    tag: heroTag ?? 'playlist-${playlistModel.name}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image(
                        image: playlistModel.songs.first.isOnDevice
                            ? FileImage(File(coverUri!))
                            : NetworkImage(
                                coverUri!,
                                headers: neteaseImageHeaders,
                              ),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: CupertinoColors.black,
                          child: SizedBox(width: 46, height: 46),
                        ),
                      ),
                    ),
                  ),
                if (coverUri != null) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlistModel.name,
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? context.appInverseTextColor
                                  : context.appPrimaryTextColor,
                            ),
                        maxLines: 1,
                      ),
                      Text(
                        context.localization.nSongs(playlistModel.songs.length),
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(
                              color: isSelected
                                  ? context.appInverseTextColor
                                  : context.appSecondaryTextColor,
                            ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (isCoverFlowFavorite)
                  Icon(
                    CupertinoIcons.star_fill,
                    size: 16,
                    color: isSelected
                        ? context.appInverseTextColor
                        : AppPalette.selectedTileGradientColor2,
                  ),
                if (isSelected)
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: context.appInverseTextColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
