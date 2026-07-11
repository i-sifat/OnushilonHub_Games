import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/daily_goal_provider.dart';
import '../../../core/providers/font_size_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../database/daily_goal_extensions.dart';
import '../../../database/database_service.dart';
import '../../../shared/widgets/app_dialogs.dart';

const _kFeedbackEmail = 'murshedalam850@gmail.com';
const _kGithubUrl = 'https://github.com/i-sifat';
const _kRepoUrl = 'https://github.com/i-sifat/onushilonhub';
const _kAppVersion = '1.0.2';
const _kAvatarUrl = 'https://avatars.githubusercontent.com/u/142529114?v=4';

// ──────────────────────────────────────────────────────────────────────────────

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
          // ── APPEARANCE ──────────────────────────────────────────────
          const _SectionLabel(label: 'Appearance'),
          _GroupCard(children: [
            _ThemeTile(
              icon: Icons.light_mode_rounded,
              label: 'Theme',
              subtitle: _modeLabel(currentMode),
              onTap: () => _showThemeDialog(context, ref, currentMode),
            ),
            const _Divider(),
            _RowTile(
              icon: Icons.format_size_rounded,
              label: 'Font size',
              subtitle: currentFontSize.label,
              onTap: () =>
                  _showFontSizeSheet(context, ref, currentFontSize),
            ),
          ]),
          // ── LEARNING ──────────────────────────────────────────────
          const _SectionLabel(label: 'Learning'),
          _GroupCard(children: [
            const _DailyGoalTile(),
            const _Divider(),
            // F-03: daily practice reminder
            const _NotificationTile(),
          ]),
          // ── PRIVACY ───────────────────────────────────────────────
          const _SectionLabel(label: 'Privacy'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.security_rounded,
              label: 'Privacy',
              subtitle: 'Manage your data',
              onTap: () => _showManageDataSheet(context),
            ),
          ]),
          // ── SUPPORT ───────────────────────────────────────────────
          const _SectionLabel(label: 'Support'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.mail_outline_rounded,
              label: 'Send feedback',
              subtitle: _kFeedbackEmail,
              onTap: () => _openEmail(context),
            ),
          ]),
          // ── ABOUT ────────────────────────────────────────────────
          const _SectionLabel(label: 'About'),
          _GroupCard(children: [
            _RowTile(
              icon: Icons.info_outline_rounded,
              label: 'About OnushilonHub',
              subtitle: 'Learn more about the app',
              onTap: () => _showAboutSheet(context),
            ),
            const _Divider(),
            const _VersionTile(),
          ]),
          const SizedBox(height: AppTokens.space40),
        ],
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  Future<void> _showFontSizeSheet(
      BuildContext context, WidgetRef ref, AppFontSize current) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
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
          top: Radius.circular(AppTokens.radiusLarge),
        ),
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
          top: Radius.circular(AppTokens.radiusLarge),
        ),
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
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (_) => const _ManageDataSheet(),
    );
  }

  Future<void> _openEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _kFeedbackEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Email address copied to clipboard')));
    }
  }
}

// ── Daily Goal tile ────────────────────────────────────────────────────

class _DailyGoalTile extends ConsumerWidget {
  const _DailyGoalTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(dailyGoalTargetProvider);

