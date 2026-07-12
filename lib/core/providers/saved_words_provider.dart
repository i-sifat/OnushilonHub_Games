import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../database/session_db_service.dart';

class SavedWord {
  final String word;
  final String definition;
  final int savedAt;

  const SavedWord({
    required this.word,
    required this.definition,
    required this.savedAt,
  });

  factory SavedWord.fromMap(Map<String, dynamic> map) => SavedWord(
        word: map['word'] as String,
        definition: map['definition'] as String,
        savedAt: map['saved_at'] as int,
      );
}

class SavedWordsNotifier extends StateNotifier<AsyncValue<List<SavedWord>>> {
  SavedWordsNotifier(this._session) : super(const AsyncValue.loading()) {
    _load();
  }

  final SessionDbService _session;

  Future<void> _load() async {
    try {
      final rows = await _session.getSavedWords();
      state = AsyncValue.data(rows.map(SavedWord.fromMap).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> isSaved(String word) async {
    return _session.isWordSaved(word);
  }

  Future<void> save(String word, String definition) async {
    await _session.saveWord(word, definition);
    await _load();
  }

  Future<void> remove(String word) async {
    await _session.removeWord(word);
    await _load();
  }
}

final savedWordsProvider =
    StateNotifierProvider<SavedWordsNotifier, AsyncValue<List<SavedWord>>>(
  (ref) => SavedWordsNotifier(ref.watch(sessionDbServiceProvider)),
);

/// A provider to quickly check if a specific word is saved.
final isWordSavedProvider = FutureProvider.family<bool, String>((ref, word) async {
  // Watch saved words so this re-evaluates when list changes.
  final savedAsync = ref.watch(savedWordsProvider);
  return savedAsync.when(
    data: (list) => list.any((s) => s.word == word),
    loading: () => false,
    error: (_, __) => false,
  );
});
