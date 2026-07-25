import 'dart:async';

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
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
    context.goNamed(
      Routes.neteaseTracks.name,
      pathParameters: {'kind': widget.kind.name},
      extra: collection,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  return SettingsListTile(
                    text: collection.title,
                    value: collection.subtitle.isEmpty
                        ? collection.trackCount == null
                              ? null
                              : '${collection.trackCount} 首'
                        : collection.subtitle,
                    isSelected: selectedDisplayItem == index,
                    onTap: () => _open(collection),
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
