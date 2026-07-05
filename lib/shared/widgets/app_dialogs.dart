// ============================================================================
// app_dialogs.dart
//
// Single entry point for showing any confirmation dialog in OnushilonHub.
//
// Architecture
// ------------
// AppDialogs no longer encodes copy or styling for individual contexts.
// Instead it renders a generic [_AppDialog] driven by a [ConfirmationConfig].
// Each context (app exit, game exit, reset data, …) is just a named factory
// on ConfirmationConfig — there is exactly one dialog widget tree.
//
// Public API
// ----------
//   AppDialogs.show(context, ConfirmationConfig.someContext())
//   AppDialogs.showAppExit(context)          → bool (true == confirmed)
//   AppDialogs.showGameExit(context)         → bool
//   AppDialogs.showResetData(context)        → bool
//
// Back-compat helpers kept so existing call sites continue to compile:
//   AppDialogs.showExit(context)             → Future<bool?>
//   AppDialogs.showResetProgress(context)    → Future<bool?>
// ============================================================================

import 'package:flutter/material.dart';

import 'package:onushilonhub/core/dialogs/confirmation_config.dart';
import 'package:onushilonhub/core/theme/app_tokens.dart';

abstract class AppDialogs {
  // ── Generic entry point ───────────────────────────────────────────────────

  /// Shows a confirmation dialog described by [config].
  /// Resolves with `true` when the user confirms, `false` otherwise
  /// (including dismiss via barrier / back).
  static Future<bool> show(
    BuildContext context,
    ConfirmationConfig config,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _AppDialog(config: config),
    );
    return result ?? false;
  }

  // ── Context-specific helpers (preferred) ──────────────────────────────────

  static Future<bool> showAppExit(BuildContext context) =>
      show(context, ConfirmationConfig.appExit());

  static Future<bool> showGameExit(BuildContext context) =>
      show(context, ConfirmationConfig.gameExit());

  static Future<bool> showResetData(BuildContext context) =>
      show(context, ConfirmationConfig.resetData());

  // ── Back-compat shims (return Future<bool?> to match old signatures) ──────

  static Future<bool?> showExit(BuildContext context) async =>
      showAppExit(context);

  static Future<bool?> showResetProgress(BuildContext context) async =>
      showResetData(context);
}

// ── Generic dialog shell ─────────────────────────────────────────────────────

class _AppDialog extends StatelessWidget {
  final ConfirmationConfig config;
  const _AppDialog({required this.config});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coloured header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: config.accentColor,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(config.headerIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: AppTokens.space12),
                Text(
                  config.title,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  config.message,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Optional warning box (destructive contexts) ─────────────────
          if (config.warningText != null)
            _WarningBox(text: config.warningText!),

          // ── Buttons ─────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              config.warningText != null ? 14 : 20,
              20,
              8,
            ),
            child: Column(
              children: [
                _PrimaryButton(
                  label: config.confirmLabel,
                  icon: config.confirmIcon,
                  color: config.accentColor,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: AppTokens.space10),
                _CancelButton(
                  label: config.cancelLabel,
                  icon: config.cancelIcon,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  config.footerIcon,
                  size: 14,
                  color: config.footerIconColor ?? colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  config.footerLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;
  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFFBF360C),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle:
              textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _CancelButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle:
              textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
