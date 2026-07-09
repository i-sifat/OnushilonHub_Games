import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
class WhoseQuoteBuilder extends McqQuestionBuilder {
  final IGameRepository repo;

  const WhoseQuoteBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final resolved = await repo.getRandomWhoseQuoteQuestions(
      count: resolveQuestionCount(config),
    );
    return resolved
        .map((q) => McqQuestion(
              prompt: '"${q.quoteText}"',
              promptSubtitle: q.eraName.isNotEmpty
                  ? 'Who said this? \u00b7 ${q.eraName}'
                  : 'Who said this?',
              options: q.options,
              correctAnswer: q.correctAuthor,
              questionText: q.quoteText,
            ))
        .toList();
  }
}
