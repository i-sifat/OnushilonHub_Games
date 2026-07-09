// F-05: 7-day game session stats for progress charts on ProfileScreen.
//
// DailyStats aggregates correct/wrong counts and XP earned per calendar day
// for the past 7 days. ProfileScreen uses this to render:
//   • 7-day XP bar chart (fl_chart BarChart)
//   • Accuracy trend line (fl_chart LineChart)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database_service.dart';

class DailyStats {
  final DateTime date;
  final int xp;
  final int correct;
  final int wrong;

  const DailyStats({
    required this.date,
    required this.xp,
    required this.correct,
    required this.wrong,
  });

  double get accuracy {
    final total = correct + wrong;
    return total == 0 ? 0 : correct / total;
  }

  bool get hasActivity => xp > 0 || correct > 0;
}

/// Returns daily stats for the last 7 calendar days (today is index 6).
/// Each entry corresponds to one day even if no sessions were played.
final gameSessionStatsProvider = FutureProvider<List<DailyStats>>((ref) async {
  final db = DatabaseService.instance.db;

  final now = DateTime.now();
  final sevenDaysAgo = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));

  final startMs = sevenDaysAgo.millisecondsSinceEpoch;

  // Query game_sessions for the last 7 days
  final rows = await db.rawQuery(
    '''
    SELECT
      date(played_at / 1000, 'unixepoch', 'localtime') AS day,
      SUM(score)         AS total_xp,
      SUM(correct_count) AS total_correct,
      SUM(wrong_count)   AS total_wrong
    FROM game_sessions
    WHERE played_at >= ?
    GROUP BY day
    ORDER BY day ASC
    ''',
    [startMs],
  );

  // Build a map from date string → stats
  final rowMap = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    rowMap[r['day'] as String] = r;
  }

  // Produce one entry per day, filling zeros for days with no sessions
  final result = <DailyStats>[];
  for (var i = 0; i < 7; i++) {
    final day = sevenDaysAgo.add(Duration(days: i));
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final r = rowMap[key];
    result.add(DailyStats(
      date: day,
      xp: (r?['total_xp'] as int?) ?? 0,
      correct: (r?['total_correct'] as int?) ?? 0,
      wrong: (r?['total_wrong'] as int?) ?? 0,
    ));
  }

  return result;
});
