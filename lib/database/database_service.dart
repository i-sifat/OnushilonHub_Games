import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
      // Required for `ON DELETE CASCADE` (used by word_list_items, F-02) to
      // actually take effect — SQLite disables FK enforcement by default.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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

    // F-01: Add SM-2 columns to word_progress (idempotent).
    // next_review_at: when this word is next due (Unix ms). NULL = due immediately.
    // ease_factor: SM-2 EF value controlling interval growth.
    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN next_review_at INTEGER',
      );
    } on DatabaseException catch (_) {/* column already exists */}
    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN ease_factor REAL',
      );
    } on DatabaseException catch (_) {/* column already exists */}

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
  // A-01: getEligibleWords/getDailyWord/getEligibleWordCount/_loadWordRows
  // moved to WordDbService. game_data_repository.dart now injects
  // WordDbService directly instead of calling DatabaseService for these.

  /// Returns the difficulty level (1/2/3) for a word length, matching the
  /// pre-computed [difficulty] column in the [words] table.
  static int difficultyForLength(int len) {
    if (len <= 5) return 1;
    if (len <= 9) return 2;
    return 3;
  }

  // ── Progress Queries ──────────────────────────────────────────────────────
  // A-01: markWordStatus/getWordProgressCounts/getAllGameProgressCounts moved
  // to ProgressDbService; saveGameSession moved to SessionDbService.
  // game_data_repository.dart (the only caller) now injects those directly.

  // ── Session Queries ───────────────────────────────────────────────────────
  // A-01: getGameSessions/getProfileStats/hasPlayedGame/getPlayedGameTypes
  // moved to SessionDbService. home_provider.dart / profile_screen.dart now
  // inject SessionDbService directly instead of calling DatabaseService.

  Future<String?> getMostRecentGameType() async {
    final rows = await db.rawQuery(
      'SELECT game_type FROM game_sessions ORDER BY played_at DESC LIMIT 1',
    );
    return rows.isEmpty ? null : rows.first['game_type'] as String?;
  }

  // ── User Progress ─────────────────────────────────────────────────────────
  // A-01: getUserProgress/updateUserProgress/addXp/updateStreak moved to
  // ProgressDbService. All internal callers now inject that service.

  // ── Saved Words ───────────────────────────────────────────────────────────
  // A-01: saveWord/unsaveWord/isWordSaved/getSavedWords moved to
  // SessionDbService. saved_words_provider.dart now injects that directly.

  // ── Daily Goal ────────────────────────────────────────────────────────────
  // A-01: getTodaySessionCount moved to SessionDbService. getDailyGoal /
  // updateDailyGoal stay here — they're DailyGoalExtensions, a genuine
  // single-source extension, not a Sprint 4/5 duplicate.

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

  // Meaning Chase phrase fallback moved to WordDbService.getMeaningChasePhrases
  // (A-01). game_data_repository.dart is the only caller and now injects
  // WordDbService directly.
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
