import 'package:flutter/foundation.dart';

import '../../../core/utils/canonical_key.dart';
import '../../../core/models/word_model.dart';

/// A set of words that all share the same canonical key — i.e. they are
/// anagrams of each other. Example:
///
///   canonicalKey('wolf') == canonicalKey('flow') == 'flow'
///
/// → `UnscrambleGroup(canonicalKey: 'flow', validWords: ['wolf', 'flow'])`.
///
/// The Unscramble game uses these groups so that any valid anagram counts
/// as a correct answer for a given scramble — the player is not forced to
/// guess the single word that happened to be stored in the database.
@immutable
class UnscrambleGroup {
  /// Canonical (sorted-letters) key shared by every word in [validWords].
  final String canonicalKey;

  /// All accepted answers for this scramble, normalised to lowercase and
  /// deduplicated. Guaranteed non-empty.
  final List<String> validWords;

  /// The original word picked as the question prompt — used to source the
  /// example DB row (Bangla meaning, id, etc.). Always a member of
  /// [validWords].
  final WordModel primaryWord;

  const UnscrambleGroup({
    required this.canonicalKey,
    required this.validWords,
    required this.primaryWord,
  }) : assert(validWords.length > 0, 'validWords must be non-empty');

  /// True when [answer] is accepted for this group.
  ///
  /// We compare via canonical key rather than `validWords.contains` so that
  /// any anagram of the same letter set is accepted, even if the DB happens
  /// to be missing one (e.g. user types "flow" but only "wolf" was stored).
  bool acceptsAnswer(String answer) {
    final key = canonicalKey0(answer);
    if (key.isEmpty) return false;
    return key == canonicalKey;
  }
}

// Re-export with a unique name so the model file does not shadow the
// utility function when both are imported into the same library.
String canonicalKey0(String input) => canonicalKey(input);
