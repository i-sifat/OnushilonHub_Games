// ── Legacy flat QuoteModel (used by old whose_quote seeded from quotes.json) ─

class QuoteModel {
  final int? id;
  final String quote;
  final String sourceName;
  final String sourceType;
  final int difficulty;
  final String era;
  final String category;

  const QuoteModel({
    this.id,
    required this.quote,
    required this.sourceName,
    required this.sourceType,
    required this.difficulty,
    required this.era,
    required this.category,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      id: json['id'] as int?,
      quote: json['quote'] as String,
      sourceName: json['source_name'] as String,
      sourceType: json['source_type'] as String,
      difficulty: json['difficulty'] as int,
      era: json['era'] as String,
      category: json['category'] as String,
    );
  }

  factory QuoteModel.fromDb(Map<String, dynamic> map) {
    return QuoteModel(
      id: map['id'] as int?,
      quote: map['quote'] as String,
      sourceName: map['source_name'] as String,
      sourceType: map['source_type'] as String,
      difficulty: map['difficulty'] as int,
      era: map['era'] as String,
      category: map['category'] as String,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'quote': quote,
      'source_name': sourceName,
      'source_type': sourceType,
      'difficulty': difficulty,
      'era': era,
      'category': category,
    };
  }

  bool get isBookQuote =>
      sourceType == 'book' || sourceType == 'novel' || sourceType == 'play';
  bool get isPersonQuote => !isBookQuote;

  String get questionPrompt {
    if (isBookQuote) return 'Which book contains this quote?';
    return 'Who said this quote?';
  }
}

// ── Rich quote models from new dataset ───────────────────────────────────────

/// A quote entry from quotes.json (references author_id, work_id, era_id).
class RichQuoteModel {
  final int id;
  final String text;
  final int authorId;
  final int? workId;
  final int eraId;
  final List<int> movementIds;
  final List<String> tags;

  const RichQuoteModel({
    required this.id,
    required this.text,
    required this.authorId,
    this.workId,
    required this.eraId,
    required this.movementIds,
    required this.tags,
  });

  factory RichQuoteModel.fromJson(Map<String, dynamic> json) {
    // author_id and era_id must not be null — entries with missing IDs are
    // filtered out in _ensureRichQuotesLoaded so they never reach fromJson,
    // but we guard here defensively to avoid a hard cast crash.
    final authorId = json['author_id'] as int?;
    final eraId = json['era_id'] as int?;
    if (authorId == null || eraId == null) {
      throw FormatException(
        'Quote id=${json['id']} has null author_id or era_id — skipped',
      );
    }
    return RichQuoteModel(
      id: json['id'] as int,
      text: json['text'] as String,
      authorId: authorId,
      workId: json['work_id'] as int?,
      eraId: eraId,
      movementIds: (json['movement_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// An author entry from quote_authors.json.
class QuoteAuthorModel {
  final int id;
  final String name;
  final int? birthYear;
  final int? deathYear;
  final String nationality;
  final int eraId;
  final String description;
  final String gender;
  final List<String> tags;

  const QuoteAuthorModel({
    required this.id,
    required this.name,
    this.birthYear,
    this.deathYear,
    required this.nationality,
    required this.eraId,
    required this.description,
    required this.gender,
    required this.tags,
  });

  factory QuoteAuthorModel.fromJson(Map<String, dynamic> json) {
    // FIX: Fields like nationality, description, gender can be null in the
    // JSON data, causing a hard 'type Null is not a subtype of String' crash.
    // Use null-aware casts with empty-string fallbacks for all String fields.
    return QuoteAuthorModel(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? 'Unknown',
      birthYear: json['birth_year'] as int?,
      deathYear: json['death_year'] as int?,
      nationality: (json['nationality'] as String?) ?? '',
      eraId: json['era_id'] as int,
      description: (json['description'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// An era entry from quote_eras.json.
class QuoteEraModel {
  final int id;
  final String name;
  final String slug;
  final int startYear;
  final int? endYear;
  final String description;
  final List<String> keyFeatures;
  final List<String> tags;

  const QuoteEraModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.startYear,
    this.endYear,
    required this.description,
    required this.keyFeatures,
    required this.tags,
  });

  factory QuoteEraModel.fromJson(Map<String, dynamic> json) {
    // FIX: Apply null-safe casts for defensive parsing.
    return QuoteEraModel(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? 'Unknown Era',
      slug: (json['slug'] as String?) ?? '',
      startYear: json['start_year'] as int,
      endYear: json['end_year'] as int?,
      description: (json['description'] as String?) ?? '',
      keyFeatures: (json['key_features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// A quiz question entry from quote_quiz_questions.json.
class QuoteQuizQuestionModel {
  final int id;
  final String question;
  final String correctAnswer;
  final List<String> wrongAnswers;
  final String difficulty;
  final String type;
  final int? eraId;
  final int? authorId;
  final int? workId;
  final List<String> tags;

  const QuoteQuizQuestionModel({
    required this.id,
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswers,
    required this.difficulty,
    required this.type,
    this.eraId,
    this.authorId,
    this.workId,
    required this.tags,
  });

  factory QuoteQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuoteQuizQuestionModel(
      id: json['id'] as int,
      question: json['question'] as String,
      correctAnswer: json['correct_answer'] as String,
      wrongAnswers: (json['wrong_answers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      difficulty: json['difficulty'] as String,
      type: json['type'] as String,
      eraId: json['era_id'] as int?,
      authorId: json['author_id'] as int?,
      workId: json['work_id'] as int?,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  /// Returns all 4 options in a shuffleable list.
  List<String> get allAnswers => [correctAnswer, ...wrongAnswers];
}
