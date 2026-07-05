import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'animated_counter.dart';

class GameHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final int score;
  final int current;
  final int total;
  final VoidCallback? onClose;
  final bool showProgressBar;

  const GameHeader({
    super.key,
    required this.title,
    required this.score,
    required this.current,
    required this.total,
    this.onClose,
    this.showProgressBar = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  State<GameHeader> createState() => _GameHeaderState();
}

class _GameHeaderState extends State<GameHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  int _prevScore = 0;

  @override
  void initState() {
    super.initState();
    _prevScore = widget.score;
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppTokens.durationMedium),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(GameHeader old) {
    super.didUpdateWidget(old);
    if (widget.score > _prevScore) {
      _bounceController
        ..reset()
        ..forward();
    }
    _prevScore = widget.score;
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = widget.total > 0 ? widget.current / widget.total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: widget.onClose,
          ),
          actions: [
            ScaleTransition(
              scale: _bounceAnim,
              child: Container(
                margin: const EdgeInsets.only(right: AppTokens.space16),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space12,
                  vertical: AppTokens.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.reward.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(color: AppColors.reward.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: AppColors.reward,
                    ),
                    const SizedBox(width: 4),
                    AnimatedCounter(
                      value: widget.score,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.showProgressBar) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: AppTokens.durationMedium),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 4,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space4),
        ],
      ],
    );
  }
}
