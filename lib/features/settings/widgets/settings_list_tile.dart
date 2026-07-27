import 'package:classipod/core/constants/app_palette.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/widgets/marquee_text.dart';
import 'package:flutter/cupertino.dart';

class SettingsListTile extends StatelessWidget {
  final String text;
  final String? value;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;
  final Widget? leading;

  const SettingsListTile({
    super.key,
    required this.text,
    this.value,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.heroTag,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final primaryTextStyle = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(
          fontFamily: 'sans-serif',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1,
          color: isSelected
              ? context.appInverseTextColor
              : context.appPrimaryTextColor,
        );
    final strutStyle = StrutStyle.fromTextStyle(
      primaryTextStyle,
      forceStrutHeight: true,
    );
    const textHeightBehavior = TextHeightBehavior();
    final tile = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 30,
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
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 5,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  flex: value == null ? 1 : 7,
                  child: MarqueeText(
                    text,
                    mode: TextScrollMode.bouncing,
                    intervalSpaces: null,
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    pauseOnBounce: const Duration(seconds: 2),
                    style: primaryTextStyle,
                    strutStyle: strutStyle,
                    textHeightBehavior: textHeightBehavior,
                  ),
                ),
                if (value != null)
                  Expanded(
                    flex: 3,
                    child: MarqueeText(
                      value!,
                      textAlign: TextAlign.right,
                      mode: TextScrollMode.bouncing,
                      intervalSpaces: null,
                      delayBefore: const Duration(seconds: 2),
                      pauseBetween: const Duration(seconds: 2),
                      pauseOnBounce: const Duration(seconds: 2),
                      style: primaryTextStyle.copyWith(
                        color: isSelected
                            ? context.appInverseTextColor
                            : context.appSecondaryTextColor,
                      ),
                      strutStyle: strutStyle,
                      textHeightBehavior: textHeightBehavior,
                    ),
                  ),
                if (value == null && isSelected)
                  Icon(
                    CupertinoIcons.right_chevron,
                    color: context.appInverseTextColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return heroTag == null ? tile : Hero(tag: heroTag!, child: tile);
  }
}
