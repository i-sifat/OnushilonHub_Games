import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/font_size_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../database/database_service.dart';
import '../../../shared/widgets/app_dialogs.dart';

const _kFeedbackEmail = 'murshedalam850@gmail.com';
const _kGithubUrl = 'https://github.com/i-sifat';
const _kRepoUrl = 'https://github.com/i-sifat/onushilonhub';
const _kAppVersion = '1.0.2';
const _kAvatarUrl =
    'https://avatars.githubusercontent.com/u/142529114?v=4';

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.screenPaddingH,
          vertical: AppTokens.space12,
        ),
        children: [
          // ── APPEARANCE ──────────────────────────────────────────────────
          const _SectionLabel(label: 'Appearance'),
          _GroupCard(children: [
            _ThemeTile(
              icon: Icons.light_mode_rounded,
              label: 'Theme',
              subtitle: _modeLabel(currentMode),
              onTap: () => _showThemeDialog(context, ref, currentMode),
            ),
            _Divider(),
            _RowTile(
              icon: Icons.format_size_rounded,
              label: 'Font size',
              subtitle: currentFontSize.label,
              onTap: () =>
                  _showFontSizeSheet(context, ref, currentFontSize),
            ),
          ]),

          const _SectionLabel(label: 'Privacy'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.security_rounded,
              label: 'Privacy',
              subtitle: 'Manage your data',
              onTap: () => _showManageDataSheet(context),
            ),
          ]),

          const _SectionLabel(label: 'Support'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.mail_outline_rounded,
              label: 'Send feedback',
              subtitle: _kFeedbackEmail,
              onTap: () => _openEmail(context),
            ),
          ]),

          const _SectionLabel(label: 'About'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.info_outline_rounded,
              label: 'About OnushilonHub',
              subtitle: 'Learn more about the app',
              onTap: () => _showAboutSheet(context),
            ),
            _Divider(),
            _VersionTile(),
          ]),

          const SizedBox(height: AppTokens.space40),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System default';
    }
  }

  Future<void> _showFontSizeSheet(
      BuildContext context, WidgetRef ref, AppFontSize current) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusLarge)),
      ),
      builder: (_) => _FontSizeSheet(current: current, ref: ref),
    );
  }

  Future<void> _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode current) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusLarge)),
      ),
      builder: (_) => _ThemeSheet(currentMode: current, ref: ref),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusLarge)),
      ),
      builder: (_) => const _AboutSheet(),
    );
  }

  void _showManageDataSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusLarge)),
      ),
      builder: (_) => const _ManageDataSheet(),
    );
  }

  Future<void> _openEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _kFeedbackEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email address copied to clipboard')));
    }
  }
}

// ── Theme modal bottom sheet ──────────────────────────────────────────────────

class _ThemeSheet extends StatelessWidget {
  final ThemeMode currentMode;
  final WidgetRef ref;
  const _ThemeSheet({required this.currentMode, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTokens.space20),
          for (final entry in {
            ThemeMode.light: ('Light', Icons.light_mode_rounded),
            ThemeMode.dark: ('Dark', Icons.dark_mode_rounded),
            ThemeMode.system: ('System default', Icons.settings_brightness_rounded),
          }.entries)
            _ThemeOption(
              icon: entry.value.$2,
              label: entry.value.$1,
              isSelected: currentMode == entry.key,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(entry.key);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.primary : colorScheme.onSurfaceVariant),
      title: Text(label, style: textTheme.bodyLarge),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
    );
  }
}

// ── About bottom sheet ────────────────────────────────────────────────────────

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppTokens.space12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
            // Back row
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space16,
                  vertical: AppTokens.space8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('About OnushionHub',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Logo + name
            const SizedBox(height: AppTokens.space32),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/icon-192.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text('OnushiionHub',
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTokens.space4),
            Text('Version $_kAppVersion',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppTokens.space12),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space32),
              child: Text(
                'Learn English, Master vocabulary.\nBuilt to help you grow every day.',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Developer ────────────────────────────────────────────────
            const SizedBox(height: AppTokens.space32),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DEVELOPER',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      )),
                  const SizedBox(height: AppTokens.space10),
                  _DeveloperRow(),

                  // ── Open Source ─────────────────────────────────────────
                  const SizedBox(height: AppTokens.space24),
                  Text('OPEN SOURCE',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      )),
                  const SizedBox(height: AppTokens.space10),
                  _GroupCard(children: [
                    const _OpenSourceTile(
                      icon: Icons.code_rounded,
                      label: 'App is open source',
                      subtitle: 'View source on GitHub',
                      url: _kRepoUrl,
                    ),
                    _Divider(),
                    const _OpenSourceTile(
                      icon: Icons.account_tree_rounded,
                      label: 'GitHub project',
                      subtitle: 'Star us on GitHub',
                      url: _kGithubUrl,
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space40),
          ],
        ),
      ),
    );
  }
}

