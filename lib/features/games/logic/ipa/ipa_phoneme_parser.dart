/// Tokenises raw IPA strings into structural atoms suitable for safe
/// transformation.
///
/// An IPA string such as `/əˈkɔɹdɪŋ/` is decomposed into:
///   [ə], [ˈ], [k], [ɔ], [ɹ], [d], [ɪ], [ŋ]
///
/// Surrounding slashes / brackets are stripped and re-applied by
/// [renderWithDelimiters]. Combining diacritics, length marks (ː) and ties
/// (‿) attach to the preceding phoneme so a transformation never separates
/// a base symbol from its modifier.
library;

/// Classification of a single token produced by [IpaPhonemeParser].
enum IpaAtomKind {
  /// A pronounceable phoneme (vowel or consonant), including any combining
  /// diacritics, length mark or tie that decorates it.
  phoneme,

  /// Primary (ˈ) or secondary (ˌ) stress mark.
  stress,

  /// Syllable boundary marker (`.`).
  syllableBreak,
}

class IpaAtom {
  final String text;
  final IpaAtomKind kind;
  const IpaAtom(this.text, this.kind);

  bool get isPhoneme => kind == IpaAtomKind.phoneme;
  bool get isStress => kind == IpaAtomKind.stress;

  @override
  String toString() => text;
}

/// Stateless parser. Safe to share across isolates.
class IpaPhonemeParser {
  const IpaPhonemeParser();

  static const String _primaryStress = '\u02C8'; // ˈ
  static const String _secondaryStress = '\u02CC'; // ˌ
  static const String _lengthMark = '\u02D0'; // ː
  static const String _tieBar = '\u203F'; // ‿
  static const String _syllableBreak = '.';
  static const Set<String> _delimiters = {'/', '[', ']'};

  /// Returns the inner content of [raw] (slashes / brackets stripped) along
  /// with the leading and trailing delimiter characters that were removed,
  /// so [renderWithDelimiters] can reattach them losslessly.
  ({String leading, String inner, String trailing}) stripDelimiters(
      String raw) {
    var leading = '';
    var trailing = '';
    var inner = raw;
    while (inner.isNotEmpty && _delimiters.contains(inner[0])) {
      leading += inner[0];
      inner = inner.substring(1);
    }
    while (inner.isNotEmpty && _delimiters.contains(inner[inner.length - 1])) {
      trailing = inner[inner.length - 1] + trailing;
      inner = inner.substring(0, inner.length - 1);
    }
    return (leading: leading, inner: inner, trailing: trailing);
  }

  /// Tokenises [raw] into atoms. Delimiters are stripped before parsing.
  List<IpaAtom> parse(String raw) {
    final stripped = stripDelimiters(raw);
    final inner = stripped.inner;
    final atoms = <IpaAtom>[];

    final runes = inner.runes.toList(growable: false);
    var i = 0;
    while (i < runes.length) {
      final ch = String.fromCharCode(runes[i]);

      if (ch == _primaryStress || ch == _secondaryStress) {
        atoms.add(IpaAtom(ch, IpaAtomKind.stress));
        i++;
        continue;
      }
      if (ch == _syllableBreak) {
        atoms.add(IpaAtom(ch, IpaAtomKind.syllableBreak));
        i++;
        continue;
      }
      if (_isWhitespace(runes[i])) {
        i++;
        continue;
      }

      // Phoneme: base + greedily consume following modifiers.
      final buf = StringBuffer(ch);
      i++;
      while (i < runes.length && _isModifier(runes[i])) {
        buf.write(String.fromCharCode(runes[i]));
        i++;
      }
      atoms.add(IpaAtom(buf.toString(), IpaAtomKind.phoneme));
    }
    return atoms;
  }

  /// Joins [atoms] back into an IPA string, re-wrapping with [leading] and
  /// [trailing] delimiters (typically `/` … `/`).
  String renderWithDelimiters(
    List<IpaAtom> atoms, {
    String leading = '/',
    String trailing = '/',
  }) {
    final inner = atoms.map((a) => a.text).join();
    return '$leading$inner$trailing';
  }

  bool _isModifier(int codeUnit) {
    // Combining diacritics block.
    if (codeUnit >= 0x0300 && codeUnit <= 0x036F) return true;
    final ch = String.fromCharCode(codeUnit);
    return ch == _lengthMark || ch == _tieBar;
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0xA0;
}
