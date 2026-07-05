import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../database/database_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  String _status = 'Loading…';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    try {
      // ── Phase 1: Copy asset DB if needed and open connection ──────────────
      // First launch: copies ~50 MB file → a few seconds.
      // Subsequent launches: just opens the existing file → < 100 ms.
      if (mounted) setState(() => _status = 'Preparing database…');
      await DatabaseService.instance.init().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const TimeoutException('Database initialisation timed out.'),
      );

      // ── Phase 2: Resolve initial route (prefs read) ───────────────────────
      if (mounted) setState(() => _status = 'Starting…');
      final route = await UserProfileNotifier.resolveInitialRoute()
          .timeout(const Duration(seconds: 5));

      // Logo plays for at least one beat
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go(route);
    } on TimeoutException catch (e) {
      if (mounted) setState(() { _status = e.message ?? 'Startup timed out.'; _error = true; });
    } catch (e) {
      if (mounted) setState(() { _status = 'Error: $e'; _error = true; });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
                    child: Image.asset(
                      'assets/images/icon-192-maskable.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
                Text(
                  'OnushilonHub',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  'Learn English. Master vocabulary.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
                if (_error) ...[
                  Text(
                    _status,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.space16),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() { _status = 'Retrying…'; _error = false; });
                      _navigate();
                    },
                    child: const Text('Retry'),
                  ),
                ] else ...[
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    _status,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

class TimeoutException implements Exception {
  final String? message;
  const TimeoutException(this.message);
}
