import 'package:classipod/features/app_startup/controllers/splash_controller.dart';
import 'package:classipod/features/app_startup/screens/splash_screen.dart';
import 'package:classipod/l10n/generated/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SplashController extends SplashControllerNotifier {
  static int buildCount = 0;

  @override
  Future<void> build() async => buildCount++;
}

void main() {
  testWidgets('starts the splash controller when shown', (tester) async {
    _SplashController.buildCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splashControllerProvider.overrideWith(_SplashController.new),
        ],
        child: const CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SplashScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(_SplashController.buildCount, 1);
  });
}
