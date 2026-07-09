import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/shell/main_shell.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/games/screens/games_hub_screen.dart';
import '../../features/games/screens/pre_game_screen.dart';
import '../../features/games/screens/universal_mcq_game_screen.dart';
import '../../features/games/screens/unscramble_game_screen.dart';
import '../../features/games/screens/true_false_game_screen.dart';
import '../../features/results/screens/results_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/saved_words_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/name_input_screen.dart';
import '../../features/word_detail/screens/word_detail_screen.dart';
import '../../features/search/screens/word_search_screen.dart';

import '../models/game_config.dart' show GameConfig, GameResult;

final appRouterProvider = Provider((ref) {
  ref.keepAlive();
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/name',
        builder: (_, __) => const NameInputScreen(),
      ),
      // F-04: word search screen
      GoRoute(
        path: '/search',
        builder: (_, __) => const WordSearchScreen(),
      ),
      // Word detail screen (UX-03)
      GoRoute(
        path: '/word/:wordId',
        builder: (_, state) => WordDetailScreen(
          wordId: int.parse(state.pathParameters['wordId']!),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/games',
              builder: (_, __) => const GamesHubScreen(),
              routes: [
                GoRoute(
                  path: 'pre/:gameType',
                  builder: (_, state) => PreGameScreen(
                    gameType: state.pathParameters['gameType']!,
                  ),
                ),
                // ── Unscramble — unique keyboard-input UI ──────────────────────────
                GoRoute(
                  path: 'play/unscramble',
                  builder: (_, state) =>
                      UnscrambleGameScreen(config: state.extra as GameConfig),
                ),
                // ── True / False — unique two-button UI ──────────────────────────
                GoRoute(
                  path: 'play/true_false',
                  builder: (_, state) =>
                      TrueFalseGameScreen(config: state.extra as GameConfig),
                ),
                // ── MCQ games ──────────────────────────────────────────────────────────
                GoRoute(
                  path: 'play/meaning_chase',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/synonym_match',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/antonym_match',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/speed_racing',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/ipa_match',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/definition_match',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
                GoRoute(
                  path: 'play/whose_quote',
                  builder: (_, state) => UniversalMcqGameScreen(
                      config: state.extra as GameConfig),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/results',
        builder: (_, state) =>
            ResultsScreen(result: state.extra as GameResult),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/saved-words',
        builder: (_, __) => const SavedWordsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
