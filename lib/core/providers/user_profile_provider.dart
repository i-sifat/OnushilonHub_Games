import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUserNameKey = 'user_name';
const _kOnboardingDoneKey = 'onboarding_completed';

class UserProfile {
  final String? name;
  final bool onboardingCompleted;

  const UserProfile({this.name, this.onboardingCompleted = false});

  UserProfile copyWith({String? name, bool? onboardingCompleted}) {
    return UserProfile(
      name: name ?? this.name,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _load();
  }

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = UserProfile(
      name: prefs.getString(_kUserNameKey),
      onboardingCompleted: prefs.getBool(_kOnboardingDoneKey) ?? false,
    );
    _loaded = true;
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserNameKey, name);
    state = state.copyWith(name: name);
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDoneKey, true);
    state = state.copyWith(onboardingCompleted: true);
  }

  /// Returns the initial route based on stored state.
  static Future<String> resolveInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kOnboardingDoneKey) ?? false;
    final name = prefs.getString(_kUserNameKey);
    if (!done) return '/onboarding';
    if (name == null || name.trim().isEmpty) return '/name';
    return '/home';
  }
}
