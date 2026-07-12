import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/word_model.dart';
import '../../../core/models/user_progress_model.dart';
import '../../../database/word_repository.dart';
import '../../../database/progress_db_service.dart';
import '../../../database/session_db_service.dart';

final userProgressProvider = FutureProvider<UserProgressModel>((ref) async {
  return ref.watch(progressDbServiceProvider).getUserProgress();
});

final dailyWordProvider = FutureProvider<WordModel?>((ref) async {
  final repo = ref.read(wordRepositoryProvider);
  return repo.getDailyWord();
});

final homeGameProgressProvider =
    FutureProvider<Map<String, Map<String, int>>>((ref) async {
  final repo = ref.read(wordRepositoryProvider);
  return repo.getAllProgressCounts();
});

final playedGamesProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(sessionDbServiceProvider).getPlayedGameTypes();
});

final todaySessionCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(sessionDbServiceProvider).getTodaySessionCount();
});
