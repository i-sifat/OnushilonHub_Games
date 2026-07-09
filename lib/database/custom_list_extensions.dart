import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// F-02: Custom word lists — schema and query helpers.
///
/// Extends [DatabaseService] with two new tables:
///   - [word_lists]: user-created list metadata (id, name, created_at).
///   - [word_list_items]: word membership (list_id → word TEXT).
///
/// Tables are created lazily on first use via [_ensureCustomListTables].
extension CustomListExtensions on DatabaseService {
  Future<void> _ensureCustomListTables() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_lists (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_list_items (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id INTEGER NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
        word    TEXT NOT NULL,
        UNIQUE(list_id, word)
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wli_list ON word_list_items(list_id)',
      );
    } on DatabaseException catch (_) {}
  }

  /// Returns all custom word lists ordered by name.
  Future<List<Map<String, Object?>>> getAllWordLists() async {
    await _ensureCustomListTables();
    return db.rawQuery('SELECT * FROM word_lists ORDER BY name ASC');
  }

  /// Creates a new word list with [name]. Returns the new list ID.
  Future<int> createWordList(String name) async {
    await _ensureCustomListTables();
    return db.insert('word_lists', {
      'name': name.trim(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Renames the list with [listId] to [newName].
  Future<void> renameWordList(int listId, String newName) async {
    await _ensureCustomListTables();
    await db.update(
      'word_lists',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  /// Deletes the list with [listId] and all its items (CASCADE).
  Future<void> deleteWordList(int listId) async {
    await _ensureCustomListTables();
    await db.delete('word_lists', where: 'id = ?', whereArgs: [listId]);
  }

  /// Returns all words in list [listId], ordered alphabetically.
  Future<List<String>> getWordsInList(int listId) async {
    await _ensureCustomListTables();
    final rows = await db.rawQuery(
      'SELECT word FROM word_list_items WHERE list_id = ? ORDER BY word ASC',
      [listId],
    );
    return rows.map((r) => r['word'] as String).toList();
  }

  /// Adds [word] to list [listId]. No-op if already present.
  Future<void> addWordToList(int listId, String word) async {
    await _ensureCustomListTables();
    await db.insert(
      'word_list_items',
      {'list_id': listId, 'word': word.toUpperCase()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes [word] from list [listId].
  Future<void> removeWordFromList(int listId, String word) async {
    await _ensureCustomListTables();
    await db.delete(
      'word_list_items',
      where: 'list_id = ? AND word = ?',
      whereArgs: [listId, word.toUpperCase()],
    );
  }
}