class _DeveloperRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.network(
              _kAvatarUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 24),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sifat',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Flutter & Android Developer',
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _kGithubUrl));
            },
            icon: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _OpenSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String url;
  const _OpenSourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return _RowTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
      },
    );
  }
}

// ── Settings row components ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppTokens.space20, bottom: AppTokens.space8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 54,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _RowTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ic = iconColor ?? colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16, vertical: AppTokens.space14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ic),
            const SizedBox(width: AppTokens.space18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ThemeTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _RowTile(
        icon: icon, label: label, subtitle: subtitle, onTap: onTap);
  }
}

class _VersionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16, vertical: AppTokens.space14),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.space18),
          Expanded(
            child: Text('Version',
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
          Text(_kAppVersion,
              style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Manage Data bottom sheet ──────────────────────────────────────────────────

class _ManageDataSheet extends StatelessWidget {
  const _ManageDataSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTokens.space24,
        right: AppTokens.space24,
        top: AppTokens.space12,
        bottom: AppTokens.space24 +
            MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius:
                    BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space20),
          Text(
            'Manage Your Data',
            style: textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            'Control your personal data and app progress stored on this device.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: AppTokens.space24),

          // Data stored info card
          Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius:
                  BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(
                  color: colorScheme.outlineVariant
                      .withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data stored on device',
                    style: textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppTokens.space8),
                const _DataInfoRow(
                    icon: Icons.bolt_rounded,
                    label: 'XP & streak progress'),
                const _DataInfoRow(
                    icon: Icons.games_rounded,
                    label: 'Game sessions & scores'),
                const _DataInfoRow(
                    icon: Icons.spellcheck_rounded,
                    label: 'Word mastery records'),
                const _DataInfoRow(
                    icon: Icons.person_rounded,
                    label: 'Profile name & preferences'),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.space24),

          // Reset Progress button
          _GroupCard(children: [
            _RowTile(
              icon: Icons.delete_sweep_rounded,
              label: 'Reset Progress',
              subtitle: 'Clear all XP, sessions and word progress',
              iconColor: colorScheme.error,
              labelColor: colorScheme.error,
              onTap: () => _confirmReset(context),
            ),
          ]),

          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await AppDialogs.showResetProgress(context);
    if (confirmed == true && context.mounted) {
      await DatabaseService.instance.resetAllProgress();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset successfully')),
        );
      }
    }
  }
}

class _DataInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DataInfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.space8),
          Text(label,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Font size modal bottom sheet ─────────────────────────────────────────────

class _FontSizeSheet extends StatelessWidget {
  final AppFontSize current;
  final WidgetRef ref;
  const _FontSizeSheet({required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font size',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTokens.space8),
          Text(
            'Affects every text element across the app. Changes apply instantly.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: AppTokens.space20),
          for (final size in AppFontSize.values)
            _FontSizeOption(
              size: size,
              isSelected: current == size,
              onTap: () {
                ref.read(fontSizeProvider.notifier).setFontSize(size);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }
}

class _FontSizeOption extends StatelessWidget {
  final AppFontSize size;
  final bool isSelected;
  final VoidCallback onTap;
  const _FontSizeOption({
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Live preview: scale the option label by its own factor so users see
    // the relative sizes before committing.
    final previewStyle = textTheme.bodyLarge?.copyWith(
      fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * size.scaleFactor,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
    );
    return ListTile(
      leading: Icon(
        Icons.format_size_rounded,
        color: isSelected ? AppColors.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(size.label, style: previewStyle),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
    );
  }
}
