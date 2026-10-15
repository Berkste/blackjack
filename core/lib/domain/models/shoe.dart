import 'dart:math';

import 'deck.dart';
import 'playing_card.dart';

/// A multi-deck blackjack shoe with a cut card.
///
/// The shoe owns nothing but cards: it has no knowledge of the count, the
/// table or the UI. Pass a [seed] to reproduce an exact shoe in tests.
class Shoe {
  Shoe({required this.deckCount, this.penetration = 0.75, int? seed})
    : assert(deckCount > 0, 'A shoe needs at least one deck.'),
      assert(
        penetration > 0 && penetration <= 1,
        'Penetration is a fraction between 0 and 1.',
      ),
      seed = seed ?? Random().nextInt(1 << 32) {
    _reshuffle();
  }

  /// Number of 52-card decks in the shoe.
  final int deckCount;

  /// Fraction of the shoe dealt before the cut card is reached.
  final double penetration;

  /// Seed used to shuffle. Reusing it reproduces the same shoe.
  final int seed;

  late List<PlayingCard> _cards;
  int _cursor = 0;
  int _shuffleNumber = 0;

  /// Total cards in a full shoe.
  int get totalCards => deckCount * Deck.cardsPerDeck;

  /// Cards not yet dealt.
  int get cardsRemaining => _cards.length - _cursor;

  /// Cards dealt since the last shuffle.
  int get cardsDealt => _cursor;

  /// How many times this shoe has been shuffled (starts at 1).
  int get shuffleNumber => _shuffleNumber;

  /// Exact decks remaining, e.g. `2.5`.
  double get decksRemaining => cardsRemaining / Deck.cardsPerDeck;

  /// Index of the cut card. Once [cardsDealt] reaches it the shoe should be
  /// reshuffled at the end of the current hand.
  int get cutCardIndex => (totalCards * penetration).round();

  /// True once the cut card has been passed.
  bool get isCutCardReached => _cursor >= cutCardIndex;

  /// True when no cards are left to deal.
  bool get isEmpty => cardsRemaining == 0;

  /// Fraction of the shoe already dealt, in `0..1`.
  double get usedFraction => totalCards == 0 ? 0 : _cursor / totalCards;

  /// The undealt cards, in the order they will come out.
  List<PlayingCard> get remainingCards =>
      List<PlayingCard>.unmodifiable(_cards.sublist(_cursor));

  /// The cards dealt so far, oldest first.
  List<PlayingCard> get dealtCards =>
      List<PlayingCard>.unmodifiable(_cards.sublist(0, _cursor));

  /// Deals the next card.
  ///
  /// Throws [StateError] when the shoe is exhausted; callers should watch
  /// [isCutCardReached] and reshuffle between hands instead.
  PlayingCard deal() {
    if (isEmpty) {
      throw StateError('Cannot deal from an exhausted shoe.');
    }
    return _cards[_cursor++];
  }

  /// Deals [count] cards at once.
  List<PlayingCard> dealMany(int count) =>
      List<PlayingCard>.generate(count, (_) => deal(), growable: false);

  /// Rebuilds and reshuffles the shoe, advancing the shuffle seed
  /// deterministically so a run stays reproducible across shuffles.
  void reshuffle() => _reshuffle();

  void _reshuffle() {
    _shuffleNumber++;
    _cards = Deck.shuffled(deckCount, Random(seed + _shuffleNumber));
    _cursor = 0;
  }

  /// Replaces the shoe contents with an exact card sequence. Intended for
  /// tests and scripted lessons.
  void stack(List<PlayingCard> cards) {
    _cards = List<PlayingCard>.of(cards);
    _cursor = 0;
  }
}
