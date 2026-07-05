import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

enum AnswerState { idle, selected, correct, wrong }

class GameAnswerTile extends StatelessWidget {
  final String label;
  final AnswerState state;
  final VoidCallback? onTap;
  final int index;
  final TextStyle? labelStyle;

  const GameAnswerTile({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
    this.index = 0,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData? trailingIcon;

    switch (state) {
      case AnswerState.correct:
        bgColor = AppColors.correctGreenLight;
        borderColor = AppColors.correctGreen;
        textColor = AppColors.correctGreen;
        trailingIcon = Icons.check_circle_rounded;
        break;
      case AnswerState.wrong:
        bgColor = AppColors.errorRedLight;
        borderColor = AppColors.errorRed;
        textColor = AppColors.errorRed;
        trailingIcon = Icons.cancel_rounded;
        break;
      case AnswerState.selected:
        bgColor = colorScheme.primaryContainer;
        borderColor = colorScheme.primary;
        textColor = colorScheme.onPrimaryContainer;
        trailingIcon = null;
        break;
      case AnswerState.idle:
        bgColor = colorScheme.surface;
        borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);
        textColor = colorScheme.onSurface;
        trailingIcon = null;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      switch (state) {
        case AnswerState.correct:
          bgColor = AppColors.correctGreen.withValues(alpha: 0.2);
          break;
        case AnswerState.wrong:
          bgColor = AppColors.errorRed.withValues(alpha: 0.2);
          break;
        default:
          break;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTokens.durationMedium),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: state == AnswerState.idle
              ? () {
                  HapticFeedback.lightImpact();
                  onTap?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
              vertical: AppTokens.space16,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: textTheme.labelMedium?.copyWith(
                      color: borderColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    label,
                    style: (labelStyle ?? textTheme.bodyLarge)?.copyWith(
                      color: textColor,
                      fontWeight: labelStyle != null
                          ? (labelStyle!.fontWeight ?? FontWeight.w500)
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppTokens.space8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: AppTokens.durationMedium),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      trailingIcon,
                      key: ValueKey(state),
                      color: borderColor,
                      size: 22,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
