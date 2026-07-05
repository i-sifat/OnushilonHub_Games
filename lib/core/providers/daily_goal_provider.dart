import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database_service.dart';

const int kDailyGoal = 5;

final dailyGoalProvider = FutureProvider<int>((ref) async {
  return DatabaseService.instance.getTodaySessionCount();
});
