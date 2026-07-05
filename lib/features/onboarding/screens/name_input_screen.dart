import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';

class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key});

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userProfileProvider).name;
    if (existing != null) {
      _controller.text = existing;
      _valid = existing.trim().length >= 2;
    }
    _controller.addListener(() {
      final v = _controller.text.trim().length >= 2;
      if (v != _valid) setState(() => _valid = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_valid) return;
    await ref
        .read(userProfileProvider.notifier)
        .setName(_controller.text.trim());
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // The amount of space the keyboard currently occupies.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Available vertical space after subtracting keyboard.
    final screenHeight = MediaQuery.of(context).size.height;
    // Decide whether to show the full-size image or a compact one.
    // When the keyboard is open or the screen is short, use a smaller image.
    final imageRatio = (bottomInset > 0 || screenHeight < 700) ? 0.45 : 1.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Set to false so we manually handle insets via AnimatedPadding.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedPadding(
          // Smoothly animate the bottom padding to match the keyboard height,
          // which causes the whole layout to scroll upward when keyboard opens.
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: SingleChildScrollView(
            // Prevent the scroll view itself from scrolling when not needed;
            // physics ensures a natural feel on small devices.
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppTokens.space40),
                  // Image shrinks when keyboard is open to keep everything
                  // on screen without overflow.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: (screenHeight - 400) * imageRatio,
                    constraints: const BoxConstraints(minHeight: 80, maxHeight: 400),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.0),
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusLarge),
                              ),
                            ),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusLarge),
                              child: Image.asset(
                                'assets/images/nameScreen.png',
                                width: c.maxWidth,
                                height: c.maxHeight,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTokens.space32),
                  Text(
                    "What's your name?",
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    "We'll use it to personalize your experience.",
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space32),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onContinue(),
                    style: textTheme.titleMedium,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  // Fixed spacing between text field and button —
                  // no Spacer here since we're inside a scroll view.
                  const SizedBox(height: AppTokens.space32),
                  AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: AppTokens.durationMedium),
                    child: AppPrimaryButton(
                      key: ValueKey(_valid),
                      label: 'Continue',
                      onPressed: _valid ? _onContinue : null,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
