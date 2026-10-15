import 'package:blackjack_core/domain/counting/hi_lo_counter.dart';
import 'package:blackjack_core/domain/models/deck.dart';
import 'package:blackjack_core/domain/models/playing_card.dart';
import 'package:blackjack_core/domain/models/shoe.dart';
import 'package:test/test.dart';

void main() {
  group('deck construction', () {
    test('a standard deck holds 52 unique cards', () {
      final List<PlayingCard> deck = Deck.standard();
      expect(deck, hasLength(52));
      expect(deck.toSet(), hasLength(52));
    });

    test('a standard deck holds four of every rank', () {
      final List<PlayingCard> deck = Deck.standard();
      for (final Rank rank in Rank.values) {
        expect(
          deck.where((PlayingCard c) => c.rank == rank).length,
          4,
          reason: 'expected four ${rank.label}s',
        );
      }
    });

    test('multiple decks repeat each card once per deck', () {
      final List<PlayingCard> shoe = Deck.multiple(6);
      expect(shoe, hasLength(312));
      expect(
        shoe
            .where(
              (PlayingCard c) => c == const PlayingCard(Rank.ace, Suit.spades),
            )
            .length,
        6,
      );
    });
  });

  group('shoe', () {
    test('reports its own size', () {
      final Shoe shoe = Shoe(deckCount: 6, seed: 1);
      expect(shoe.totalCards, 312);
      expect(shoe.cardsRemaining, 312);
      expect(shoe.decksRemaining, 6);
      expect(shoe.cardsDealt, 0);
    });

    test('dealing depletes the shoe one card at a time', () {
      final Shoe shoe = Shoe(deckCount: 1, seed: 1);
      shoe.deal();
      expect(shoe.cardsRemaining, 51);
      expect(shoe.cardsDealt, 1);
      shoe.dealMany(10);
      expect(shoe.cardsRemaining, 41);
      expect(shoe.decksRemaining, closeTo(41 / 52, 1e-9));
    });

    test('the same seed produces the same shoe', () {
      final Shoe a = Shoe(deckCount: 2, seed: 42);
      final Shoe b = Shoe(deckCount: 2, seed: 42);
      expect(a.dealMany(20), b.dealMany(20));
    });

    test('different seeds produce different shoes', () {
      final Shoe a = Shoe(deckCount: 6, seed: 1);
      final Shoe b = Shoe(deckCount: 6, seed: 2);
      expect(a.dealMany(50), isNot(b.dealMany(50)));
    });

    test('a dealt shoe still contains a balanced count', () {
      final Shoe shoe = Shoe(deckCount: 6, seed: 7);
      final List<PlayingCard> all = shoe.dealMany(312);
      expect(HiLoCounter.countOf(all), 0);
    });

    test('the cut card sits at the penetration mark', () {
      final Shoe shoe = Shoe(deckCount: 6, penetration: 0.75, seed: 3);
      expect(shoe.cutCardIndex, 234);
      shoe.dealMany(233);
      expect(shoe.isCutCardReached, isFalse);
      shoe.deal();
      expect(shoe.isCutCardReached, isTrue);
    });

    test('an exhausted shoe throws rather than dealing nothing', () {
      final Shoe shoe = Shoe(deckCount: 1, seed: 5);
      shoe.dealMany(52);
      expect(shoe.isEmpty, isTrue);
      expect(shoe.deal, throwsStateError);
    });

    test('reshuffling refills the shoe and changes the order', () {
      final Shoe shoe = Shoe(deckCount: 2, seed: 11);
      final List<PlayingCard> firstPass = shoe.dealMany(30);
      shoe.reshuffle();
      expect(shoe.cardsRemaining, 104);
      expect(shoe.cardsDealt, 0);
      expect(shoe.shuffleNumber, 2);
      expect(shoe.dealMany(30), isNot(firstPass));
    });

    test('reshuffling is reproducible for a given seed', () {
      final Shoe a = Shoe(deckCount: 2, seed: 99)..reshuffle();
      final Shoe b = Shoe(deckCount: 2, seed: 99)..reshuffle();
      expect(a.dealMany(40), b.dealMany(40));
    });

    test('used fraction tracks how deep the shoe is', () {
      final Shoe shoe = Shoe(deckCount: 1, seed: 2);
      shoe.dealMany(26);
      expect(shoe.usedFraction, closeTo(0.5, 1e-9));
    });

    test('dealt and remaining cards partition the shoe', () {
      final Shoe shoe = Shoe(deckCount: 1, seed: 4);
      shoe.dealMany(10);
      expect(shoe.dealtCards, hasLength(10));
      expect(shoe.remainingCards, hasLength(42));
    });

    test('a stacked shoe deals exactly what it was given', () {
      final Shoe shoe = Shoe(deckCount: 1, seed: 1);
      const List<PlayingCard> stacked = <PlayingCard>[
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.king, Suit.hearts),
      ];
      shoe.stack(stacked);
      expect(shoe.deal(), stacked[0]);
      expect(shoe.deal(), stacked[1]);
      expect(shoe.isEmpty, isTrue);
    });
  });
}
