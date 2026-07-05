/// A word entry loaded from synonyms_antonyms.json.
/// JSON structure: { "word": { "word": "...", "synonyms": [...], "antonyms": [...] } }
class SynonymAntonymModel {
  final String word;
  final List<String> synonyms;
  final List<String> antonyms;

  const SynonymAntonymModel({
    required this.word,
    required this.synonyms,
    required this.antonyms,
  });

  factory SynonymAntonymModel.fromJson(Map<String, dynamic> json) {
    return SynonymAntonymModel(
      word: (json['word'] as String? ?? '').trim(),
      synonyms: (json['synonyms'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      antonyms: (json['antonyms'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}
