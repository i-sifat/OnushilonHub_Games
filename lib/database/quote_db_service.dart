import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

final quoteDbServiceProvider = Provider((ref) {
  return QuoteDbService(DatabaseService.instance);
});

/// Handles quotes_data DB operations (seeding and lookup).
///
/// Extracted from DatabaseService (A-01).
class QuoteDbService {
  final DatabaseService _db;

  const QuoteDbService(this._db);

  static const _quotesVersion = 1;

  /// Seeds quotes from [quotes] JSON list if not already seeded or if the
  /// stored version is older than [_quotesVersion].
  Future<void> ensureQuotesSeeded(
    List<Map<String, dynamic>> quotes,
  ) async {
    final rows = await _db.db.rawQuery(
      "SELECT value FROM quotes_meta WHERE key = 'version'",
    );
    final storedVersion = rows.isEmpty
        ? 0
        : int.tryParse(rows.first['value'] as String? ?? '0') ?? 0;
    if (storedVersion >= _quotesVersion) {
      // Already seeded at this version; check count.
      final count = Sqflite.firstIntValue(
            await _db.db.rawQuery('SELECT COUNT(*) FROM quotes_data'),
          ) ??
          0;
      if (count > 0) return;
    }
    await _db.db.transaction((txn) async {
      await txn.delete('quotes_data');
      for (final q in quotes) {
        await txn.insert(
          'quotes_data',
          {
            'id': q['id'],
            'quote': q['text'] ?? q['quote'],
            'source_name': q['author_id']?.toString() ?? '',
            'source_type': 'author',
            'difficulty': 1,
            'era': q['era_id']?.toString() ?? '',
            'category': (q['tags'] as List?)?.firstOrNull?.toString() ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'quotes_meta',
        {'key': 'version', 'value': '$_quotesVersion'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<int> getQuoteCount({
    int? eraId,
    String? category,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (eraId != null) { conditions.add('era = ?'); args.add(eraId.toString()); }
    if (category != null && category != 'all') { conditions.add('category = ?'); args.add(category); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    return Sqflite.firstIntValue(
      await _db.db.rawQuery('SELECT COUNT(*) FROM quotes_data $where', args),
    ) ?? 0;
  }

  Future<List<String>> getDistinctEras() async => [];
  Future<List<String>> getDistinctCategories() async => [];
}
