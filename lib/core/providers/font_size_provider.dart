import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, user-selectable font size.
///
/// Three discrete steps — small enough to stay tasteful, large enough to be
/// useful for accessibility. The scale factor is multiplied into every
/// `TextStyle.fontSize` via `TextTheme.apply(fontSizeFactor:)`, so the entire
/// app reflows from a single source of truth (the active [ThemeData]).
enum AppFontSize {
  small(0.90, 'Small'),
  medium(1.00, 'Medium'),
  large(1.10, 'Large');

  const AppFontSize(this.scaleFactor, this.label);

  /// Multiplier applied to the base text theme.
  final double scaleFactor;

  /// Human-readable label shown in the settings UI.
  final String label;

  static const AppFontSize defaultSize = AppFontSize.medium;
}

const _kFontSizeKey = 'app_font_size';

/// Persistent [AppFontSize] preference.
///
/// Mirrors the architecture of [themeModeProvider]: a [StateNotifier] that
/// initialises synchronously to the default value (so no first-frame flash)
/// and asynchronously loads the saved value from [SharedPreferences].
final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, AppFontSize>((ref) {
  return FontSizeNotifier();
});

class FontSizeNotifier extends StateNotifier<AppFontSize> {
  FontSizeNotifier() : super(AppFontSize.defaultSize) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kFontSizeKey);
    if (saved == null) return;
    final restored = _fromString(saved);
    if (restored != state) state = restored;
  }

  Future<void> setFontSize(AppFontSize size) async {
    if (state == size) return;
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontSizeKey, size.name);
  }

  AppFontSize _fromString(String value) {
    for (final size in AppFontSize.values) {
      if (size.name == value) return size;
    }
    return AppFontSize.defaultSize;
  }
}