    return goalAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.flag_rounded),
        title: Text('Daily goal'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const ListTile(
        leading: Icon(Icons.flag_rounded),
        title: Text('Daily goal'),
        subtitle: Text('Could not load'),
      ),
      data: (goal) => ListTile(
        leading: const Icon(Icons.flag_rounded),
        title: const Text('Daily goal'),
        subtitle: Text('$goal session${goal == 1 ? '' : 's'} per day'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: goal <= 1 ? null : () => _setGoal(ref, goal - 1),
              tooltip: 'Decrease',
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$goal',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: goal >= 20 ? null : () => _setGoal(ref, goal + 1),
              tooltip: 'Increase',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setGoal(WidgetRef ref, int newGoal) async {
    await DatabaseService.instance.updateDailyGoal(newGoal);
    ref.invalidate(dailyGoalTargetProvider);
  }
}

// ── Notification tile (F-03) ───────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  ({int hour, int minute})? _reminderTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminderTime();
  }

  Future<void> _loadReminderTime() async {
    final time = await NotificationService.instance.getReminderTime();
    if (mounted) {
      setState(() {
        _reminderTime = time;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const ListTile(
        leading: Icon(Icons.notifications_rounded),
        title: Text('Daily reminder'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final enabled = _reminderTime != null;
    final timeStr = enabled
        ? TimeOfDay(
                hour: _reminderTime!.hour,
                minute: _reminderTime!.minute)
            .format(context)
        : 'Off';

    return ListTile(
      leading: Icon(
        Icons.notifications_rounded,
        color: enabled ? colorScheme.primary : null,
      ),
      title: const Text('Daily reminder'),
      subtitle: Text(timeStr),
      trailing: Switch(
        value: enabled,
        onChanged: (val) async {
          if (val) {
            await _pickTime();
          } else {
            await _disableReminder();
          }
        },
      ),
      onTap: enabled ? _pickTime : null,
    );
  }

  Future<void> _pickTime() async {
    final current = _reminderTime != null
        ? TimeOfDay(
            hour: _reminderTime!.hour,
            minute: _reminderTime!.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null || !mounted) return;
    await NotificationService.instance
        .scheduleDailyReminder(picked.hour, picked.minute);
    if (mounted) {
      setState(
          () => _reminderTime = (hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _disableReminder() async {
    await NotificationService.instance.cancelDailyReminder();
    if (mounted) setState(() => _reminderTime = null);
  }
}

// ── Theme sheet ──────────────────────────────────────────────────────────

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
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTokens.space16),
          _ThemeOption(
            label: 'Light',
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
            onTap: () => _setThemeMode(context, ThemeMode.light),
          ),
          _ThemeOption(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => _setThemeMode(context, ThemeMode.dark),
          ),
          _ThemeOption(
            label: 'System default',
            icon: Icons.settings_rounded,
            isSelected: currentMode == ThemeMode.system,
            onTap: () => _setThemeMode(context, ThemeMode.system),
          ),
        ],
      ),
    );
  }

  void _setThemeMode(BuildContext context, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    Navigator.of(context).pop();
  }
}

// ── Theme option ─────────────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

// ── Font size sheet ──────────────────────────────────────────────────────

class _FontSizeSheet extends StatelessWidget {
  final AppFontSize current;
  final WidgetRef ref;

  const _FontSizeSheet({required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font size',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTokens.space16),
          for (final size in AppFontSize.values)
            _FontSizeOption(
              label: size.label,
              isSelected: current == size,
              onTap: () => _setFontSize(context, size),
            ),
        ],
      ),
    );
  }

  void _setFontSize(BuildContext context, AppFontSize size) {
    ref.read(fontSizeProvider.notifier).setFontSize(size);
    Navigator.of(context).pop();
  }
}

// ── Font size option ────────────────────────────────────────────────────

class _FontSizeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontSizeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

// ── Version tile ────────────────────────────────────────────────────────

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.tag_rounded),
      title: Text('Version'),
      subtitle: Text(_kAppVersion),
    );
  }
}

// ── About sheet ────────────────────────────────────────────────────────

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About OnushilonHub',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTokens.space16),
          Row(
            children: [
              const CircleAvatar(
                backgroundImage: NetworkImage(_kAvatarUrl),
                radius: 24,
              ),
              const SizedBox(width: AppTokens.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Developed by', style: textTheme.bodySmall),
                  Text(
                    'Murshed Alam Sifat',
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          _AboutLinkRow(
            icon: Icons.code_rounded,
            label: 'GitHub',
            url: _kGithubUrl,
          ),
          const SizedBox(height: AppTokens.space4),
          _AboutLinkRow(
            icon: Icons.folder_open_rounded,
            label: 'Repository',
            url: _kRepoUrl,
          ),
          const SizedBox(height: AppTokens.space16),
          Text('Version $_kAppVersion', style: textTheme.bodySmall),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }
}

// ── About link row ─────────────────────────────────────────────────────

class _AboutLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _AboutLinkRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label URL copied to clipboard')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppTokens.space8),
            Flexible(
              child: Text(
                url,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manage data sheet ──────────────────────────────────────────────────

class _ManageDataSheet extends StatelessWidget {
  const _ManageDataSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage your data',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTokens.space12),
          Text(
            'Reset all progress, XP, streaks, and game history. '
            'This cannot be undone.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.space24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _resetAllProgress(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Reset all progress'),
            ),
          ),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }

  Future<void> _resetAllProgress(BuildContext context) async {
    final confirmed = await AppDialogs.showResetData(context);
    if (confirmed && context.mounted) {
      await DatabaseService.instance.resetAllProgress();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All progress has been reset')),
        );
      }
    }
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.space16,
        bottom: AppTokens.space8,
        left: AppTokens.space4,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space8),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _RowTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, indent: 56);
  }
}
