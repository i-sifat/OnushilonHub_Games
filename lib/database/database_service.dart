import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../core/models/user_progress_model.dart';

/// Central SQLite service.
///
/// Strategy:
///   • vocabulary.db ships as a Flutter asset (assets/db/vocabulary.db).
///   • Version-checked on every launch: if the bundled asset is newer than the
///     on-disk copy (checked via a stored schema version), the asset replaces
///     the old copy — vocabulary content is always up to date.
///   • User-data tables are created via CREATE TABLE IF NOT EXISTS on every open.
///
/// DB schema version — bump this whenever the asset DB changes.
const int _kAssetDbVersion = 2; // v2: deduped + difficulty col + no hypernyms

/// Startup time target: < 300 ms.
class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  Database? _db;

  /// Always true — no background seeding in this version.
  /// Kept for backward compatibility with HomeScreen.
  final ValueNotifier<bool> seedReady = ValueNotifier(true);

  bool get isInitialized => _db != null;

  /// Always true — seeding is a no-op in this version.
  bool get seedComplete => true;

  /// No-op. Kept for backward compatibility.
  Future<void> seedInBackground() async {}

  /// No-op. Kept for backward compatibility.
  Future<void> ensureSeedComplete() async {}

  Database get db {
    if (_db == null) {
      throw StateError('DatabaseService not initialized. Call init() first.');
    }
    return _db!;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final path = await _resolveDbPath();
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => _ensureUserTables(db),
      onOpen: _ensureUserTables,
    );
  }

  /// Copies the bundled asset DB to the documents directory on first launch,
  /// and re-copies it whenever [_kAssetDbVersion] is bumped — ensuring the
  /// vocabulary content stays current across app updates while preserving all
  /// user progress (which lives in separate user-data tables).
  Future<String> _resolveDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'vocabulary.db');
    final metaPath = join(dir.path, 'db_asset_version.txt');
    final metaFile = File(metaPath);

    final storedVersion = metaFile.existsSync()
        ? int.tryParse(await metaFile.readAsString()) ?? 0
        : 0;

    if (!File(path).existsSync() || storedVersion < _kAssetDbVersion) {
      final data = await rootBundle.load('assets/db/vocabulary.db');
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      await metaFile.writeAsString('$_kAssetDbVersion');
    }
    return path;
  }

  Future<void> _ensureUserTables(Database db) async {
    // User progress
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_progress (
        id           INTEGER PRIMARY KEY,
        total_xp     INTEGER NOT NULL DEFAULT 0,
        streak       INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER,
        theme_mode   TEXT NOT NULL DEFAULT 'system'
      )
    ''');
    final cnt = (await db.rawQuery(
      'SELECT COUNT(*) AS c FROM user_progress WHERE id = 1',
    )).first['c'] as int;
    if (cnt == 0) {
      await db.insert('user_progress', {
        'id': 1, 'total_xp': 0, 'streak': 0, 'theme_mode': 'system',
      });
    }

    // Word progress — tracks per-game mastery
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_progress (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id        INTEGER NOT NULL,
        game_type      TEXT NOT NULL,
        status         TEXT NOT NULL DEFAULT 'new',
        attempts       INTEGER NOT NULL DEFAULT 0,
        last_attempted INTEGER,
        UNIQUE(word_id, game_type)
      )
    ''');

    // Game sessions history
    await db.execute('''
      CREATE TABLE IF NOT EXISTS game_sessions (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        game_type        TEXT NOT NULL,
        score            INTEGER NOT NULL DEFAULT 0,
        correct_count    INTEGER NOT NULL DEFAULT 0,
        wrong_count      INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        played_at        INTEGER NOT NULL
      )
    ''');

    // Saved words
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_words (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        word       TEXT NOT NULL UNIQUE,
        definition TEXT NOT NULL,
        saved_at   INTEGER NOT NULL
      )
    ''');

    // Quotes (seeded lazily from small JSON files)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes_data (
        id          INTEGER PRIMARY KEY,
        quote       TEXT NOT NULL,
        source_name TEXT NOT NULL,
        source_type TEXT NOT NULL,
        difficulty  INTEGER NOT NULL DEFAULT 1,
        era         TEXT NOT NULL DEFAULT '',
        category    TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Performance indices on user-data tables
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wp_game_status ON word_progress(game_type, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_game ON game_sessions(game_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_played_at ON game_sessions(played_at)',
    );
  }

  // ── Word Queries ──────────────────────────────────────────────────────────

  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    /// When true, only words that have an entry in [definitions] (sense_order=0)
    /// are returned. Set this for any game that displays a definition so words
    /// with no usable definition are excluded at the DB level.
    bool requiresDefinition = false,
    /// When true, only words that have at least one synonym are returned.
    bool requiresSynonym = false,
    /// When true, only words that have at least one antonym are returned.
    bool requiresAntonym = false,
  }) async {
    // Use the stored difficulty column rather than computing LENGTH() at query
    // time — significantly faster on large result sets.
    final diffClause = difficulty > 0 ? 'AND w.difficulty = $difficulty' : '';
    final defClause = requiresDefinition
        ? 'AND EXISTS (SELECT 1 FROM definitions d WHERE d.word_id = w.id AND d.sense_order = 0 AND LENGTH(d.definition) > 0)'
        : '';
    final synClause = requiresSynonym
        ? 'AND EXISTS (SELECT 1 FROM synonyms s WHERE s.word_id = w.id)'
        : '';
    final antClause = requiresAntonym
        ? 'AND EXISTS (SELECT 1 FROM antonyms a WHERE a.word_id = w.id)'
        : '';
    final fetchLimit = (limit * 4).clamp(limit, 2000);

    // Unscramble requires UPPERCASE-only words so that scrambled tiles are
    // consistent and lowercase duplicate rows (which lack English definitions)
    // are excluded. Other game types should see the full word pool.
    final upperClause =
        gameType == 'unscramble' ? 'AND w.word = UPPER(w.word)' : '';

    final rows = await db.rawQuery('''
      SELECT w.id, w.word, wp.last_attempted
      FROM words w
      LEFT JOIN word_progress wp
        ON w.id = wp.word_id AND wp.game_type = ?
      WHERE (wp.status IS NULL OR wp.status != 'mastered')
      $upperClause
      $diffClause
      $defClause
      $synClause
      $antClause
      ORDER BY RANDOM()
      LIMIT $fetchLimit
    ''', [gameType]);

    final now = DateTime.now().millisecondsSinceEpoch;
    final sorted = rows.map((r) {
      final last = r['last_attempted'] as int?;
      return (id: r['id'] as int, priority: last == null ? 999999999 : now - last);
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final ids = sorted.take(limit).map((e) => e.id).toList();
    return _loadWordRows(ids);
  }

  /// Returns the difficulty level (1/2/3) for a word length, matching the
  /// pre-computed [difficulty] column in the [words] table.
  static int difficultyForLength(int len) {
    if (len <= 5) return 1;
    if (len <= 9) return 2;
    return 3;
  }

  Future<List<WordRow>> _loadWordRows(List<int> ids) async {
    if (ids.isEmpty) return [];
    final ph = ids.map((_) => '?').join(',');

    // Word texts
    final wordTexts = await db.rawQuery(
      'SELECT id, word FROM words WHERE id IN ($ph)', ids,
    );
    final wordTextMap = {for (final r in wordTexts) r['id'] as int: r['word'] as String};

    // Definitions (first sense only) with example
    final defRows = await db.rawQuery('''
      SELECT d.word_id, d.pos, d.definition, ue.example
      FROM definitions d
      LEFT JOIN usage_examples ue ON ue.definition_id = d.id
      WHERE d.word_id IN ($ph) AND d.sense_order = 0
    ''', ids);
    final defMap = {for (final r in defRows) r['word_id'] as int: r};

    // Synonyms (up to 10 per word, deduplicated at source)
    final synRows = await db.rawQuery('''
      SELECT word_id, GROUP_CONCAT(synonym, '|') AS syns
      FROM (SELECT word_id, synonym FROM synonyms WHERE word_id IN ($ph) LIMIT 10)
      GROUP BY word_id
    ''', ids);
    final synMap = {for (final r in synRows) r['word_id'] as int: r['syns'] as String? ?? ''};

    // Antonyms (up to 10 per word, deduplicated at source)
    final antRows = await db.rawQuery('''
      SELECT word_id, GROUP_CONCAT(antonym, '|') AS ants
      FROM (SELECT word_id, antonym FROM antonyms WHERE word_id IN ($ph) LIMIT 10)
      GROUP BY word_id
    ''', ids);
    final antMap = {for (final r in antRows) r['word_id'] as int: r['ants'] as String? ?? ''};

    // Bengali meanings — IPA-table trimming means only matching words remain
    final bnRows = await db.rawQuery('''
      SELECT LOWER(w.word) AS wl, bd.bn
      FROM words w
      JOIN bengali_dictionary bd ON LOWER(w.word) = LOWER(bd.en)
      WHERE w.id IN ($ph)
    ''', ids);
    final bnMap = {for (final r in bnRows) r['wl'] as String: r['bn'] as String};

    return ids.map((id) {
      final word = wordTextMap[id] ?? '';
      final defRow = defMap[id];
      final definition = defRow?['definition'] as String? ?? '';
      final example = (defRow?['example'] as String? ?? '').isNotEmpty
          ? defRow!['example'] as String
          : word;
      final pos = defRow?['pos'] as String? ?? '';
      final syns = (synMap[id] ?? '').split('|').where((s) => s.isNotEmpty).toList();
      final ants = (antMap[id] ?? '').split('|').where((s) => s.isNotEmpty).toList();
      // Trim verbose bn values like "সত্য (Adj.), প্রকৃত (Adj.)..." to just
      // the primary meaning before the first comma.
      final rawBn = bnMap[word.toLowerCase()] ?? '';
      final bn = rawBn.isEmpty ? '' : rawBn.split(',').first.trim();
      final len = word.length;

      return WordRow(
        id: id,
        word: word,
        definition: definition.isNotEmpty ? definition : bn,
        example: example,
        pos: pos,
        difficulty: difficultyForLength(len),
        synonyms: syns,
        antonyms: ants,
        banglaMeaning: bn,
        supportedGames: const [
          'unscramble', 'synonym_match', 'antonym_match',
          'meaning_chase', 'true_false', 'speed_racing',
        ],
      );
    }).where((w) => w.word.isNotEmpty).toList();
  }

  Future<WordRow?> getDailyWord() async {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words')) ?? 0;
    if (total == 0) return null;
    final rows = await db.rawQuery(
      'SELECT id FROM words ORDER BY id LIMIT 1 OFFSET ?',
      [dayOfYear % total],
    );
    if (rows.isEmpty) return null;
    final list = await _loadWordRows([rows.first['id'] as int]);
    return list.isEmpty ? null : list.first;
  }

  Future<int> getEligibleWordCount({
    required String gameType,
    required int difficulty,
  }) async {
    final diffClause = difficulty > 0 ? 'AND w.difficulty = $difficulty' : '';
    return Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM words w
      WHERE w.id NOT IN (
        SELECT wp.word_id FROM word_progress wp
        WHERE wp.game_type = ? AND wp.status = 'mastered'
      )
      $diffClause
    ''', [gameType])) ?? 0;
  }

  // ── Progress Queries ──────────────────────────────────────────────────────

  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  }) async {
    await db.rawInsert('''
      INSERT INTO word_progress (word_id, game_type, status, attempts, last_attempted)
      VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(word_id, game_type) DO UPDATE SET
        status = excluded.status,
        attempts = attempts + 1,
        last_attempted = excluded.last_attempted
    ''', [wordId, gameType, status, DateTime.now().millisecondsSinceEpoch]);
  }

  Future<Map<String, int>> getWordProgressCounts({required String gameType}) async {
    final mastered = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM word_progress WHERE game_type = ? AND status = 'mastered'",
      [gameType],
    )) ?? 0;
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM words'),
    ) ?? 0;
    return {'mastered': mastered, 'total': total};
  }

  Future<Map<String, Map<String, int>>> getAllGameProgressCounts() async {
    const gameTypes = [
      'unscramble', 'synonym_match', 'antonym_match',
      'meaning_chase', 'true_false', 'speed_racing',
    ];
    final result = <String, Map<String, int>>{};
    for (final g in gameTypes) {
      result[g] = await getWordProgressCounts(gameType: g);
    }
    return result;
  }

  // ── Session Queries ───────────────────────────────────────────────────────

  Future<void> saveGameSession(GameSessionModel session) async {
    await db.insert('game_sessions', session.toDb());
  }

  /// Returns up to [limit] most recent sessions, optionally filtered by
  /// [gameType]. Capped to prevent unbounded growth as sessions accumulate.
  Future<List<GameSessionModel>> getGameSessions({
    String? gameType,
    int limit = 200,
  }) async {
    final rows = await db.query(
      'game_sessions',
      where: gameType != null ? 'game_type = ?' : null,
      whereArgs: gameType != null ? [gameType] : null,
      orderBy: 'played_at DESC',
      limit: limit,
    );
    return rows.map(GameSessionModel.fromDb).toList();
  }

  Future<Map<String, dynamic>> getProfileStats() async {
    final totalSessions =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM game_sessions')) ?? 0;
    final totalCorrect =
        Sqflite.firstIntValue(await db.rawQuery('SELECT SUM(correct_count) FROM game_sessions')) ?? 0;
    final totalWrong =
        Sqflite.firstIntValue(await db.rawQuery('SELECT SUM(wrong_count) FROM game_sessions')) ?? 0;
    final totalMastered = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM word_progress WHERE status = 'mastered'",
    )) ?? 0;

    final gameStats = await db.rawQuery('''
      SELECT game_type,
             COUNT(*) as sessions,
             SUM(score) as total_score,
             SUM(correct_count) as correct,
             SUM(wrong_count) as wrong
      FROM game_sessions
      GROUP BY game_type
      ORDER BY total_score DESC
    ''');

    return {
      'totalSessions': totalSessions,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalMastered': totalMastered,
      'gameStats': gameStats,
    };
  }

  Future<bool> hasPlayedGame(String gameType) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM game_sessions WHERE game_type = ?',
        [gameType],
      ),
    );
    return (count ?? 0) > 0;
  }

  Future<Set<String>> getPlayedGameTypes() async {
    final rows = await db.rawQuery('SELECT DISTINCT game_type FROM game_sessions');
    return rows.map((r) => r['game_type'] as String).toSet();
  }

  Future<String?> getMostRecentGameType() async {
    final rows = await db.rawQuery(
      'SELECT game_type FROM game_sessions ORDER BY played_at DESC LIMIT 1',
    );
    return rows.isEmpty ? null : rows.first['game_type'] as String?;
  }

  // ── User Progress ─────────────────────────────────────────────────────────

  Future<UserProgressModel> getUserProgress() async {
    final rows = await db.query('user_progress', where: 'id = 1');
    if (rows.isEmpty) return const UserProgressModel();
    return UserProgressModel.fromDb(rows.first);
  }

  Future<void> updateUserProgress(UserProgressModel model) async {
    await db.update('user_progress', model.toDb(), where: 'id = 1');
  }

  Future<void> addXp(int xp) async {
    await db.rawUpdate(
      'UPDATE user_progress SET total_xp = total_xp + ? WHERE id = 1',
      [xp],
    );
  }

  Future<void> updateStreak() async {
    final rows = await db.query(
      'user_progress',
      columns: ['streak', 'last_played_at'],
      where: 'id = 1',
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastMs = row['last_played_at'] as int?;
    final lastDay = lastMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastMs).let(
            (d) => DateTime(d.year, d.month, d.day))
        : null;

    if (lastDay == today) return;

    final streak = row['streak'] as int;
    final yesterday = today.subtract(const Duration(days: 1));
    final newStreak = (lastDay == yesterday) ? streak + 1 : 1;

    await db.update(
      'user_progress',
      {'streak': newStreak, 'last_played_at': today.millisecondsSinceEpoch},
      where: 'id = 1',
    );
  }

  // ── Saved Words ───────────────────────────────────────────────────────────

  Future<void> saveWord(String word, String definition) async {
    await db.insert(
      'saved_words',
      {'word': word, 'definition': definition, 'saved_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unsaveWord(String word) async {
    await db.delete('saved_words', where: 'word = ?', whereArgs: [word]);
  }

  Future<bool> isWordSaved(String word) async {
    return (Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM saved_words WHERE word = ?', [word],
        )) ??
        0) > 0;
  }

  Future<List<Map<String, dynamic>>> getSavedWords() async {
    return db.query('saved_words', orderBy: 'saved_at DESC');
  }

  // ── Daily Goal ────────────────────────────────────────────────────────────

  Future<int> getTodaySessionCount() async {
    final start = DateTime.now().let((n) =>
        DateTime(n.year, n.month, n.day).millisecondsSinceEpoch);
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM game_sessions WHERE played_at >= ?', [start],
        )) ??
        0;
  }

  // ── Quotes seeding ────────────────────────────────────────────────────────

  static const _quotesVersion = 1;

  Future<void> ensureQuotesSeeded(List<Map<String, dynamic>> quotes) async {
    final ver = await db.rawQuery(
      "SELECT value FROM quotes_meta WHERE key = 'version'",
    );
    if (ver.isNotEmpty &&
        int.tryParse(ver.first['value'] as String) == _quotesVersion) {
      return;
    }
    final batch = db.batch();
    batch.delete('quotes_data');
    for (final q in quotes) {
      batch.insert('quotes_data', q, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    batch.insert('quotes_meta', {'key': 'version', 'value': '$_quotesVersion'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getEligibleQuotesRaw({
    required int difficulty,
    required int limit,
    String? era,
    String? category,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (difficulty > 0) { conditions.add('difficulty = ?'); args.add(difficulty); }
    if (era != null && era != 'all') { conditions.add('era = ?'); args.add(era); }
    if (category != null && category != 'all') { conditions.add('category = ?'); args.add(category); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final lim = limit > 0 ? 'LIMIT $limit' : '';
    return db.rawQuery('SELECT * FROM quotes_data $where ORDER BY RANDOM() $lim', args);
  }

  Future<int> getEligibleQuoteCount({
    required int difficulty,
    String? era,
    String? category,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (difficulty > 0) { conditions.add('difficulty = ?'); args.add(difficulty); }
    if (era != null && era != 'all') { conditions.add('era = ?'); args.add(era); }
    if (category != null && category != 'all') { conditions.add('category = ?'); args.add(category); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM quotes_data $where', args),
        ) ?? 0;
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Clears all user-generated data: XP, sessions, word progress, saved words.
  /// Vocabulary data is preserved.
  Future<void> resetAllProgress() async {
    await db.transaction((txn) async {
      await txn.delete('word_progress');
      await txn.delete('game_sessions');
      await txn.delete('saved_words');
      await txn.update('user_progress', {
        'total_xp': 0,
        'streak': 0,
        'last_played_at': null,
      }, where: 'id = 1');
    });
  }

  // ── Era / Category (resolved from JSON, not DB) ───────────────────────────

  /// Eras and categories are sourced from the JSON quote files, not the DB.
  /// These stubs are kept for backward compatibility.
  Future<List<String>> getDistinctEras() async => [];
  Future<List<String>> getDistinctCategories() async => [];

  // Meaning Chase phrase fallback
  // Returns multi-word Bengali phrases (is_phrase=1) for Meaning Chase
  // fallback when not enough single-word questions can be built.
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases({
    required int limit,
  }) async {
    return db.rawQuery(
      'SELECT en, bn FROM bengali_dictionary'
      ' WHERE is_phrase = 1 AND LENGTH(TRIM(bn)) > 0'
      ' ORDER BY RANDOM() LIMIT ?',
      [limit],
    );
  }
}

// ── Extension helpers ─────────────────────────────────────────────────────────

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ── WordRow ───────────────────────────────────────────────────────────────────

/// Lightweight word data class returned by all DB queries.
class WordRow {
  final int id;
  final String word;
  final String definition;
  final String example;
  final String pos;
  final int difficulty;
  final List<String> synonyms;
  final List<String> antonyms;
  final String banglaMeaning;
  final List<String> supportedGames;

  const WordRow({
    required this.id,
    required this.word,
    required this.definition,
    required this.example,
    required this.pos,
    required this.difficulty,
    required this.synonyms,
    required this.antonyms,
    required this.banglaMeaning,
    required this.supportedGames,
  });
}
