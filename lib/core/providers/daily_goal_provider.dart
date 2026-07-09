import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daily_goal_extensions.dart';
import '../../database/database_service.dart';

// Fallback constant kept for backward compatibility.
// Prefer [dailyGoalTargetProvider] for the live, user-configured value.
const int kDailyGoal = 5;

/// Today's completed session count (not the goal target).
final dailyGoalProvider = FutureProvider<int>((ref) async {
  return DatabaseService.instance.getTodaySessionCount();
});

/// The user's configured daily-goal session count (1–20, default 5).
///
/// Reads from `user_progress.daily_goal` in the DB.
/// Use [DatabaseService.instance.updateDailyGoal] to change the value,
/// then call `ref.invalidate(dailyGoalTargetProvider)` to refresh.
final dailyGoalTargetProvider = FutureProvider<int>((ref) async {
  return DatabaseService.instance.getDailyGoal();
});
