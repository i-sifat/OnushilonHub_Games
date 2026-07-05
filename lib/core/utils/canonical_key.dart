/// Canonical-key utilities for the Unscramble game.
///
/// The canonical key of a word is its lowercase alphabet letters sorted
/// alphabetically. Words that are anagrams of each other share the same key:
///
///   canonicalKey('wolf') == canonicalKey('flow') == 'flow'
///   canonicalKey('Listen') == canonicalKey('silent') == 'eilnst'
///
/// This module is intentionally dependency-free so it can be reused from
/// any layer (logic, tests, builders) without pulling Flutter in.
library;

/// Returns the canonical key for [input].
///
/// Behaviour:
///   * trims surrounding whitespace
///   * lowercases the string
///   * keeps only `a–z` characters (digits, punctuation, accents are dropped)
///   * sorts the remaining characters alphabetically
///
/// Returns an empty string when [input] contains no usable letters — callers
/// must treat an empty key as "no group" and skip it.
String canonicalKey(String input) {
  if (input.isEmpty) return '';
  final trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) return '';

  final chars = <String>[];
  for (var i = 0; i < trimmed.length; i++) {
    final code = trimmed.codeUnitAt(i);
    // 'a' = 97, 'z' = 122
    if (code >= 97 && code <= 122) {
      chars.add(trimmed[i]);
    }
  }
  if (chars.isEmpty) return '';
  chars.sort();
  return chars.join();
}

/// True when [a] and [b] are non-empty anagrams of each other.
bool isAnagram(String a, String b) {
  final keyA = canonicalKey(a);
  if (keyA.isEmpty) return false;
  return keyA == canonicalKey(b);
}
