import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String imagePath;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

const _pages = <_OnboardingPage>[
  _OnboardingPage(
    icon: Icons.menu_book_rounded,
    title: 'Learn vocabulary smarter',
    subtitle:
        'Curated words, examples, and synonyms designed for real exam preparation.',
    imagePath: 'assets/images/LearnVocabularySmarter.png',
  ),
  _OnboardingPage(
    icon: Icons.insights_rounded,
    title: 'Track progress and mastery',
    subtitle:
        'See your XP, streaks, and mastered words grow as you practice every day.',
    imagePath: 'assets/images/TrackProgress&Mastery.png',
  ),
  _OnboardingPage(
    icon: Icons.sports_esports_rounded,
    title: 'Practice interactive games',
    subtitle:
        'Unscramble, match, race, and challenge yourself with calm, focused mini-games.',
    imagePath: 'assets/images/InteractiveVocabularyGames.png',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _onContinue() async {
    if (_isLast) {
      await ref.read(userProfileProvider.notifier).completeOnboarding();
      if (!mounted) return;
      context.go('/name');
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: AppTokens.durationMedium),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _onSkip() async {
    await ref.read(userProfileProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/name');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Stable header — branding never shifts between pages.
            _OnboardingHeader(
              showSkip: !_isLast,
              onSkip: _onSkip,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardPageView(page: _pages[i]),
              ),
            ),
            // Indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.screenPaddingH,
                vertical: AppTokens.space16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(
                        milliseconds: AppTokens.durationMedium),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  );
                }),
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPaddingH,
                AppTokens.space8,
                AppTokens.screenPaddingH,
                AppTokens.space24,
              ),
              child: AppPrimaryButton(
                label: _isLast ? 'Get started' : 'Continue',
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable onboarding header.
///
/// The brand mark (logo + wordmark) is anchored to the left and the Skip
/// action is anchored to the right inside a fixed-height container.
/// The Skip slot ALWAYS reserves its space — when [showSkip] is false the
/// button is rendered invisibly and ignores hit-testing, so the brand mark
/// never reflows between onboarding steps.
class _OnboardingHeader extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;

  const _OnboardingHeader({
    required this.showSkip,
    required this.onSkip,
  });

  // A reserved height that fits any TextButton variant, ensuring the row
  // is identical pixel-for-pixel regardless of Skip visibility.
  static const double _headerHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.screenPaddingH,
        AppTokens.space16,
        AppTokens.space8,
        0,
      ),
      child: SizedBox(
        height: _headerHeight,
        child: Row(
          children: [
            // ── Brand mark ────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: Image.asset(
                'assets/images/icon-192-maskable.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Text(
              'OnushilonHub',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const Spacer(),
            // ── Reserved Skip slot ────────────────────────────────────────
            // The slot is always rendered so the brand mark never shifts.
            // When skip is not applicable the button is invisible and
            // non-interactive — layout is preserved.
            Visibility(
              visible: showSkip,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              maintainInteractivity: false,
              child: TextButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.screenPaddingH,
        vertical: AppTokens.space16,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppTokens.space16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, c) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.0),
                            borderRadius: BorderRadius.circular(
                                AppTokens.radiusLarge),
                          ),
                        ),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusLarge),
                          child: Image.asset(
                            page.imagePath,
                            width: c.maxWidth * 1.1,
                            height: c.maxHeight * 1.1,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space24),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTokens.space12),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space24),
        ],
      ),
    );
  }
}
