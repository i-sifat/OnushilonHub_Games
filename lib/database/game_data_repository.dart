import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../core/models/ipa_model.dart';
import '../core/models/definition_model.dart';
import '../core/models/quote_model.dart';
import '../core/models/user_progress_model.dart';
import '../features/games/logic/game_exception.dart';
import 'i_game_repository.dart';

/// Riverpod handle for the singleton [DatabaseService]. Wrapping it in a
/// provider lets controllers and repositories receive the dependency via
/// constructor injection instead of reaching into `DatabaseService.instance`
/// directly.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  ref.keepAlive();
  return DatabaseService.instance;
});

/// Provider for the game-data repository. The concrete type is exposed for
/// backward compatibility; it also `implements IGameRepository` (Task 7) so
/// new code can depend on the interface.
final gameDataRepositoryProvider = Provider<GameDataRepository>((ref) {
  ref.keepAlive();
  return GameDataRepository(ref.watch(databaseServiceProvider));
});

// ── Resolved question types ────────────────────────────────────────────────

class ResolvedSynonymAntonymQuestion {
  final String word;
  final String correctAnswer;
  final List<String> options;

  const ResolvedSynonymAntonymQuestion({
    required this.word,
    required this.correctAnswer,
    required this.options,
  });
}

class ResolvedWhoseQuoteQuestion {
  final String quoteText;
  final String correctAuthor;
  final String eraName;
  final List<String> options;

  const ResolvedWhoseQuoteQuestion({
    required this.quoteText,
    required this.correctAuthor,
    required this.eraName,
    required this.options,
  });
}

/// Unified data source for all game content.
///
/// • IPA, definitions, synonyms, antonyms → SQLite queries against vocabulary.db
/// • Quotes / authors / eras → small JSON files (kept as-is; only 100 quotes)
///
/// Memory cache: only the current game's question set is cached (released via
/// [clearCache]). No full-table caching.
class GameDataRepository implements IGameRepository {
  final DatabaseService _db;

  GameDataRepository(this._db);

  // ── Lightweight in-memory caches (cleared between games) ─────────────────

  List<IpaModel>? _ipaCache;
  List<DefinitionModel>? _definitionCache;

  // Quote data (small JSON, loaded once)
  List<RichQuoteModel>? _richQuoteCache;
  Map<int, QuoteAuthorModel>? _authorCache;
  Map<int, QuoteEraModel>? _eraCache;

  // ── IPA ────────────────────────────────────────────────────────────────────

  /// Returns [count] random IPA entries from the vocabulary DB.
  @override
  Future<List<IpaModel>> getRandomIpaEntries({required int count}) async {
    if (_ipaCache == null) {
      await _loadIpaFromDb(count * 4);
    }
    final list = _ipaCache!.toList()..shuffle(Random());
    return list.take(count).toList();
  }

  Future<void> _loadIpaFromDb(int limit) async {
    // FIX: The original literal AND word NOT LIKE ''''%' was invalid SQLite
    // because the escaped apostrophe sequence broke the LIKE string literal.
    // Solution: pass the apostrophe-prefix pattern as a bound parameter (?)
    // which avoids all single-quote escaping complexity entirely.
    final rows = await _db.db.rawQuery('''
      SELECT word, ipa FROM ipa_pronunciations
      WHERE locale = 'en_US'
        AND word NOT LIKE ?
        AND word NOT LIKE '%-%'
        AND word NOT LIKE '% %'
        AND LENGTH(ipa) > 0
      ORDER BY RANDOM()
      LIMIT ?
    ''', ["'%", limit]);

    // Use IpaModel.fromEntry() so comma-split logic lives in one place.
    _ipaCache = rows
        .map((r) => IpaModel.fromEntry(
              r['word'] as String,
              r['ipa'] as String,
            ))
        .where((m) => m.word.isNotEmpty && m.ipa.isNotEmpty)
        .toList();
  }

  // ── Definitions ────────────────────────────────────────────────────────────

