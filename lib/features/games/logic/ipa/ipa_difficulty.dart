/// Difficulty tiers used by the IPA Match distractor generator.
///
/// Each tier maps to a distinct set of phoneme transformations applied to the
/// correct IPA string. Higher difficulties produce more plausible — and thus
/// harder to discriminate — distractors. See
/// [IpaDistractorGenerator] for the transformation catalogue.
enum IpaDifficulty {
  easy,
  medium,
  hard;

  /// Maps the legacy integer difficulty carried on [GameConfig.difficulty]
  /// (1 = easy, 2 = medium, 3 = hard) onto the typed enum. Unknown values
  /// fall back to [easy] so malformed persisted configs cannot crash a game.
  static IpaDifficulty fromLegacy(int value) {
    switch (value) {
      case 2:
        return IpaDifficulty.medium;
      case 3:
        return IpaDifficulty.hard;
      case 1:
      default:
        return IpaDifficulty.easy;
    }
  }
}
