import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/models/game_config.dart';
import '../../../database/game_data_repository.dart';
import 'builders/definition_match_builder.dart';
import 'builders/ipa_match_builder.dart';
import 'builders/mcq_question_builder.dart';
import 'builders/meaning_chase_builder.dart';
import 'builders/speed_racing_builder.dart';
import 'builders/synonym_antonym_builders.dart';
import 'builders/true_false_builder.dart';
import 'builders/whose_quote_builder.dart';
import 'mcq_game_notifier.dart';
import 'state/mcq_game_state.dart';
import 'state/unscramble_game_state.dart';
import 'unscramble_notifier.dart';

/// Declarative builder registration (Task 3).
///
/// Adding a new MCQ-style game requires exactly two changes:
///   1. one new `*_builder.dart` file under `logic/builders/`
///   2. one line in this map
typedef _BuilderFn = McqQuestionBuilder Function(GameDataRepository);

const Map<GameType, _BuilderFn> _builderRegistry = {
  GameType.ipaMatch: IpaMatchBuilder.new,
  GameType.definitionMatch: DefinitionMatchBuilder.new,
  GameType.whoseQuote: WhoseQuoteBuilder.new,
  GameType.synonymMatch: SynonymMatchBuilder.new,
  GameType.antonymMatch: AntonymMatchBuilder.new,
  GameType.meaningChase: MeaningChaseBuilder.new,
  GameType.speedRacing: SpeedRacingBuilder.new,
  GameType.trueFalse: TrueFalseBuilder.new,
};

final questionBuilderFactoryProvider =
    Provider<McqQuestionBuilderFactory>((ref) {
  final repo = ref.watch(gameDataRepositoryProvider);
  return McqQuestionBuilderFactory({
    for (final entry in _builderRegistry.entries)
      entry.key: entry.value(repo),
  });
});

// ── Riverpod-first notifiers (Task 1 + 2) ──────────────────────────────────

/// Family-scoped MCQ notifier — one instance per active [GameConfig].
final mcqGameNotifierProvider = StateNotifierProvider.autoDispose
    .family<McqGameNotifier, McqGameState, GameConfig>((ref, config) {
  final notifier = McqGameNotifier(
    config: config,
    repo: ref.watch(gameDataRepositoryProvider),
    builderFactory: ref.watch(questionBuilderFactoryProvider),
  );
  notifier.initialize();
  return notifier;
});

/// Family-scoped Unscramble notifier — one per [GameConfig].
final unscrambleGameNotifierProvider = StateNotifierProvider.autoDispose
    .family<UnscrambleNotifier, UnscrambleGameState, GameConfig>(
        (ref, config) {
  final notifier = UnscrambleNotifier(
    config: config,
    repo: ref.watch(gameDataRepositoryProvider),
  );
  notifier.initialize();
  return notifier;
});
