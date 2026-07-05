import 'dart:math';

import 'ipa_difficulty.dart';
import 'ipa_phoneme_parser.dart';
import 'ipa_phoneme_similarity.dart';

/// Generates plausible IPA distractors derived from a single target IPA
/// string, parametrised by [IpaDifficulty].
///
/// All public methods are deterministic with respect to the injected [Random];
/// inject a seeded RNG for reproducible tests. Generation never mutates the
/// original IPA string and never returns the correct answer as a distractor.
class IpaDistractorGenerator {
  final IpaPhonemeParser _parser;
  final Random _rng;

  /// Maximum transformation attempts before giving up on a difficulty tier
  /// and falling back to easier transformations. Caps allocation in the
  /// pathological case where a very short IPA admits few mutations.
  static const int _maxAttemptsPerDistractor = 24;

  IpaDistractorGenerator({
    IpaPhonemeParser parser = const IpaPhonemeParser(),
    Random? random,
  })  : _parser = parser,
        _rng = random ?? Random();

  /// Produces up to [count] unique distractors for [correctIpa] at the
  /// requested [difficulty]. May return fewer than [count] when the source
  /// IPA admits no further unique mutations — callers must handle that.
  List<String> generate({
    required String correctIpa,
    required IpaDifficulty difficulty,
    required int count,
  }) {
    if (count <= 0) return const [];
    final delim = _parser.stripDelimiters(correctIpa);
    final atoms = _parser.parse(correctIpa);
    if (atoms.where((a) => a.isPhoneme).length < 2) return const [];

    final results = <String>{};
    final blocked = <String>{delim.inner};
    final transforms = _orderedStrategiesFor(difficulty);

    for (final strategy in transforms) {
      _fillUsing(strategy, atoms, blocked, results, count, delim);
      if (results.length >= count) break;
    }
    // Fallback: never leave the consumer short — try EASY strategies last.
    if (results.length < count && difficulty != IpaDifficulty.easy) {
      for (final strategy in _orderedStrategiesFor(IpaDifficulty.easy)) {
        _fillUsing(strategy, atoms, blocked, results, count, delim);
        if (results.length >= count) break;
      }
    }
    return results.toList(growable: false);
  }

  // ── Strategy dispatch ─────────────────────────────────────────────────────

  List<_Transform> _orderedStrategiesFor(IpaDifficulty difficulty) {
    switch (difficulty) {
      case IpaDifficulty.easy:
        return [
          _removeFinalPhoneme,
          _duplicatePhoneme,
          _addPhoneme,
          _swapAdjacentPhonemes,
        ];
      case IpaDifficulty.medium:
        return [
          _relocateStress,
          _swapNonAdjacentPhonemes,
          _shiftPhonemeAcrossSyllable,
          _swapAdjacentPhonemes,
        ];
      case IpaDifficulty.hard:
        return [
          _substituteSimilarPhoneme,
          _substituteSimilarPlusStress,
          _substituteSimilarPhoneme,
        ];
    }
  }

  void _fillUsing(
    _Transform strategy,
    List<IpaAtom> atoms,
    Set<String> blocked,
    Set<String> results,
    int count,
    ({String leading, String inner, String trailing}) delim,
  ) {
    var attempts = 0;
    while (results.length < count && attempts < _maxAttemptsPerDistractor) {
      attempts++;
      final mutated = strategy(atoms);
      if (mutated == null) return; // strategy not applicable
      final inner = mutated.map((a) => a.text).join();
      if (inner.isEmpty || blocked.contains(inner)) continue;
      blocked.add(inner);
      results.add(_parser.renderWithDelimiters(
        mutated,
        leading: delim.leading.isEmpty ? '/' : delim.leading,
        trailing: delim.trailing.isEmpty ? '/' : delim.trailing,
      ));
    }
  }

  // ── EASY transforms ──────────────────────────────────────────────────────

  List<IpaAtom>? _removeFinalPhoneme(List<IpaAtom> atoms) {
    final lastPhonemeIdx = _lastIndexWhere(atoms, (a) => a.isPhoneme);
    if (lastPhonemeIdx < 0) return null;
    final phonemeCount = atoms.where((a) => a.isPhoneme).length;
    if (phonemeCount <= 2) return null;
    final copy = List<IpaAtom>.of(atoms)..removeAt(lastPhonemeIdx);
    return copy;
  }

  List<IpaAtom>? _duplicatePhoneme(List<IpaAtom> atoms) {
    final idx = _randomIndexWhere(atoms, (a) => a.isPhoneme);
    if (idx < 0) return null;
    final copy = List<IpaAtom>.of(atoms)..insert(idx + 1, atoms[idx]);
    return copy;
  }

  /// Inserts a phoneme already present in the word at a random position,
  /// guaranteeing the inserted symbol "belongs" to the same word's sound set.
  List<IpaAtom>? _addPhoneme(List<IpaAtom> atoms) {
    final phonemes = atoms.where((a) => a.isPhoneme).toList();
    if (phonemes.isEmpty) return null;
    final extra = phonemes[_rng.nextInt(phonemes.length)];
    final pos = _rng.nextInt(atoms.length + 1);
    final copy = List<IpaAtom>.of(atoms)..insert(pos, extra);
    return copy;
  }

