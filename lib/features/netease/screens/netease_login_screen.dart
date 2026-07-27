import 'dart:async';
import 'dart:math' as math;

import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/features/backup/services/backup_service.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_service.dart';
import 'package:classipod/features/status_bar/widgets/status_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class NeteaseLoginScreen extends ConsumerStatefulWidget {
  const NeteaseLoginScreen({super.key});

  @override
  ConsumerState<NeteaseLoginScreen> createState() => _NeteaseLoginScreenState();
}

class _NeteaseLoginScreenState extends ConsumerState<NeteaseLoginScreen>
    with CustomScreen {
  Timer? _timer;
  NeteaseQrChallenge? _challenge;
  NeteaseQrStatus? _status;
  String _message = '正在生成二维码…';
  bool _busy = false;

  @override
  String get routeName => Routes.neteaseLogin.name;

  @override
  List<int> get displayItems => const [0];

  @override
  Future<void> onSelectPressed() async {
    if (ref.read(neteaseServiceProvider).profile != null) {
      await _logout();
    } else if (_challenge == null || _status == NeteaseQrStatus.expired) {
      await _createQr();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final profile = await ref.read(neteaseServiceProvider).restoreProfile();
    if (profile != null) {
      if (mounted) setState(() => _message = '${profile.nickname} 已登录');
      return;
    }
    await _createQr();
  }

  Future<void> _createQr() async {
    if (_busy) return;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _challenge = null;
      _status = null;
      _message = '正在生成二维码…';
    });
    try {
      final challenge = await ref.read(neteaseServiceProvider).createQrLogin();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _message = '请使用网易云音乐扫码';
      });
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_checkQr()),
      );
    } catch (error) {
      if (mounted) setState(() => _message = '生成失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkQr() async {
    final challenge = _challenge;
    if (_busy || challenge == null) return;
    _busy = true;
    try {
      final status = await ref
          .read(neteaseServiceProvider)
          .checkQrLogin(challenge.key);
      if (!mounted) return;
      setState(() {
        _status = status;
        _message = switch (status) {
          NeteaseQrStatus.waiting => '等待扫码',
          NeteaseQrStatus.scanned => '已扫码，请在手机上确认',
          NeteaseQrStatus.expired => '二维码已过期，按中心键刷新',
          NeteaseQrStatus.confirmed => '登录成功',
        };
      });
      if (status == NeteaseQrStatus.expired) _timer?.cancel();
      if (status == NeteaseQrStatus.confirmed) {
        _timer?.cancel();
        ref.invalidate(neteaseSessionProvider);
        await ref.read(backupServiceProvider).writeAutomaticBackup();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) context.pop();
      }
    } catch (error) {
      if (mounted) setState(() => _message = '检查失败：$error');
    } finally {
      _busy = false;
    }
  }

  Future<void> _logout() async {
    await ref.read(neteaseServiceProvider).logout();
    await ref.read(backupServiceProvider).writeAutomaticBackup();
    ref.invalidate(neteaseSessionProvider);
    await _createQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.read(neteaseServiceProvider).profile;
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const StatusBar(title: '网易云登录'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(
                  190.0,
                  math.min(
                    constraints.maxWidth - 24,
                    constraints.maxHeight - 42,
                  ),
                );
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_challenge != null && profile == null)
                      ColoredBox(
                        color: CupertinoColors.white,
                        child: QrImageView(
                          data: _challenge!.loginUrl,
                          size: size,
                          padding: const EdgeInsets.all(6),
                        ),
                      )
                    else
                      Icon(
                        profile == null
                            ? CupertinoIcons.qrcode
                            : CupertinoIcons.check_mark_circled_solid,
                        size: math.max(40, size * .45),
                      ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (profile != null)
                      const Text('按中心键退出登录', style: TextStyle(fontSize: 11)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
