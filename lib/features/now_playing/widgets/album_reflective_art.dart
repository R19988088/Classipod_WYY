import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:classipod/core/constants/app_palette.dart';
import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/services/media_cache.dart';
import 'package:flutter/cupertino.dart';

class AlbumReflectiveArt extends StatefulWidget {
  final String? thumbnailPath;
  final bool isOnDevice;
  final double? imageWidth;
  final String heroTag;
  final bool tiltedImage;
  final bool flipOnEnter;
  final String? assetPath;

  const AlbumReflectiveArt({
    super.key,
    this.thumbnailPath,
    this.isOnDevice = true,
    this.imageWidth,
    required this.heroTag,
    this.tiltedImage = false,
    this.flipOnEnter = false,
    this.assetPath,
  });

  @override
  State<AlbumReflectiveArt> createState() => _AlbumReflectiveArtState();
}

class _AlbumReflectiveArtState extends State<AlbumReflectiveArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    unawaited(_controller.forward());
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _imageProvider() {
    if (widget.assetPath case final assetPath?) {
      return AssetImage(assetPath);
    }
    if (widget.thumbnailPath case final thumbnailPath?) {
      return widget.isOnDevice
          ? FileImage(File(thumbnailPath))
          : CachedNetworkImageProvider(
              thumbnailPath,
              headers: neteaseImageHeaders,
              cacheManager: PersistentCoverCache.instance,
            );
    }
    return const AssetImage(Assets.defaultAlbumCoverImage);
  }

  @override
  Widget build(BuildContext context) {
    late final Matrix4 transform;
    if (widget.tiltedImage) {
      transform = Matrix4.identity()
        ..setEntry(3, 2, 0.003)
        ..rotateY(-0.12);
    } else {
      transform = Matrix4.identity();
    }

    final isDarkTheme =
        CupertinoTheme.of(context).brightness == Brightness.dark;
    final overlayTopColor = isDarkTheme
        ? AppPalette.darkReflectionOverlayColor1
        : const Color(0x66FFFFFF);
    final overlayBottomColor = isDarkTheme
        ? AppPalette.darkReflectionOverlayColor2
        : const Color(0xFFFFFFFF);
    final overlayBorderColor = isDarkTheme
        ? CupertinoColors.black
        : CupertinoColors.white;

    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            late final Widget sourceWidget;
            late final Widget destinationWidget;
            switch (flightDirection) {
              case HeroFlightDirection.push:
                sourceWidget = fromHeroContext.widget;
                destinationWidget = toHeroContext.widget;
              case HeroFlightDirection.pop:
                sourceWidget = toHeroContext.widget;
                destinationWidget = fromHeroContext.widget;
            }
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                if (animation.value < 0.01 || animation.value > 0.999) {
                  unawaited(_controller.forward());
                } else if (animation.isAnimating) {
                  _controller.reset();
                }
                return Transform(
                  transform: Matrix4.identity()..rotateY(animation.value * pi),
                  alignment: Alignment.center,
                  child: (animation.value > 0.5)
                      ? Transform.flip(flipX: true, child: destinationWidget)
                      : child,
                );
              },
              child: sourceWidget,
            );
          },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Transform(
          transform: widget.flipOnEnter
              ? (Matrix4.identity()..rotateY((1 - _animation.value) * pi))
              : transform,
          alignment: Alignment.center,
          child: child,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const reflectionRatio = 1 / 3;
            final availableWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : widget.imageWidth ?? 200;
            final availableHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : double.infinity;
            final requestedWidth = widget.imageWidth ?? availableWidth;
            final coverSize = min(
              min(requestedWidth, availableWidth),
              availableHeight / (1 + reflectionRatio),
            );
            final reflectionHeight = coverSize * reflectionRatio;

            Widget coverImage({required double height}) => Image(
              image: _imageProvider(),
              errorBuilder: (_, _, _) => Image.asset(
                Assets.defaultAlbumCoverImage,
                height: height,
                width: coverSize,
                fit: BoxFit.cover,
              ),
              height: height,
              width: coverSize,
              alignment: Alignment.bottomCenter,
              fit: BoxFit.cover,
            );

            return SizedBox(
              height: coverSize + reflectionHeight,
              width: coverSize,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: coverSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: .28),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: coverImage(height: coverSize),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _animation,
                    child: SizedBox(
                      height: reflectionHeight,
                      width: coverSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.flip(
                            flipY: true,
                            child: coverImage(height: reflectionHeight),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                                right: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                                bottom: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [overlayTopColor, overlayBottomColor],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
