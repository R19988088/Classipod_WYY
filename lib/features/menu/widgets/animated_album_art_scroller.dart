import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/services/media_cache.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/menu/models/split_screen_type.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimatedAlbumArtScroller extends ConsumerStatefulWidget {
  const AnimatedAlbumArtScroller({super.key});

  @override
  ConsumerState createState() => _AnimatedAlbumArtScrollerState();
}

class _AnimatedAlbumArtScrollerState
    extends ConsumerState<AnimatedAlbumArtScroller>
    with SingleTickerProviderStateMixin {
  ImageProvider _albumArtImage = const AssetImage(
    Assets.defaultAlbumCoverImage,
  );
  late final AnimationController _animationController;
  late Animation<Alignment> _alignmentAnimation;
  double alignment = 0;
  bool _isEmptyState = false;

  void _getRandomAlbumArt() {
    final albumDetails = ref.read(albumDetailsProvider);
    final settings = ref.read(settingsPreferencesControllerProvider);
    if (settings.musicSource == MusicSource.netease) {
      final covers = ref
          .read(currentCoverFlowAlbumsProvider)
          .where((album) => album.coverUri?.isNotEmpty == true)
          .toList();
      if (covers.isNotEmpty) {
        final cover = covers
            .elementAt(Random().nextInt(covers.length))
            .coverUri!;
        setState(() {
          _isEmptyState = false;
          _albumArtImage = CachedNetworkImageProvider(
            cover,
            headers: neteaseImageHeaders,
            cacheManager: PersistentCoverCache.instance,
          );
        });
        return;
      }
    }
    if (albumDetails.isEmpty) {
      setState(() {
        _isEmptyState = true;
      });
      return;
    }

    final albumsWithArtwork = albumDetails.where((album) {
      final albumArtPath = album.albumArtPath;
      if (albumArtPath == null) {
        return false;
      }
      return !album.isOnDevice() || File(albumArtPath).existsSync();
    }).toList();

    setState(() {
      _isEmptyState = false;
      if (albumsWithArtwork.isEmpty) {
        _albumArtImage = const AssetImage(Assets.defaultAlbumCoverImage);
      } else {
        final randomAlbum = albumsWithArtwork.elementAt(
          Random().nextInt(albumsWithArtwork.length),
        );
        _albumArtImage = randomAlbum.isOnDevice()
            ? FileImage(File(randomAlbum.albumArtPath!))
            : NetworkImage(randomAlbum.albumArtPath!);
      }
    });
  }

  void _setRandomAnimationDirection() {
    final randomNumber = Random().nextInt(4);
    if (randomNumber == 0) {
      _alignmentAnimation = Tween<Alignment>(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).animate(_animationController);
    } else if (randomNumber == 1) {
      _alignmentAnimation = Tween<Alignment>(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).animate(_animationController);
    } else if (randomNumber == 2) {
      _alignmentAnimation = Tween<Alignment>(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).animate(_animationController);
    } else {
      _alignmentAnimation = Tween<Alignment>(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
      ).animate(_animationController);
    }
  }

  void _repeatAnimation() {
    if (_animationController.isCompleted) {
      _setRandomAnimationDirection();
      _getRandomAlbumArt();
      unawaited(_animationController.repeat(count: 1));
    }
  }

  @override
  void initState() {
    super.initState();
    _getRandomAlbumArt();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (!_isEmptyState) {
      _setRandomAnimationDirection();
      unawaited(_animationController.forward());
      _animationController.addListener(_repeatAnimation);
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_repeatAnimation);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmptyState) {
      return EmptyStateWidget(
        emptyDescription: context.localization.noMusicFilesFound,
      );
    }

    return RepaintBoundary(
      key: const ValueKey(SplitScreenType.albumArt),
      child: AnimatedAlbumArt(
        animation: _alignmentAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: Image(
            key: ValueKey(_albumArtImage),
            image: _albumArtImage,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                Assets.defaultAlbumCoverImage,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnimatedAlbumArt extends AnimatedWidget {
  final Widget child;

  const AnimatedAlbumArt({
    super.key,
    required Animation<Alignment> animation,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<Alignment>;
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 1 / 2,
        child: ClipRect(
          child: Transform.scale(
            scale: 1.5,
            alignment: animation.value,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
