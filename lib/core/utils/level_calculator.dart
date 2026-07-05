/// Single source of truth for XP → level conversion.
///
/// Uses an exponential threshold curve: 100, 110, 121, 133 ...
/// so each level requires slightly more XP than the last.
class LevelCalculator {
  LevelCalculator._();

  /// Returns the level for a given [xp] amount (minimum level 1).
  static int levelFor(int xp) {
    if (xp <= 0) return 1;
    int level = 1;
    int threshold = 0;
    int increment = 100;
    while (xp >= threshold + increment) {
      threshold += increment;
      increment = (increment * 1.1).round();
      level++;
    }
    return level;
  }

  /// XP needed to reach the *next* level from the current [xp] value.
  static int xpToNextLevel(int xp) {
    int threshold = 0;
    int increment = 100;
    while (xp >= threshold + increment) {
      threshold += increment;
      increment = (increment * 1.1).round();
    }
    return (threshold + increment) - xp;
  }

  /// Total XP required to reach [level] from level 1.
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    int threshold = 0;
    int increment = 100;
    for (int i = 1; i < level; i++) {
      threshold += increment;
      increment = (increment * 1.1).round();
    }
    return threshold;
  }
}
