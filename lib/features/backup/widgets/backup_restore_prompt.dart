import 'package:classipod/core/alerts/dialogs.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/features/app_startup/controllers/splash_controller.dart';
import 'package:classipod/features/backup/services/backup_service.dart';
import 'package:classipod/features/music/cover_flow/controllers/cover_flow_favorites_controller.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/music_source.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupRestorePrompt extends ConsumerStatefulWidget {
  const BackupRestorePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackupRestorePrompt> createState() =>
      _BackupRestorePromptState();
}

class _BackupRestorePromptState extends ConsumerState<BackupRestorePrompt> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final backup = await ref
          .read(backupServiceProvider)
          .readAutomaticBackup();
      if (backup == null || !mounted) return;
      final restore = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('发现 ClassiPod 备份'),
          content: Text(
            '备份时间：${backup.createdAt.toLocal()}\n是否载入设置、登录状态和 Cover Flow 收藏？',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不载入'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('载入'),
            ),
          ],
        ),
      );
      if (restore != true) return;
      await ref.read(backupServiceProvider).restore(backup);
      await ref
          .read(sharedPreferencesWithCacheProvider)
          .requireValue
          .reloadCache();
      ref.invalidate(settingsPreferencesControllerProvider);
      ref.invalidate(coverFlowFavoritesControllerProvider);
      ref.invalidate(neteaseServiceProvider);
      ref.invalidate(neteaseSessionProvider);
      // The splash notifier can retain the pre-restore initialization result.
      // Recreate it after the settings cache has been refreshed so a restored
      // Netease source never enters the local file scanner.
      ref.invalidate(splashControllerProvider);
      final restoredSettings = ref.read(settingsPreferencesControllerProvider);
      if (restoredSettings.musicSource == MusicSource.netease) {
        await ref.read(neteaseServiceProvider).restoreProfile();
        await ref
            .read(settingsPreferencesControllerProvider.notifier)
            .setInitialRepeatMode();
        // Netease has no local metadata scan. Enter the menu directly after
        // restoring it instead of routing through the scanner splash.
        ref.read(routerProvider).goNamed(Routes.menu.name);
      } else {
        ref.read(routerProvider).goNamed(Routes.splash.name);
      }
    } catch (error) {
      if (mounted) {
        await Dialogs.showInfoDialog(
          context: context,
          title: '备份载入失败',
          content: '$error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
