/// A word + definitions loaded from word_definitions.json.
/// JSON structure: { "WORD": { "MEANINGS": [["PartOfSpeech","Definition",["Type"],[]] ...] } }
class DefinitionModel {
  final String word;
  final String partOfSpeech;
  final String definition;

  const DefinitionModel({
    required this.word,
    required this.partOfSpeech,
    required this.definition,
  });

  /// Parses from the nested MEANINGS array entry.
  /// [entry] is e.g. ["Noun", "the 1st letter...", ["Letter"], []]
  factory DefinitionModel.fromMeaning(String word, List<dynamic> entry) {
    final pos = entry.isNotEmpty ? (entry[0] as String? ?? '') : '';
    final def = entry.length > 1 ? (entry[1] as String? ?? '') : '';
    return DefinitionModel(word: word, partOfSpeech: pos, definition: def);
  }
}