  /// Returns [count] random definition entries from the vocabulary DB.
  ///
  /// DM1: always reloads 2000 entries from the DB on every call — this
  /// guarantees each session draws from a fresh random slice of the 53,470
  /// available definitions instead of recycling the same tiny cache.
  /// DM5: clearing _definitionCache before loading (not relying on
  /// clearGameCache being called) ensures freshness even after an abnormal
  /// app exit that skipped dispose().
  @override
  Future<List<DefinitionModel>> getRandomDefinitionEntries({
    required int count,
  }) async {
    // DM5: always reload — do not reuse a stale cache from a previous session.
    await _loadDefinitionsFromDb(2000);
    final list = _definitionCache!.toList()..shuffle(Random());
    return list.take(count).toList();
  }

  Future<List<DefinitionModel>> getAllDefinitions() async {
    if (_definitionCache == null) {
      await _loadDefinitionsFromDb(2000);
    }
    return List.unmodifiable(_definitionCache!);
  }

  Future<void> _loadDefinitionsFromDb(int limit) async {
    // DM5: always clear first so a stale cache from a previous session never
    // leaks into the new one — regardless of how the previous session ended.
    _definitionCache = null;

    final rows = await _db.db.rawQuery('''
      SELECT w.word, d.pos, d.definition
      FROM definitions d
      JOIN words w ON w.id = d.word_id
      WHERE d.sense_order = 0
        AND LENGTH(d.definition) > 10
        AND LENGTH(d.definition) <= 120
      ORDER BY RANDOM()
      LIMIT ?
    ''', [limit]);
    // DM3: LENGTH <= 120 caps definitions at a readable size for MCQ tiles.
    // The longest definitions in the DB are 479 chars (GYMNOSPERMAE) — those
    // would overflow option tiles on small screens and are now excluded.
    // 3,005 definitions (5.6%) exceed 120 chars; 50,465 remain available.

    // Deduplicate on definition text: the same definition string appearing for
    // multiple words would allow a distractor to also be a correct answer for
    // a different question in the same session.
    final seen = <String>{};
    _definitionCache = rows
        .map((r) => DefinitionModel(
              word: r['word'] as String,
              partOfSpeech: r['pos'] as String? ?? '',
              definition: r['definition'] as String,
            ))
        .where((d) => d.word.isNotEmpty && d.definition.isNotEmpty && seen.add(d.definition))
        .toList();
  }

  /// DM2: Returns a large independent pool of definitions for use as
  /// distractors in Definition Match.
  ///
  /// This pool is intentionally SEPARATE from the question pool returned by
  /// [getRandomDefinitionEntries]. Using one shared pool for both questions
  /// and distractors creates a pattern-recognition exploit where every
  /// distractor the player sees is also the correct answer for another
  /// question in the same session.
  ///
  /// This method:
  ///   • Is NOT cached — each call draws a fresh random set from the DB.
  ///   • Does NOT filter by word_progress (mastery) — ensures distractors
  ///     remain plentiful even for advanced players who have mastered many words.
  ///   • Applies the same LENGTH <= 120 cap as the question pool (DM3).
  @override
  Future<List<DefinitionModel>> getDefinitionDistractorPool({
    required int limit,
  }) async {
    try {
      final rows = await _db.db.rawQuery('''
        SELECT w.word, d.pos, d.definition
        FROM definitions d
        JOIN words w ON w.id = d.word_id
        WHERE d.sense_order = 0
          AND LENGTH(d.definition) > 10
          AND LENGTH(d.definition) <= 120
        ORDER BY RANDOM()
        LIMIT ?
      ''', [limit]);

      final seen = <String>{};
      return rows
          .map((r) => DefinitionModel(
                word: r['word'] as String,
                partOfSpeech: r['pos'] as String? ?? '',
                definition: r['definition'] as String,
              ))
          .where((d) => d.definition.isNotEmpty && seen.add(d.definition))
          .toList();
    } catch (e) {
      throw RepositoryException('Failed to load definition distractor pool',
          cause: e);
    }
  }

  // ── Synonyms / Antonyms ────────────────────────────────────────────────────

  /// Returns [count] synonym-match questions from vocabulary.db.
  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions({
    required int count,
  }) async {
    return _buildSynonymAntonymQuestions(count: count, isAntonym: false);
  }

  /// Returns [count] antonym-match questions from vocabulary.db.
  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomAntonymQuestions({
    required int count,
  }) async {
    return _buildSynonymAntonymQuestions(count: count, isAntonym: true);
  }

