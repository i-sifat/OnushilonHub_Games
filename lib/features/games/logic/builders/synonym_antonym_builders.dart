import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// Builds synonym OR antonym questions. Discriminated by [isAntonym] so the
/// same code path produces both, with no duplication.
class SynonymAntonymBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  final bool isAntonym;

  const SynonymAntonymBuilder(this.repo, {required this.isAntonym});

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);
    final resolved = isAntonym
        ? await repo.getRandomAntonymQuestions(count: count)
        : await repo.getRandomSynonymQuestions(count: count);
    final rel = isAntonym ? 'antonym' : 'synonym';
    final wordIdMap = await repo
        .getWordIdsByLowercase(resolved.map((q) => q.word).toList());

    return resolved
        .map((q) => McqQuestion(
              prompt: q.word,
              promptSubtitle: 'Choose the $rel',
              options: q.options,
              correctAnswer: q.correctAnswer,
              allCorrectAnswers: q.allCorrect,
              questionText: 'What is a $rel of "${q.word}"?',
              wordId: wordIdMap[q.word.toLowerCase()],
            ))
        .toList();
  }
}

class SynonymMatchBuilder extends SynonymAntonymBuilder {
  const SynonymMatchBuilder(super.repo) : super(isAntonym: false);
}

class AntonymMatchBuilder extends SynonymAntonymBuilder {
  const AntonymMatchBuilder(super.repo) : super(isAntonym: true);
}
