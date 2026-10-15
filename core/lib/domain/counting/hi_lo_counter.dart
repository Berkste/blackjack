import '../models/deck.dart';
import '../models/playing_card.dart';
import 'true_count_calculator.dart';

/// A single step of a running count, used to build the answer breakdown
/// the trainer shows after a drill.
class CountStep {
  const CountStep({
    required this.card,
    required this.value,
    required this.runningTotal,
  });

  final PlayingCard card;

  /// Hi-Lo tag contributed by [card].
  final int value;

  /// Running count *after* [card] was counted.
  final int runningTotal;

  /// Signed tag, e.g. `+1`.
  String get signedValue => value > 0 ? '+$value' : '$value';
}

/// The Hi-Lo counting engine.
///
/// Holds a running count plus enough shoe context to derive a true count.
/// It knows nothing about widgets and is fully unit-testable.
class HiLoCounter {
  HiLoCounter({int deckCount = 6, int cardsSeen = 0})
    : assert(deckCount > 0, 'A shoe needs at least one deck.'),
      _deckCount = deckCount {
    _cardsSeen = cardsSeen;
  }

  int _deckCount;
  int _runningCount = 0;
  int _cardsSeen = 0;
  final List<CountStep> _history = <CountStep>[];

  /// Decks in the shoe being counted.
  int get deckCount => _deckCount;

  /// Current running count.
  int get runningCount => _runningCount;

  /// How many cards have been counted since the last [reset].
  int get cardsSeen => _cardsSeen;

  /// Total cards in the shoe.
  int get totalCards => _deckCount * Deck.cardsPerDeck;

  /// Cards not yet seen.
  int get cardsRemaining => (totalCards - _cardsSeen).clamp(0, totalCards);

  /// Exact decks remaining, derived from cards seen.
  double get decksRemaining => cardsRemaining / Deck.cardsPerDeck;

  /// Decks remaining snapped to the nearest half deck — what a counter at the
  /// table would actually estimate.
  double get estimatedDecksRemaining =>
      TrueCountCalculator.nearestHalfDeck(decksRemaining);

  /// True count from the exact decks remaining, truncated toward zero.
  double get trueCount =>
      TrueCountCalculator.compute(_runningCount, decksRemaining);

  /// Unrounded true count, useful for charts and index comparisons.
  double get rawTrueCount =>
      TrueCountCalculator.raw(_runningCount, decksRemaining);

  /// Step-by-step record of the cards counted so far.
  List<CountStep> get history => List<CountStep>.unmodifiable(_history);

  /// Counts one card into the running count.
  int addCard(PlayingCard card) {
    _runningCount += card.hiLoValue;
    _cardsSeen++;
    _history.add(
      CountStep(card: card, value: card.hiLoValue, runningTotal: _runningCount),
    );
    return _runningCount;
  }

  /// Counts a batch of cards.
  int addCards(Iterable<PlayingCard> cards) {
    for (final PlayingCard card in cards) {
      addCard(card);
    }
    return _runningCount;
  }

  /// Undoes the most recent [addCard]. Returns the card removed, or `null`
  /// when nothing has been counted yet.
  PlayingCard? removeLastCard() {
    if (_history.isEmpty) return null;
    final CountStep step = _history.removeLast();
    _runningCount -= step.value;
    _cardsSeen--;
    return step.card;
  }

  /// Clears the running count and history. Pass [deckCount] to also switch to
  /// a differently sized shoe.
  void reset({int? deckCount}) {
    if (deckCount != null) {
      assert(deckCount > 0, 'A shoe needs at least one deck.');
      _deckCount = deckCount;
    }
    _runningCount = 0;
    _cardsSeen = 0;
    _history.clear();
  }

  /// Overrides how many cards have been dealt, for when the shoe is the
  /// source of truth rather than the counter.
  void syncCardsSeen(int cardsSeen) {
    _cardsSeen = cardsSeen.clamp(0, totalCards);
  }

  /// Running count of an arbitrary card sequence, without touching state.
  static int countOf(Iterable<PlayingCard> cards) =>
      cards.fold<int>(0, (int sum, PlayingCard c) => sum + c.hiLoValue);

  /// Builds a breakdown for [cards] starting from [startingCount].
  static List<CountStep> breakdown(
    Iterable<PlayingCard> cards, {
    int startingCount = 0,
  }) {
    int total = startingCount;
    return <CountStep>[
      for (final PlayingCard card in cards)
        CountStep(
          card: card,
          value: card.hiLoValue,
          runningTotal: total += card.hiLoValue,
        ),
    ];
  }
}
