/// Phoneme confusability tables used by the HARD distractor strategy.
///
/// Each entry maps a base IPA phoneme to a short ranked list of phonemes a
/// learner most plausibly confuses it with. Multi-character substitutes (e.g.
/// `oʊ`) are supported so a single base can expand into a diphthong.
class IpaPhonemeSimilarity {
  const IpaPhonemeSimilarity._();

  /// Vowel confusions (American English biased).
  static const Map<String, List<String>> vowelNeighbours = {
    'i': ['ɪ', 'e'],
    'ɪ': ['i', 'ɛ', 'ə'],
    'e': ['ɛ', 'eɪ'],
    'eɪ': ['ɛ', 'e'],
    'ɛ': ['æ', 'ɪ'],
    'æ': ['ɛ', 'ʌ'],
    'ʌ': ['ə', 'ɑ'],
    'ə': ['ʌ', 'ɪ'],
    'ɑ': ['ɔ', 'ʌ'],
    'ɔ': ['ɑ', 'oʊ'],
    'o': ['oʊ', 'ɔ'],
    'oʊ': ['ɔ', 'ʊ'],
    'ʊ': ['u', 'oʊ'],
    'u': ['ʊ', 'oʊ'],
    'aɪ': ['ɔɪ', 'eɪ'],
    'aʊ': ['oʊ', 'ɑ'],
    'ɔɪ': ['aɪ', 'oʊ'],
  };

  /// Consonant confusions covering voicing pairs and place-of-articulation
  /// neighbours common to L2 learners.
  static const Map<String, List<String>> consonantNeighbours = {
    'p': ['b', 'f'],
    'b': ['p', 'v'],
    't': ['d', 'θ'],
    'd': ['t', 'ð'],
    'k': ['g', 't'],
    'g': ['k', 'd'],
    'f': ['v', 'p'],
    'v': ['f', 'b'],
    'θ': ['t', 's'],
    'ð': ['d', 'z'],
    's': ['z', 'θ'],
    'z': ['s', 'ʒ'],
    'ʃ': ['ʒ', 's'],
    'ʒ': ['ʃ', 'z'],
    'tʃ': ['dʒ', 'ʃ'],
    'dʒ': ['tʃ', 'ʒ'],
    'm': ['n'],
    'n': ['m', 'ŋ'],
    'ŋ': ['n', 'k'],
    'l': ['ɹ', 'n'],
    'ɹ': ['l', 'w'],
    'r': ['ɹ', 'l'],
    'w': ['v', 'ɹ'],
    'j': ['i', 'ɪ'],
    'h': ['x'],
  };

  /// Returns ranked confusable substitutes for [phoneme], or an empty list
  /// when none are known. Diacritics on [phoneme] are ignored for lookup.
  static List<String> neighboursFor(String phoneme) {
    final base = _stripDiacritics(phoneme);
    return vowelNeighbours[base] ?? consonantNeighbours[base] ?? const [];
  }

  static String _stripDiacritics(String phoneme) {
    final buf = StringBuffer();
    for (final r in phoneme.runes) {
      if (r >= 0x0300 && r <= 0x036F) continue;
      if (r == 0x02D0 || r == 0x203F) continue;
      buf.writeCharCode(r);
    }
    return buf.toString();
  }
}