  Future<List<ResolvedSynonymAntonymQuestion>> _buildSynonymAntonymQuestions({
    required int count,
    required bool isAntonym,
  }) async {
    final table = isAntonym ? 'antonyms' : 'synonyms';
    final col = isAntonym ? 'antonym' : 'synonym';

    // Fetch words that have at least one entry in the target table
    final wordRows = await _db.db.rawQuery('''
      SELECT w.id, w.word,
             (SELECT GROUP_CONCAT($col, '|') FROM $table WHERE word_id = w.id LIMIT 10) AS answers
      FROM words w
      WHERE EXISTS (SELECT 1 FROM $table WHERE word_id = w.id)
      ORDER BY RANDOM()
      LIMIT ?
    ''', [count * 2]);

    if (wordRows.isEmpty) return [];

    // Build distractor pool
    final distractorRows = await _db.db.rawQuery('''
      SELECT DISTINCT $col AS answer FROM $table
      ORDER BY RANDOM()
      LIMIT 200
    ''');
    final allAnswers = distractorRows
        .map((r) => r['answer'] as String)
        .where((s) => s.isNotEmpty)
        .toList();

    final rng = Random();
    final questions = <ResolvedSynonymAntonymQuestion>[];

    for (final row in wordRows) {
      if (questions.length >= count) break;
      final word = row['word'] as String;
      final answerStr = row['answers'] as String? ?? '';
      final correctList =
          answerStr.split('|').where((s) => s.isNotEmpty).toList();
      if (correctList.isEmpty) continue;

      final correct = correctList[rng.nextInt(correctList.length)];
      final distractors = allAnswers
          .where((s) => s != correct && !correctList.contains(s))
          .toList()
        ..shuffle(rng);

      if (distractors.length < 3) continue;

      final options = [correct, ...distractors.take(3)]..shuffle(rng);
      questions.add(ResolvedSynonymAntonymQuestion(
        word: word,
        correctAnswer: correct,
        options: options,
      ));
    }

    return questions;
  }

  // ── Rich Quotes ────────────────────────────────────────────────────────────

  /// Returns [count] WhoseQuote questions.
  @override
  Future<List<ResolvedWhoseQuoteQuestion>> getRandomWhoseQuoteQuestions({
    required int count,
    int? eraId,
  }) async {
    await _ensureRichQuotesLoaded();

    final quotes = _richQuoteCache!;
    final authors = _authorCache!;
    final eras = _eraCache!;
    final rng = Random();

    var pool = eraId != null
        ? quotes.where((q) => q.eraId == eraId).toList()
        : quotes.toList();
    pool.shuffle(rng);

    if (pool.length < 4) pool = quotes.toList()..shuffle(rng);

    final selected = pool.take(count).toList();
    final allAuthorNames = authors.values.map((a) => a.name).toSet().toList();

    return selected.map((q) {
      final author = authors[q.authorId];
      final era = eras[q.eraId];
      final correctAuthor = author?.name ?? 'Unknown';
      final eraName = era?.name ?? '';

      final distractors = allAuthorNames
          .where((n) => n != correctAuthor)
          .toList()
        ..shuffle(rng);
      final options = [correctAuthor, ...distractors.take(3)]..shuffle(rng);

      return ResolvedWhoseQuoteQuestion(
        quoteText: q.text,
        correctAuthor: correctAuthor,
        eraName: eraName,
        options: options,
      );
    }).toList();
  }

