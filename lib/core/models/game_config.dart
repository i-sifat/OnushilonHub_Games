import 'package:flutter/material.dart';

enum GameType {
  unscramble,
  synonymMatch,
  antonymMatch,
  meaningChase,
  trueFalse,
  speedRacing,
  whoseQuote,
  ipaMatch,
  definitionMatch;

  String get label {
    switch (this) {
      case GameType.unscramble:
        return 'Unscramble';
      case GameType.synonymMatch:
        return 'Synonym Match';
      case GameType.antonymMatch:
        return 'Antonym Match';
      case GameType.meaningChase:
        return 'Meaning Chase';
      case GameType.trueFalse:
        return 'True or False';
      case GameType.speedRacing:
        return 'Speed Racing';
      case GameType.whoseQuote:
        return 'Whose Quote';
      case GameType.ipaMatch:
        return 'IPA Match';
      case GameType.definitionMatch:
        return 'Definition Match';
    }
  }

  String get subtitle {
    switch (this) {
      case GameType.unscramble:
        return 'Make the correct word.';
      case GameType.synonymMatch:
        return 'Find the word closest in meaning.';
      case GameType.antonymMatch:
        return 'Find the word opposite in meaning.';
      case GameType.meaningChase:
        return 'Pick the right meaning.';
      case GameType.trueFalse:
        return 'Decide if the statement is true.';
      case GameType.speedRacing:
        return 'Answer before the timer runs out.';
      case GameType.whoseQuote:
        return 'Identify the author of the famous quote.';
      case GameType.ipaMatch:
        return 'Match the word to its pronunciation.';
      case GameType.definitionMatch:
        return 'Pick the correct definition.';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.unscramble:
        return Icons.shuffle_rounded;
      case GameType.synonymMatch:
        return Icons.compare_arrows_rounded;
      case GameType.antonymMatch:
        return Icons.swap_horiz_rounded;
      case GameType.meaningChase:
        return Icons.translate_rounded;
      case GameType.trueFalse:
        return Icons.check_circle_outline_rounded;
      case GameType.speedRacing:
        return Icons.speed_rounded;
      case GameType.whoseQuote:
        return Icons.format_quote_rounded;
      case GameType.ipaMatch:
        return Icons.record_voice_over_rounded;
      case GameType.definitionMatch:
        return Icons.menu_book_rounded;
    }
  }

  Color get iconBg {
    switch (this) {
      case GameType.unscramble:
        return const Color(0xFFE3F2FD);
      case GameType.synonymMatch:
        return const Color(0xFFF3E5F5);
      case GameType.antonymMatch:
        return const Color(0xFFFCE4EC);
      case GameType.meaningChase:
        return const Color(0xFFE8F5E9);
      case GameType.trueFalse:
        return const Color(0xFFFFF8E1);
      case GameType.speedRacing:
        return const Color(0xFFE8F5E9);
      case GameType.whoseQuote:
        return const Color(0xFFE3F2FD);
      case GameType.ipaMatch:
        return const Color(0xFFE0F2F1);
      case GameType.definitionMatch:
        return const Color(0xFFF9FBE7);
    }
  }

  Color get iconColor {
    switch (this) {
      case GameType.unscramble:
        return const Color(0xFF1565C0);
      case GameType.synonymMatch:
        return const Color(0xFF6A1B9A);
      case GameType.antonymMatch:
        return const Color(0xFFC62828);
      case GameType.meaningChase:
        return const Color(0xFF2E7D32);
      case GameType.trueFalse:
        return const Color(0xFFE65100);
      case GameType.speedRacing:
        return const Color(0xFF1B5E20);
      case GameType.whoseQuote:
        return const Color(0xFF0D47A1);
      case GameType.ipaMatch:
        return const Color(0xFF00695C);
      case GameType.definitionMatch:
        return const Color(0xFF558B2F);
    }
  }

  String get dbKey {
    switch (this) {
      case GameType.unscramble:
        return 'unscramble';
      case GameType.synonymMatch:
        return 'synonym_match';
      case GameType.antonymMatch:
        return 'antonym_match';
      case GameType.meaningChase:
        return 'meaning_chase';
      case GameType.trueFalse:
        return 'true_false';
      case GameType.speedRacing:
        return 'speed_racing';
      case GameType.whoseQuote:
        return 'whose_quote';
      case GameType.ipaMatch:
        return 'ipa_match';
      case GameType.definitionMatch:
        return 'definition_match';
    }
  }

  static GameType fromString(String key) {
    switch (key) {
      case 'unscramble':
        return GameType.unscramble;
      case 'synonym_match':
        return GameType.synonymMatch;
      case 'antonym_match':
        return GameType.antonymMatch;
      case 'meaning_chase':
        return GameType.meaningChase;
      case 'true_false':
        return GameType.trueFalse;
      case 'speed_racing':
        return GameType.speedRacing;
      case 'whose_quote':
        return GameType.whoseQuote;
      case 'ipa_match':
        return GameType.ipaMatch;
      case 'definition_match':
        return GameType.definitionMatch;
      // legacy key — map to meaningChase so old DB rows don't crash
      case 'error_detection':
        return GameType.meaningChase;
      default:
        return GameType.unscramble;
    }
  }
}

class GameConfig {
  final GameType gameType;
  final int difficulty; // 1 = easy, 2 = medium, 3 = hard
  final int questionCount; // 0 = all
  final String? era; // for whose_quote
  final String? category; // for whose_quote
  final bool trackAnswerTime; // for unscramble

  const GameConfig({
    required this.gameType,
    this.difficulty = 1,
    this.questionCount = 10,
    this.era,
    this.category,
    this.trackAnswerTime = false,
  });
}

class GameResult {
  final GameType gameType;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int durationSeconds;
  /// Base XP from correct answers (correctCount x xpPerCorrect).
  final int baseXp;
  /// Bonus XP from speed streaks; 0 for non-Speed-Racing games.
  final int bonusXp;
  final List<MistakeItem> mistakes;

  const GameResult({
    required this.gameType,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.durationSeconds,
    required this.baseXp,
    this.bonusXp = 0,
    required this.mistakes,
  });

  /// Total XP earned (base + speed bonus).
  int get xpEarned => baseXp + bonusXp;

  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0;
    return correctCount / total;
  }
}

class MistakeItem {
  final String question;
  final String userAnswer;
  final String correctAnswer;

  const MistakeItem({
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
  });
}
