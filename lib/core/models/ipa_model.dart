/// A word + IPA pronunciation pair loaded from the [ipa_pronunciations] table
/// in vocabulary.db. The [ipa] column may contain multiple pronunciations
/// separated by ", " — [fromEntry] extracts only the primary one.
class IpaModel {
  final String word;
  final String ipa; // primary (first) pronunciation

  const IpaModel({required this.word, required this.ipa});

  /// Constructs an [IpaModel] from a raw DB [ipa] value that may contain
  /// multiple pronunciations separated by ", " (e.g. "/ˈeɪ/, /ə/").
  /// Only the first pronunciation is kept.
  factory IpaModel.fromEntry(String word, String rawIpa) {
    // DB stores multiple pronunciations separated by ", "
    // Use "," as the split token and trim to handle both ", " and ","
    final primary = rawIpa.split(',').first.trim();
    return IpaModel(word: word, ipa: primary);
  }
}
