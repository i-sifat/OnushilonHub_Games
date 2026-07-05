import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

class WhoseQuoteBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const WhoseQuoteBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final resolved = await repo.getRandomWhoseQuoteQuestions(
      count: resolveQuestionCount(config),
    );
    return resolved
        .map((q) => McqQuestion(
              prompt: '"${q.quoteText}"',
              promptSubtitle:
                  q.eraName.isNotEmpty ? q.eraName : 'Who said this?',
              options: q.options,
              correctAnswer: q.correctAuthor,
              questionText: q.quoteText,
            ))
        .toList();
  }
}
