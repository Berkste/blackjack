import 'dart:math';

import 'playing_card.dart';

/// Factory helpers for building standard 52-card decks.
abstract final class Deck {
  /// Number of cards in one standard deck.
  static const int cardsPerDeck = 52;

  /// A fresh, ordered 52-card deck.
  static List<PlayingCard> standard() => <PlayingCard>[
    for (final Suit suit in Suit.values)
      for (final Rank rank in Rank.values) PlayingCard(rank, suit),
  ];

  /// [deckCount] standard decks concatenated in order.
  static List<PlayingCard> multiple(int deckCount) {
    assert(deckCount > 0, 'A shoe needs at least one deck.');
    return <PlayingCard>[for (int i = 0; i < deckCount; i++) ...standard()];
  }

  /// A shuffled copy of [deckCount] decks. Pass a seeded [random] for
  /// reproducible shoes.
  static List<PlayingCard> shuffled(int deckCount, Random random) {
    final List<PlayingCard> cards = multiple(deckCount);
    cards.shuffle(random);
    return cards;
  }
}