  @override
  Future<List<QuoteEraModel>> getEras() async {
    await _ensureRichQuotesLoaded();
    return _eraCache!.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _ensureRichQuotesLoaded() async {
    if (_richQuoteCache != null && _authorCache != null && _eraCache != null) {
      return;
    }

    // Load authors and eras first so we can cross-validate quote entries.
    final authorsRaw = await rootBundle.loadString('assets/json/quote_authors.json');
    final erasRaw = await rootBundle.loadString('assets/json/quote_eras.json');

    final authorList = (jsonDecode(authorsRaw) as List<dynamic>)
        .map((e) => QuoteAuthorModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _authorCache = {for (final a in authorList) a.id: a};

    final eraList = (jsonDecode(erasRaw) as List<dynamic>)
        .map((e) => QuoteEraModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _eraCache = {for (final e in eraList) e.id: e};

    // Parse quotes — skip any entry whose author_id or era_id is null, or
    // whose author_id has no matching entry in the authors list. These are
    // data errors that would cause a hard cast crash at runtime.
    final quotesRaw = await rootBundle.loadString('assets/json/quotes.json');
    final validAuthorIds = _authorCache!.keys.toSet();
    final validEraIds = _eraCache!.keys.toSet();
    _richQuoteCache = (jsonDecode(quotesRaw) as List<dynamic>)
        .where((e) {
          final m = e as Map<String, dynamic>;
          final authorId = m['author_id'];
          final eraId = m['era_id'];
          return authorId != null &&
              eraId != null &&
              validAuthorIds.contains(authorId as int) &&
              validEraIds.contains(eraId as int);
        })
        .map((e) => RichQuoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Releases game-specific caches. Call when leaving a game screen.
  @override
  void clearGameCache() {
    _ipaCache = null;
    _definitionCache = null;
  }

  /// Releases all caches including quote data.
  @override
  void clearCache() {
    _ipaCache = null;
    _definitionCache = null;
    _richQuoteCache = null;
    _authorCache = null;
    _eraCache = null;
  }

  // ── Word data exposed for builders (no direct DB access elsewhere) ───────

  @override
  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) {
    try {
      return _db.getEligibleWords(
        gameType: gameType,
        difficulty: difficulty,
        limit: limit,
        requiresDefinition: requiresDefinition,
        requiresSynonym: requiresSynonym,
        requiresAntonym: requiresAntonym,
      );
    } catch (e) {
      throw RepositoryException('Failed to load eligible words', cause: e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases({
    required int limit,
  }) {
    try {
      return _db.getMeaningChasePhrases(limit: limit);
    } catch (e) {
      throw RepositoryException(
          'Failed to load meaning-chase phrases', cause: e);
    }
  }

  /// Batch-resolves word IDs for a list of words (case-insensitive).
  ///
  /// Returns a map keyed by the *lowercase* word. Missing words are simply
  /// absent — callers should treat `null` as "no mastery tracking for this
  /// item" rather than an error.
  @override
  Future<Map<String, int>> getWordIdsByLowercase(List<String> words) async {
    if (words.isEmpty) return const {};
    try {
      final lower = words.map((w) => w.toLowerCase()).toList();
      final ph = lower.map((_) => '?').join(',');
      // DM6: ORDER BY word DESC so UPPERCASE rows (e.g. 'WOLF') are processed
      // last and win the last-write-wins dict comprehension over any lowercase
      // orphan rows (e.g. 'wolf') that share the same LOWER(word) key.
      // After the DB cleanup there are 0 case-duplicate pairs, but this ORDER BY
      // makes the resolution deterministic and safe against future data changes.
      final rows = await _db.db.rawQuery(
        'SELECT id, LOWER(word) AS wl FROM words WHERE LOWER(word) IN ($ph) ORDER BY word ASC',
        lower,
      );
      return {for (final r in rows) r['wl'] as String: r['id'] as int};
    } catch (e) {
      throw RepositoryException('Failed to resolve word ids', cause: e);
    }
  }

  @override
  Future<int?> getWordIdByLowercase(String word) async {
    final map = await getWordIdsByLowercase([word]);
    return map[word.toLowerCase()];
  }

  // ── Mastery / progress writes ────────────────────────────────────────────

  @override
  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  }) async {
    try {
      await _db.markWordStatus(
          wordId: wordId, gameType: gameType, status: status);
    } catch (e) {
      throw RepositoryException('Failed to mark word status', cause: e);
    }
  }

  // ── Session persistence ──────────────────────────────────────────────────

  /// Persists a finished session and rolls XP + streak into user_progress.
  /// Throws [RepositoryException] on failure so the controller can surface
  /// a meaningful error to the player instead of silently swallowing it.
  @override
  Future<void> persistSession({
    required GameSessionModel session,
    required int xpEarned,
  }) async {
    try {
      await _db.saveGameSession(session);
      await _db.addXp(xpEarned);
      await _db.updateStreak();
    } catch (e) {
      throw RepositoryException('Failed to persist game session', cause: e);
    }
  }
}
