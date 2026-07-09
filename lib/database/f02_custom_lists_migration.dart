import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// F-02: Custom word lists schema migration.
///
/// Adds `word_lists` (id, name, created_at) and
/// `word_list_items` (list_id, word) tables.
extension F02CustomListsMigration on DatabaseService {
  /// Idempotently creates the custom-list tables.
  Future<void> applyF02CustomListsMigration() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_lists (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_list_items (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id  INTEGER NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
        word     TEXT NOT NULL,
        UNIQUE(list_id, word)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wli_list ON word_list_items(list_id)',
    );
  }

  // ── CRUD helpers ────────────────────────────────────────────────

  Future<int> createWordList(String name) async {
    return db.insert('word_lists', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameWordList(int listId, String newName) async {
    await db.update('word_lists', {'name': newName},
        where: 'id = ?', whereArgs: [listId]);
  }

  Future<void> deleteWordList(int listId) async {
    await db.delete('word_lists', where: 'id = ?', whereArgs: [listId]);
  }

  Future<List<Map<String, Object?>>> getWordLists() =>
      db.query('word_lists', orderBy: 'created_at DESC');

  Future<void> addWordToList(int listId, String word) async {
    await db.insert(
      'word_list_items',
      {'list_id': listId, 'word': word},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeWordFromList(int listId, String word) async {
    await db.delete('word_list_items',
        where: 'list_id = ? AND word = ?', whereArgs: [listId, word]);
  }

  Future<List<String>> getWordsInList(int listId) async {
    final rows = await db.query('word_list_items',
        columns: ['word'], where: 'list_id = ?', whereArgs: [listId]);
    return rows.map((r) => r['word'] as String).toList();
  }
}
