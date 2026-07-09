class UserProgressModel {
  final int id;
  final int totalXp;
  final int streak;
  final String themeMode;
  final DateTime? lastPlayedAt;
  final int dailyGoal;

  const UserProgressModel({
    this.id = 1,
    this.totalXp = 0,
    this.streak = 0,
    this.themeMode = 'system',
    this.lastPlayedAt,
    this.dailyGoal = 5,
  });

  factory UserProgressModel.fromDb(Map map) {
    return UserProgressModel(
      id: map['id'] as int,
      totalXp: map['total_xp'] as int,
      streak: map['streak'] as int,
      themeMode: map['theme_mode'] as String,
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'] as int)
          : null,
      dailyGoal: (map['daily_goal'] as int?) ?? 5,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'total_xp': totalXp,
      'streak': streak,
      'theme_mode': themeMode,
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'daily_goal': dailyGoal,
    };
  }

  UserProgressModel copyWith({
    int? totalXp,
    int? streak,
    String? themeMode,
    DateTime? lastPlayedAt,
    bool clearLastPlayedAt = false,
    int? dailyGoal,
  }) {
    return UserProgressModel(
      id: id,
      totalXp: totalXp ?? this.totalXp,
      streak: streak ?? this.streak,
      themeMode: themeMode ?? this.themeMode,
      lastPlayedAt: clearLastPlayedAt
          ? null
          : (lastPlayedAt ?? this.lastPlayedAt),
      dailyGoal: dailyGoal ?? this.dailyGoal,
    );
  }
}

class GameSessionModel {
  final int? id;
  final String gameType;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int durationSeconds;
  final DateTime playedAt;

  const GameSessionModel({
    this.id,
    required this.gameType,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.durationSeconds,
    required this.playedAt,
  });

  factory GameSessionModel.fromDb(Map map) {
    return GameSessionModel(
      id: map['id'] as int?,
      gameType: map['game_type'] as String,
      score: map['score'] as int,
      correctCount: map['correct_count'] as int,
      wrongCount: map['wrong_count'] as int,
      durationSeconds: map['duration_seconds'] as int,
      playedAt:
          DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'game_type': gameType,
      'score': score,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'duration_seconds': durationSeconds,
      'played_at': playedAt.millisecondsSinceEpoch,
    };
  }
}

class WordProgressModel {
  final int? id;
  final int wordId;
  final String gameType;
  final String status; // 'new', 'mistake', 'mastered'
  final int attempts;
  final DateTime? lastAttempted;

  const WordProgressModel({
    this.id,
    required this.wordId,
    required this.gameType,
    required this.status,
    required this.attempts,
    this.lastAttempted,
  });

  factory WordProgressModel.fromDb(Map map) {
    return WordProgressModel(
      id: map['id'] as int?,
      wordId: map['word_id'] as int,
      gameType: map['game_type'] as String,
      status: map['status'] as String,
      attempts: map['attempts'] as int,
      lastAttempted: map['last_attempted'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_attempted'] as int)
          : null,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'word_id': wordId,
      'game_type': gameType,
      'status': status,
      'attempts': attempts,
      'last_attempted': lastAttempted?.millisecondsSinceEpoch,
    };
  }
}
