import 'dart:async';
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
import 'a06_cache_guard_extensions.dart';
import 'quote_progress_extensions.dart';

/// Riverpod handle for the singleton [DatabaseService].
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  ref.keepAlive();
  return DatabaseService.instance;
});

/// Provider for the game-data repository.
final gameDataRepositoryProvider = Provider<GameDataRepository>((ref) {
  ref.keepAlive();
  return GameDataRepository(ref.watch(databaseServiceProvider));
});

// ── Resolved question types ────────────────────────────────────────────────

class ResolvedSynonymAntonymQuestion {
  final String word;
  final String correctAnswer;
  final List<String> options;
  final List<String> allCorrect;

  const ResolvedSynonymAntonymQuestion({
    required this.word,
    required this.correctAnswer,
    required this.options,
    this.allCorrect = const [],
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

typedef Era = QuoteEraModel;

class GameDataRepository implements IGameRepository {
  final DatabaseService _db;

  GameDataRepository(this._db);

  // ── Caches ──────────────────────────────────────────────────────────────

  List<IpaModel>? _ipaCache;
  List<DefinitionModel>? _definitionCache;
  List<RichQuoteModel>? _richQuoteCache;
  Map<int, QuoteAuthorModel>? _authorCache;
  Map<int, QuoteEraModel>? _eraCache;

  // A-06: Concurrency guards
  final _ipaGuard = ConcurrentLoadGuard<void>();
  final _defGuard = ConcurrentLoadGuard<void>();
  final _quoteGuard = ConcurrentLoadGuard<void>();

  // ── IPA ────────────────────────────────────────────────────────────────

  @override
  Future<List<IpaModel>> getRandomIpaEntries({required int count}) async {
    await _ipaGuard.run(() => _loadIpaFromDb(2000));
    final list = _ipaCache!.toList()..shuffle(Random());
    return list.take(count).toList();
  }

  Future<void> _loadIpaFromDb(int limit) async {
    _ipaCache = null;
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

    _ipaCache = rows
        .map((r) => IpaModel.fromEntry(
              r['word'] as String,
              r['ipa'] as String,
            ))
        .where((m) => m.word.isNotEmpty && m.ipa.isNotEmpty)
        .toList();
  }

  // ── Definitions ────────────────────────────────────────────────────────

  @override
  Future<List<DefinitionModel>> getRandomDefinitionEntries({
    required int count,
  }) async {
    await _defGuard.run(() => _loadDefinitionsFromDb(2000));
    final list = _definitionCache!.toList()..shuffle(Random());
    return list.take(count).toList();
  }

  Future<List<DefinitionModel>> getAllDefinitions() async {
    if (_definitionCache == null) {
      await _defGuard.run(() => _loadDefinitionsFromDb(2000));
    }
    return List.unmodifiable(_definitionCache!);
  }

  Future<void> _loadDefinitionsFromDb(int limit) async {
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

  @override
  Future<List<DefinitionModel>> getSynonymDistractorPool({
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
          .where((d) => d.word.isNotEmpty && seen.add(d.word))
          .toList();
    } catch (e) {
      throw RepositoryException('Failed to load synonym distractor pool',
          cause: e);
    }
  }

  @override
  Future<List<DefinitionModel>> getAntonymDistractorPool({
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
          .where((d) => d.word.isNotEmpty && seen.add(d.word))
          .toList();
    } catch (e) {
      throw RepositoryException('Failed to load antonym distractor pool',
          cause: e);
    }
  }

  // ── Synonyms / Antonyms ────────────────────────────────────────────────

  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions({
    required int count,
  }) async {
    return _buildSynonymAntonymQuestions(count: count, isAntonym: false);
  }

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

    final wordRows = await _db.db.rawQuery('''
      SELECT w.id, w.word,
        (SELECT GROUP_CONCAT($col, '|') FROM $table WHERE word_id = w.id) AS answers
      FROM words w
      WHERE EXISTS (SELECT 1 FROM $table WHERE word_id = w.id)
      ORDER BY RANDOM()
      LIMIT ?
    ''', [count * 2]);

    if (wordRows.isEmpty) return [];

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
        allCorrect: correctList,
      ));
    }

    final sessionCorrects = questions.map((q) => q.correctAnswer).toSet();
    final rng2 = Random();
    return questions.map((q) {
      final cleanOpts = q.options
          .where((o) => o == q.correctAnswer ||
              !sessionCorrects.contains(o))
          .toList();
      if (cleanOpts.length < 4) return q;
      cleanOpts.shuffle(rng2);
      return ResolvedSynonymAntonymQuestion(
        word: q.word,
        correctAnswer: q.correctAnswer,
        options: cleanOpts,
        allCorrect: q.allCorrect,
      );
    }).toList();
  }

  // ── Rich Quotes ────────────────────────────────────────────────────────

  /// G-12: Filters out mastered quotes so players see fresh content.
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

    // G-12: Get mastered quote IDs and filter them out of the pool.
    final masteredIds = await _db.getMasteredQuoteIds();

    var pool = eraId != null
        ? quotes.where((q) => q.eraId == eraId).toList()
        : quotes.toList();

    // Remove mastered quotes from the pool.
    if (masteredIds.isNotEmpty) {
      pool = pool.where((q) => !masteredIds.contains(q.id)).toList();
    }

    pool.shuffle(rng);

    // Fallback: if too few unmastered quotes remain, use the full pool.
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

      // G-12: Record this quote as seen for mastery tracking.
      _db.recordQuoteSeen(q.id);

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
    await _quoteGuard.run(() => _loadRichQuotes());
  }

  Future<void> _loadRichQuotes() async {
    if (_richQuoteCache != null && _authorCache != null && _eraCache != null) {
      return;
    }

    final authorsRaw = await rootBundle.loadString('assets/json/quote_authors.json');
    final erasRaw = await rootBundle.loadString('assets/json/quote_eras.json');

    final authorList = (jsonDecode(authorsRaw) as List)
        .map((e) => QuoteAuthorModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _authorCache = {for (final a in authorList) a.id: a};

    final eraList = (jsonDecode(erasRaw) as List)
        .map((e) => QuoteEraModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _eraCache = {for (final e in eraList) e.id: e};

    final quotesRaw = await rootBundle.loadString('assets/json/quotes.json');
    final validAuthorIds = _authorCache!.keys.toSet();
    final validEraIds = _eraCache!.keys.toSet();
    _richQuoteCache = (jsonDecode(quotesRaw) as List)
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

  // ── Utility ───────────────────────────────────────────────────────────

  @override
  void clearGameCache() {
    _ipaCache = null;
    _definitionCache = null;
  }

  @override
  void clearCache() {
    _ipaCache = null;
    _definitionCache = null;
    _richQuoteCache = null;
    _authorCache = null;
    _eraCache = null;
  }

  // ── Word data ───────────────────────────────────────────────────────────

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

  @override
  Future<Map<String, int>> getWordIdsByLowercase(List<String> words) async {
    if (words.isEmpty) return const {};
    try {
      final lower = words.map((w) => w.toLowerCase()).toList();
      final ph = lower.map((_) => '?').join(',');
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

  // ── Writes ──────────────────────────────────────────────────────────────

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
