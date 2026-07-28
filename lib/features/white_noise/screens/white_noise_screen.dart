import 'dart:async';

import 'package:classipod/core/alerts/dialogs.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:classipod/features/white_noise/controllers/white_noise_controller.dart';
import 'package:classipod/features/white_noise/models/white_noise_sound.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WhiteNoiseScreen extends ConsumerStatefulWidget {
  const WhiteNoiseScreen({super.key});

  @override
  ConsumerState<WhiteNoiseScreen> createState() => _WhiteNoiseScreenState();
}

class _WhiteNoiseScreenState extends ConsumerState<WhiteNoiseScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.whiteNoise.name;

  @override
  List<WhiteNoiseCategory> get displayItems => WhiteNoiseCategory.values;

  @override
  Future<void> onSelectPressed() => _open(displayItems[selectedDisplayItem]);

  Future<void> _open(WhiteNoiseCategory category) async {
    setState(() => selectedDisplayItem = category.index);
    try {
      await ref.read(whiteNoiseControllerProvider.notifier).start(category);
      if (mounted) {
        unawaited(context.pushNamed(Routes.whiteNoisePlayer.name));
      }
    } catch (error) {
      if (mounted) {
        await Dialogs.showInfoDialog(
          context: context,
          title: '白噪音播放失败',
          content: '$error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const StatusBar(title: '白噪音'),
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
                  final category = displayItems[index];
                  return SettingsListTile(
                    text: category.title,
                    value: category == WhiteNoiseCategory.noise ? '白噪音' : '随机',
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.asset(
                        category.imagePath,
                        width: 22,
                        height: 22,
                        fit: BoxFit.cover,
                      ),
                    ),
                    heroTag: category.heroTag,
                    isSelected: selectedDisplayItem == index,
                    onTap: () => _open(category),
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
