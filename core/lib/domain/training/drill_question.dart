import 'dart:math';

import 'package:meta/meta.dart';

import '../counting/hi_lo_counter.dart';
import '../counting/true_count_calculator.dart';
import '../models/deck.dart';
import '../models/difficulty.dart';
import '../models/playing_card.dart';

/// One question in a drill.
///
/// Questions are data, not widgets: the generator decides what is asked and
/// what the right answer is, and the drill screen only renders it.
@immutable
class DrillQuestion {
  const DrillQuestion({
    required this.drill,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.cards = const <PlayingCard>[],
    this.startingCount = 0,
    this.runningCount,
    this.decksRemaining,
    this.totalDecks = 6,
  });

  final TrainingDrill drill;

  /// The question put to the user.
  final String prompt;

  /// Answer labels, already shuffled.
  final List<String> options;

  final int correctIndex;

  /// Why the answer is what it is, shown after answering.
  final String explanation;

  /// Cards involved, if any.
  final List<PlayingCard> cards;

  /// Running count before [cards] were dealt.
  final int startingCount;

  /// Running count supplied by the question, for true-count drills.
  final int? runningCount;

  /// Decks left, for true-count and deck-estimation drills.
  final double? decksRemaining;

  final int totalDecks;

  String get correctLabel => options[correctIndex];

  /// The Hi-Lo breakdown behind the answer, when cards were involved.
  List<CountStep> get breakdown =>
      HiLoCounter.breakdown(cards, startingCount: startingCount);

  bool isCorrect(int index) => index == correctIndex;
}

/// Builds drill questions.
///
/// Seeded so a drill can be replayed exactly in a test, and pure so the
/// question logic can be verified without pumping a widget.
class DrillGenerator {
  DrillGenerator({int? seed}) : _random = Random(seed);

  final Random _random;

  /// Deck counts a true-count or estimation question can use.
  static const List<int> shoeSizes = <int>[2, 4, 6, 8];

  PlayingCard randomCard() => PlayingCard(
    Rank.values[_random.nextInt(Rank.values.length)],
    Suit.values[_random.nextInt(Suit.values.length)],
  );

  List<PlayingCard> randomCards(int count) =>
      List<PlayingCard>.generate(count, (_) => randomCard(), growable: false);

  /// Builds the next question for [drill] at [difficulty].
  DrillQuestion next(TrainingDrill drill, Difficulty difficulty) {
    switch (drill) {
      case TrainingDrill.singleCard:
        return _singleCard();
      case TrainingDrill.runningCount:
        return _runningCount(difficulty);
      case TrainingDrill.speedCount:
        return _speedCheckpoint(difficulty);
      case TrainingDrill.trueCount:
        return _trueCount(difficulty);
      case TrainingDrill.deckEstimation:
        return _deckEstimation(difficulty);
      case TrainingDrill.fullDrill:
        return _runningCount(difficulty);
    }
  }

  DrillQuestion _singleCard() {
    final PlayingCard card = randomCard();
    const List<String> options = <String>['+1', '0', '-1'];
    final int correctIndex = switch (card.hiLoValue) {
      1 => 0,
      0 => 1,
      _ => 2,
    };
    return DrillQuestion(
      drill: TrainingDrill.singleCard,
      prompt: 'What is the Hi-Lo value?',
      options: options,
      correctIndex: correctIndex,
      cards: <PlayingCard>[card],
      explanation: _singleCardExplanation(card),
    );
  }

  static String _singleCardExplanation(PlayingCard card) {
    switch (card.hiLoGroup) {
      case HiLoGroup.low:
        return 'A ${card.rank.label.toLowerCase()} is a low card. Everything '
            'from two through six counts +1.';
      case HiLoGroup.neutral:
        return 'A ${card.rank.label.toLowerCase()} is neutral. Sevens, eights '
            'and nines count 0 and you skip straight past them.';
      case HiLoGroup.high:
        return 'A ${card.rank.label.toLowerCase()} is a high card. Tens, face '
            'cards and aces all count -1.';
    }
  }

  DrillQuestion _runningCount(Difficulty difficulty) {
    final List<PlayingCard> cards = randomCards(difficulty.sequenceLength);
    final int answer = HiLoCounter.countOf(cards);
    final List<int> values = _numericOptions(answer, spread: 2);
    return DrillQuestion(
      drill: TrainingDrill.runningCount,
      prompt: 'What is the final running count?',
      options: values.map(_signed).toList(growable: false),
      correctIndex: values.indexOf(answer),
      cards: cards,
      explanation:
          '${cards.length} cards, and the tags add up to ${_signed(answer)}.',
    );
  }

