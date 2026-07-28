import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/services/media_cache.dart';
import 'package:classipod/features/menu/controller/home_cover_controller.dart';
import 'package:classipod/features/menu/models/home_cover_snapshot.dart';
import 'package:classipod/features/menu/models/split_screen_type.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimatedAlbumArtScroller extends ConsumerStatefulWidget {
  const AnimatedAlbumArtScroller({
    super.key,
    this.type = SplitScreenType.albumArt,
  });

  final SplitScreenType type;

  @override
  ConsumerState createState() => _AnimatedAlbumArtScrollerState();
}

class _AnimatedAlbumArtScrollerState
    extends ConsumerState<AnimatedAlbumArtScroller>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late final AnimationController _animationController;
  late Animation<Alignment> _alignmentAnimation;
  List<_CoverImage> _images = const [];
  String _signature = '';
  _CoverImage _current = const _CoverImage(
    'default',
    AssetImage(Assets.defaultAlbumCoverImage),
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener(_onAnimationStatus);
    _setRandomAnimationDirection();
    unawaited(_animationController.forward());
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _chooseNextImage();
    _setRandomAnimationDirection();
    unawaited(_animationController.forward(from: 0));
  }

  void _replaceImages(List<_CoverImage> images, String signature) {
    if (!mounted || signature == _signature) return;
    setState(() {
      _signature = signature;
      _images = images;
      _chooseNextImage();
    });
  }

  void _chooseNextImage() {
    if (_images.isEmpty) {
      _current = const _CoverImage(
        'default',
        AssetImage(Assets.defaultAlbumCoverImage),
      );
      return;
    }
    final candidates = _images.length > 1
        ? _images.where((image) => image.key != _current.key).toList()
        : _images;
    _current = candidates[_random.nextInt(candidates.length)];
  }

  void _setRandomAnimationDirection() {
    const corners = [
      [Alignment.topLeft, Alignment.bottomRight],
      [Alignment.topRight, Alignment.bottomLeft],
      [Alignment.bottomLeft, Alignment.topRight],
      [Alignment.bottomRight, Alignment.topLeft],
    ];
    final pair = corners[_random.nextInt(corners.length)];
    _alignmentAnimation = Tween<Alignment>(
      begin: pair.first,
      end: pair.last,
    ).animate(_animationController);
  }

  List<_CoverImage> _availableImages() {
    if (widget.type == SplitScreenType.whiteNoise) {
      return [
        for (final category in WhiteNoiseCategory.values)
          _CoverImage(category.imagePath, AssetImage(category.imagePath)),
      ];
    }

    final settings = ref.watch(settingsPreferencesControllerProvider);
    if (widget.type == SplitScreenType.albumArt) {
      if (settings.musicSource == MusicSource.netease) {
        return _networkImages(
          ref
              .watch(currentCoverFlowAlbumsProvider)
              .map((album) => album.coverUri ?? ''),
        );
      }
      return [
        for (final album in ref.watch(albumDetailsProvider))
          if (album.albumArtPath case final path?)
            if (!album.isOnDevice() || File(path).existsSync())
              _CoverImage(
                path,
                album.isOnDevice() ? FileImage(File(path)) : NetworkImage(path),
              ),
      ];
    }

    final category = switch (widget.type) {
      SplitScreenType.artists => HomeCoverCategory.artists,
      SplitScreenType.albums => HomeCoverCategory.albums,
      SplitScreenType.playlists => HomeCoverCategory.playlists,
      SplitScreenType.podcasts => HomeCoverCategory.podcasts,
      SplitScreenType.recommendations => HomeCoverCategory.recommendations,
      _ => null,
    };
    if (category == null) return const [];
    final snapshot = ref.watch(homeCoverControllerProvider).value;
    return _networkImages(snapshot?.covers(category) ?? const []);
  }

  List<_CoverImage> _networkImages(Iterable<String> urls) => [
    for (final url in urls.where((url) => url.isNotEmpty).toSet())
      _CoverImage(
        url,
        CachedNetworkImageProvider(
          url,
          headers: neteaseImageHeaders,
          cacheManager: PersistentCoverCache.instance,
        ),
      ),
  ];

  @override
  void dispose() {
    _animationController
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _availableImages();
    final signature =
        '${widget.type.name}:${images.map((image) => image.key).join('|')}';
    if (signature != _signature) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _replaceImages(images, signature),
      );
    }

    return RepaintBoundary(
      key: ValueKey(widget.type),
      child: AnimatedAlbumArt(
        animation: _alignmentAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: Image(
            key: ValueKey(_current.key),
            image: _current.provider,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              Assets.defaultAlbumCoverImage,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverImage {
  const _CoverImage(this.key, this.provider);

  final String key;
  final ImageProvider provider;
}

class AnimatedAlbumArt extends AnimatedWidget {
  const AnimatedAlbumArt({
    super.key,
    required Animation<Alignment> animation,
    required this.child,
  }) : super(listenable: animation);

  final Widget child;

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