  List<IpaAtom>? _swapAdjacentPhonemes(List<IpaAtom> atoms) {
    final phonemeIndices = _indicesWhere(atoms, (a) => a.isPhoneme);
    if (phonemeIndices.length < 2) return null;
    final pick = _rng.nextInt(phonemeIndices.length - 1);
    final a = phonemeIndices[pick];
    final b = phonemeIndices[pick + 1];
    if (atoms[a].text == atoms[b].text) return null;
    final copy = List<IpaAtom>.of(atoms);
    final tmp = copy[a];
    copy[a] = copy[b];
    copy[b] = tmp;
    return copy;
  }

  // ── MEDIUM transforms ────────────────────────────────────────────────────

  List<IpaAtom>? _relocateStress(List<IpaAtom> atoms) {
    final stressIndices = _indicesWhere(atoms, (a) => a.isStress);
    final phonemeIndices = _indicesWhere(atoms, (a) => a.isPhoneme);
    if (phonemeIndices.length < 2) return null;
    final copy = List<IpaAtom>.of(atoms);
    final stressText = stressIndices.isNotEmpty
        ? copy[stressIndices.first].text
        : '\u02C8';
    // Remove existing stress markers.
    copy.removeWhere((a) => a.isStress);
    // Insert before a different phoneme than the original stress position.
    final phonemesAfterRemoval =
        _indicesWhere(copy, (a) => a.isPhoneme);
    if (phonemesAfterRemoval.length < 2) return null;
    final originalStressTarget = stressIndices.isNotEmpty
        ? _indexOfNextPhoneme(atoms, stressIndices.first)
        : -1;
    int target;
    var tries = 0;
    do {
      target = phonemesAfterRemoval[_rng.nextInt(phonemesAfterRemoval.length)];
      tries++;
    } while (target == originalStressTarget && tries < 6);
    copy.insert(target, IpaAtom(stressText, IpaAtomKind.stress));
    return copy;
  }

  List<IpaAtom>? _swapNonAdjacentPhonemes(List<IpaAtom> atoms) {
    final phonemeIndices = _indicesWhere(atoms, (a) => a.isPhoneme);
    if (phonemeIndices.length < 3) return null;
    final a = phonemeIndices[_rng.nextInt(phonemeIndices.length)];
    int b;
    var tries = 0;
    do {
      b = phonemeIndices[_rng.nextInt(phonemeIndices.length)];
      tries++;
    } while ((b == a || (a - b).abs() < 2 || atoms[a].text == atoms[b].text) &&
        tries < 8);
    if (b == a || atoms[a].text == atoms[b].text) return null;
    final copy = List<IpaAtom>.of(atoms);
    final tmp = copy[a];
    copy[a] = copy[b];
    copy[b] = tmp;
    return copy;
  }

  List<IpaAtom>? _shiftPhonemeAcrossSyllable(List<IpaAtom> atoms) {
    final phonemeIndices = _indicesWhere(atoms, (a) => a.isPhoneme);
    if (phonemeIndices.length < 3) return null;
    final fromIdx = phonemeIndices[_rng.nextInt(phonemeIndices.length)];
    final atom = atoms[fromIdx];
    final copy = List<IpaAtom>.of(atoms)..removeAt(fromIdx);
    final targets = _indicesWhere(copy, (a) => a.isPhoneme);
    if (targets.isEmpty) return null;
    final to = targets[_rng.nextInt(targets.length)];
    copy.insert(to, atom);
    return copy;
  }

  // ── HARD transforms ──────────────────────────────────────────────────────

  List<IpaAtom>? _substituteSimilarPhoneme(List<IpaAtom> atoms) {
    final phonemeIndices = _indicesWhere(atoms, (a) => a.isPhoneme).toList()
      ..shuffle(_rng);
    for (final idx in phonemeIndices) {
      final neighbours =
          IpaPhonemeSimilarity.neighboursFor(atoms[idx].text);
      if (neighbours.isEmpty) continue;
      final replacement = neighbours[_rng.nextInt(neighbours.length)];
      if (replacement == atoms[idx].text) continue;
      final copy = List<IpaAtom>.of(atoms);
      copy[idx] = IpaAtom(replacement, IpaAtomKind.phoneme);
      return copy;
    }
    return null;
  }

  List<IpaAtom>? _substituteSimilarPlusStress(List<IpaAtom> atoms) {
    final substituted = _substituteSimilarPhoneme(atoms);
    if (substituted == null) return null;
    return _relocateStress(substituted) ?? substituted;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _lastIndexWhere(List<IpaAtom> atoms, bool Function(IpaAtom) test) {
    for (var i = atoms.length - 1; i >= 0; i--) {
      if (test(atoms[i])) return i;
    }
    return -1;
  }

  List<int> _indicesWhere(List<IpaAtom> atoms, bool Function(IpaAtom) test) {
    final out = <int>[];
    for (var i = 0; i < atoms.length; i++) {
      if (test(atoms[i])) out.add(i);
    }
    return out;
  }

  int _randomIndexWhere(List<IpaAtom> atoms, bool Function(IpaAtom) test) {
    final candidates = _indicesWhere(atoms, test);
    if (candidates.isEmpty) return -1;
    return candidates[_rng.nextInt(candidates.length)];
  }

  int _indexOfNextPhoneme(List<IpaAtom> atoms, int from) {
    for (var i = from + 1; i < atoms.length; i++) {
      if (atoms[i].isPhoneme) return i;
    }
    return -1;
  }
}

typedef _Transform = List<IpaAtom>? Function(List<IpaAtom>);