  DrillQuestion _speedCheckpoint(Difficulty difficulty) {
    // The view deals cards itself; this seeds the checkpoint question.
    final List<PlayingCard> cards = randomCards(difficulty.sequenceLength);
    final int answer = HiLoCounter.countOf(cards);
    final List<int> values = _numericOptions(answer, spread: 2);
    return DrillQuestion(
      drill: TrainingDrill.speedCount,
      prompt: 'Current running count?',
      options: values.map(_signed).toList(growable: false),
      correctIndex: values.indexOf(answer),
      cards: cards,
      explanation:
          'The tags on those ${cards.length} cards total '
          '${_signed(answer)}.',
    );
  }

  DrillQuestion _trueCount(Difficulty difficulty) {
    final int totalDecks = shoeSizes[_random.nextInt(shoeSizes.length)];
    // Whole- or half-deck depths, weighted toward whole decks early on.
    final bool halfDeck =
        difficulty.index >= Difficulty.advanced.index && _random.nextBool();
    final double decks = halfDeck
        ? (_random.nextInt(totalDecks * 2 - 1) + 1) / 2
        : (_random.nextInt(totalDecks) + 1).toDouble();

    // Pick a running count that divides cleanly, so the drill teaches the
    // division rather than the rounding.
    final int trueTarget = _random.nextInt(9) - 4;
    final int running = (trueTarget * decks).round();
    final double answer = TrueCountCalculator.compute(
      running,
      decks,
    ).toDouble();

    final List<double> values = _doubleOptions(answer);
    return DrillQuestion(
      drill: TrainingDrill.trueCount,
      prompt: 'What is the true count?',
      options: values.map(TrueCountCalculator.format).toList(growable: false),
      correctIndex: values.indexOf(answer),
      runningCount: running,
      decksRemaining: decks,
      totalDecks: totalDecks,
      explanation:
          '${_signed(running)} ÷ ${decks.toStringAsFixed(1)} = '
          '${TrueCountCalculator.format(answer)}.',
    );
  }

  DrillQuestion _deckEstimation(Difficulty difficulty) {
    final int totalDecks = _random.nextBool() ? 6 : 8;
    final bool halfDecks = difficulty.index >= Difficulty.advanced.index;
    final double decks = halfDecks
        ? (_random.nextInt((totalDecks - 1) * 2) + 2) / 2
        : (_random.nextInt(totalDecks - 1) + 1).toDouble();

    final List<double> values = _deckOptions(decks, totalDecks, halfDecks);
    return DrillQuestion(
      drill: TrainingDrill.deckEstimation,
      prompt: 'Approximately how many decks remain?',
      options: values
          .map((double v) => v.toStringAsFixed(halfDecks ? 1 : 0))
          .toList(growable: false),
      correctIndex: values.indexOf(decks),
      decksRemaining: decks,
      totalDecks: totalDecks,
      explanation:
          '${(totalDecks - decks).toStringAsFixed(1)} of $totalDecks decks '
          'have been dealt, leaving ${decks.toStringAsFixed(1)}.',
    );
  }

  /// Four integer options around [answer], shuffled, always including it.
  List<int> _numericOptions(int answer, {int spread = 2}) {
    final Set<int> values = <int>{answer};
    final List<int> offsets = <int>[
      1,
      -1,
      2,
      -2,
      spread + 1,
      -(spread + 1),
      4,
      -4,
    ]..shuffle(_random);
    for (final int offset in offsets) {
      if (values.length == 4) break;
      values.add(answer + offset);
    }
    final List<int> list = values.toList()..shuffle(_random);
    return list;
  }

  List<double> _doubleOptions(double answer) {
    final Set<double> values = <double>{answer};
    final List<double> offsets = <double>[1, -1, 2, -2, 3, -3]
      ..shuffle(_random);
    for (final double offset in offsets) {
      if (values.length == 4) break;
      values.add(answer + offset);
    }
    final List<double> list = values.toList()..shuffle(_random);
    return list;
  }

  List<double> _deckOptions(double answer, int totalDecks, bool halfDecks) {
    final double step = halfDecks ? 0.5 : 1;
    final Set<double> values = <double>{answer};
    for (int i = 1; values.length < 4 && i < 8; i++) {
      final double up = answer + step * i;
      final double down = answer - step * i;
      if (down >= step) values.add(down);
      if (values.length < 4 && up <= totalDecks) values.add(up);
    }
    final List<double> list = values.toList()..sort();
    return list;
  }

  static String _signed(int value) => value > 0 ? '+$value' : '$value';

  /// Cards remaining, expressed as decks, for a shoe that has dealt [dealt].
  static double decksLeft(int totalDecks, int dealt) =>
      (totalDecks * Deck.cardsPerDeck - dealt) / Deck.cardsPerDeck;
}
