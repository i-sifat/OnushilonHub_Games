import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/custom_list_extensions.dart';
import '../../database/database_service.dart';
import '../../database/game_data_repository.dart' show databaseServiceProvider;

/// F-02: Represents a user-created word list.
class CustomWordList {
  final int id;
  final String name;
  final int createdAt;
  final List<String> words;

  const CustomWordList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.words,
  });

  CustomWordList copyWith({String? name, List<String>? words}) {
    return CustomWordList(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      words: words ?? this.words,
    );
  }
}

/// F-02: Manages the full list of [CustomWordList]s.
class CustomListNotifier extends AsyncNotifier<List<CustomWordList>> {
  DatabaseService get _db => ref.read(databaseServiceProvider);

  @override
  Future<List<CustomWordList>> build() async {
    return _loadAll();
  }

  Future<List<CustomWordList>> _loadAll() async {
    final rows = await _db.getAllWordLists();
    final lists = <CustomWordList>[];
    for (final row in rows) {
      final listId = row['id'] as int;
      final words = await _db.getWordsInList(listId);
      lists.add(CustomWordList(
        id: listId,
        name: row['name'] as String,
        createdAt: row['created_at'] as int,
        words: words,
      ));
    }
    return lists;
  }

  /// Creates a new word list with [name].
  ///
  /// Throws a [StateError] with a friendly message if [name] is already
  /// taken (word_lists.name has a UNIQUE constraint) — callers should catch
  /// this and show it to the user rather than letting the raw
  /// [DatabaseException] surface.
  Future<void> create(String name) async {
    try {
      await _db.createWordList(name);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw StateError('A list named "$name" already exists.');
      }
      rethrow;
    }
    ref.invalidateSelf();
  }

  /// Renames list [id] to [newName]. See [create] for the duplicate-name
  /// error contract.
  Future<void> rename(int id, String newName) async {
    try {
      await _db.renameWordList(id, newName);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw StateError('A list named "$newName" already exists.');
      }
      rethrow;
    }
    ref.invalidateSelf();
  }

  /// Deletes list [id].
  Future<void> delete(int id) async {
    await _db.deleteWordList(id);
    ref.invalidateSelf();
  }

  /// Adds [word] to list [listId].
  Future<void> addWord(int listId, String word) async {
    await _db.addWordToList(listId, word);
    ref.invalidateSelf();
  }

  /// Removes [word] from list [listId].
  Future<void> removeWord(int listId, String word) async {
    await _db.removeWordFromList(listId, word);
    ref.invalidateSelf();
  }
}

/// Top-level provider for all custom word lists.
final customListsProvider =
    AsyncNotifierProvider<CustomListNotifier, List<CustomWordList>>(
        CustomListNotifier.new);
