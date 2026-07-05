// ============================================================================
// confirmation_config.dart
//
// Single source of truth for every contextual confirmation dialog in the app.
//
// Why this exists
// ---------------
// Previously each feature called showDialog() with bespoke copy and styling,
// which led to:
//   • duplicated dialog widgets,
//   • drifted button labels ("Exit", "Yes, exit app", "Leave"),
//   • inconsistent destructive treatment.
//
// The ConfirmationConfig is a small, immutable, fully-typed value object that
// fully describes one confirmation surface: title, message, action labels,
// icons, destructive flag, optional warning box and footer.
//
// To add a new confirmation context (e.g. logout, delete account) just add
// a new named factory below — never hardcode a dialog inline.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

@immutable
class ConfirmationConfig {
  // ── Core copy ─────────────────────────────────────────────────────────────
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  // ── Iconography ───────────────────────────────────────────────────────────
  final IconData headerIcon;
  final IconData confirmIcon;
  final IconData cancelIcon;

  // ── Visual treatment ──────────────────────────────────────────────────────
  final Color accentColor;
  final bool destructive;

  // ── Optional extras ───────────────────────────────────────────────────────
  final String? warningText;
  final String footerLabel;
  final IconData footerIcon;
  final Color? footerIconColor;

  const ConfirmationConfig({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.headerIcon,
    required this.confirmIcon,
    required this.cancelIcon,
    required this.accentColor,
    required this.footerLabel,
    required this.footerIcon,
    this.destructive = false,
    this.warningText,
    this.footerIconColor,
  });

  // ── Context-specific presets ──────────────────────────────────────────────

  /// App-level exit confirmation. Only shown from the ROOT destination.
  factory ConfirmationConfig.appExit() => const ConfirmationConfig(
        title: 'Exit App?',
        message: 'Are you sure you want to close OnushilonHub?',
        confirmLabel: 'Exit',
        cancelLabel: 'Stay',
        headerIcon: Icons.logout_rounded,
        confirmIcon: Icons.logout_rounded,
        cancelIcon: Icons.arrow_back_rounded,
        accentColor: AppColors.primary,
        footerLabel: 'Progress auto-saved',
        footerIcon: Icons.shield_outlined,
        footerIconColor: AppColors.primaryLight,
      );

  /// Active gameplay exit confirmation. Distinct copy from app-exit so the
  /// user understands what they are about to lose.
  factory ConfirmationConfig.gameExit() => const ConfirmationConfig(
        title: 'Exit Game?',
        message: 'Your current progress in this game may be lost.',
        confirmLabel: 'Exit Game',
        cancelLabel: 'Continue Playing',
        headerIcon: Icons.sports_esports_rounded,
        confirmIcon: Icons.exit_to_app_rounded,
        cancelIcon: Icons.play_arrow_rounded,
        accentColor: Color(0xFFE65100), // amber-warning, not destructive red
        footerLabel: 'Unsaved progress will be lost',
        footerIcon: Icons.info_outline_rounded,
        footerIconColor: Color(0xFFE65100),
      );

  /// Destructive "reset everything" confirmation used from Settings.
  factory ConfirmationConfig.resetData() => const ConfirmationConfig(
        title: 'Reset All Data?',
        message:
            'This will permanently remove your learning progress, game '
            'statistics, settings, and saved data. This action cannot be undone.',
        confirmLabel: 'Reset Data',
        cancelLabel: 'Cancel',
        headerIcon: Icons.delete_forever_rounded,
        confirmIcon: Icons.delete_forever_rounded,
        cancelIcon: Icons.close_rounded,
        accentColor: Color(0xFFB71C1C),
        destructive: true,
        warningText:
            'This action cannot be undone. All data will be lost forever.',
        footerLabel: 'Cannot be recovered',
        footerIcon: Icons.lock_outline_rounded,
        footerIconColor: Color(0xFFE8A020),
      );
}
