import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppTokens.radiusSmall,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // FIX: The original Column had a fixed-height parent container but the
    // Column's children could overflow it (20 + 12 + 14 + 8 + 14 = 68px of
    // content + 40px padding = 108px minimum, which exceeds small height
    // values and caused RenderFlex overflow by 36px).
    //
    // Solution: remove the fixed height from the outer container and instead
    // let it size to its children.  Callers that need a specific height should
    // wrap SkeletonCard in a SizedBox themselves.  The padding is preserved so
    // the card looks the same; we just no longer force a hard height cap.
    return Container(
      // No fixed height — sizes to content so no overflow is possible.
      padding: const EdgeInsets.all(AppTokens.cardPaddingH),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // size to children, not parent
        children: [
          LoadingSkeleton(height: 20, width: 120),
          SizedBox(height: AppTokens.space12),
          LoadingSkeleton(height: 14),
          SizedBox(height: AppTokens.space8),
          // FIX: avoid MediaQuery here — use a FractionallySizedBox instead
          // so the width is derived from the widget's own layout constraints,
          // not the full screen width.  This is safer when the card is used
          // inside constrained parent widgets.
          FractionallySizedBox(
            widthFactor: 0.6,
            child: LoadingSkeleton(height: 14),
          ),
        ],
      ),
    );
  }
}
