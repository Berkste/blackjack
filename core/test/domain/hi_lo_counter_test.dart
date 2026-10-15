import 'package:blackjack_core/domain/counting/hi_lo_counter.dart';
import 'package:blackjack_core/domain/models/deck.dart';
import 'package:blackjack_core/domain/models/playing_card.dart';
import 'package:test/test.dart';

PlayingCard card(Rank rank) => PlayingCard(rank, Suit.spades);

void main() {
  group('Hi-Lo card values', () {
    test('2 through 6 tag as +1', () {
      for (final Rank rank in <Rank>[
        Rank.two,
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]) {
        expect(rank.hiLoValue, 1, reason: '${rank.label} should be +1');
      }
    });

    test('7 through 9 tag as 0', () {
      for (final Rank rank in <Rank>[Rank.seven, Rank.eight, Rank.nine]) {
        expect(rank.hiLoValue, 0, reason: '${rank.label} should be 0');
      }
    });

    test('10, J, Q, K and A tag as -1', () {
      for (final Rank rank in <Rank>[
        Rank.ten,
        Rank.jack,
        Rank.queen,
        Rank.king,
        Rank.ace,
      ]) {
        expect(rank.hiLoValue, -1, reason: '${rank.label} should be -1');
      }
    });

    test('every rank has exactly one tag and the suit never matters', () {
      for (final Rank rank in Rank.values) {
        expect(rank.hiLoValue, inInclusiveRange(-1, 1));
        for (final Suit suit in Suit.values) {
          expect(PlayingCard(rank, suit).hiLoValue, rank.hiLoValue);
        }
      }
    });

    test('a full deck is count-balanced', () {
      expect(HiLoCounter.countOf(Deck.standard()), 0);
    });

    test('six decks are count-balanced', () {
      expect(HiLoCounter.countOf(Deck.multiple(6)), 0);
    });

    test('a deck holds twenty low, twelve neutral and twenty high cards', () {
      final List<PlayingCard> deck = Deck.standard();
      int low = 0;
      int neutral = 0;
      int high = 0;
      for (final PlayingCard c in deck) {
        switch (c.hiLoGroup) {
          case HiLoGroup.low:
            low++;
          case HiLoGroup.neutral:
            neutral++;
          case HiLoGroup.high:
            high++;
        }
      }
      expect(low, 20);
      expect(neutral, 12);
      expect(high, 20);
    });
  });

  group('running count', () {
    test('the worked example from the lesson totals zero', () {
      final HiLoCounter counter = HiLoCounter();
      counter.addCards(<PlayingCard>[
        card(Rank.five),
        card(Rank.king),
        card(Rank.eight),
        card(Rank.three),
        card(Rank.ace),
      ]);
      expect(counter.runningCount, 0);
      expect(counter.cardsSeen, 5);
    });

    test('accumulates card by card', () {
      final HiLoCounter counter = HiLoCounter();
      expect(counter.addCard(card(Rank.five)), 1);
      expect(counter.addCard(card(Rank.six)), 2);
      expect(counter.addCard(card(Rank.king)), 1);
      expect(counter.addCard(card(Rank.seven)), 1);
      expect(counter.addCard(card(Rank.ace)), 0);
    });

    test('goes negative when high cards come out first', () {
      final HiLoCounter counter = HiLoCounter();
      counter.addCards(<PlayingCard>[
        card(Rank.ace),
        card(Rank.king),
        card(Rank.queen),
      ]);
      expect(counter.runningCount, -3);
    });

    test('reset clears the count, history and cards seen', () {
      final HiLoCounter counter = HiLoCounter();
      counter.addCards(<PlayingCard>[card(Rank.two), card(Rank.three)]);
      counter.reset();
      expect(counter.runningCount, 0);
      expect(counter.cardsSeen, 0);
      expect(counter.history, isEmpty);
      expect(counter.decksRemaining, 6);
    });

    test('reset can switch the shoe size', () {
      final HiLoCounter counter = HiLoCounter(deckCount: 6);
      counter.reset(deckCount: 2);
      expect(counter.deckCount, 2);
      expect(counter.totalCards, 104);
    });

    test('removeLastCard undoes exactly one card', () {
      final HiLoCounter counter = HiLoCounter();
      counter.addCards(<PlayingCard>[card(Rank.five), card(Rank.king)]);
      expect(counter.runningCount, 0);
      final PlayingCard? removed = counter.removeLastCard();
      expect(removed, card(Rank.king));
      expect(counter.runningCount, 1);
      expect(counter.cardsSeen, 1);
    });

    test('removeLastCard on an empty counter returns null', () {
      expect(HiLoCounter().removeLastCard(), isNull);
    });

    test('history records the running total after each card', () {
      final HiLoCounter counter = HiLoCounter();
      counter.addCards(<PlayingCard>[
        card(Rank.five),
        card(Rank.king),
        card(Rank.six),
        card(Rank.three),
      ]);
      expect(
        counter.history.map((CountStep s) => s.runningTotal).toList(),
        <int>[1, 0, 1, 2],
      );
      expect(counter.history.first.signedValue, '+1');
      expect(counter.history[1].signedValue, '-1');
    });

    test('a static breakdown matches a live counter', () {
      final List<PlayingCard> cards = <PlayingCard>[
        card(Rank.five),
        card(Rank.king),
        card(Rank.six),
        card(Rank.three),
      ];
      final List<CountStep> steps = HiLoCounter.breakdown(cards);
      expect(steps.last.runningTotal, 2);
      expect(steps.last.runningTotal, HiLoCounter.countOf(cards));
    });
  });

  group('decks remaining', () {
    test('a fresh six-deck shoe has six decks remaining', () {
      expect(HiLoCounter(deckCount: 6).decksRemaining, 6);
    });

    test('shrinks as cards are counted', () {
      final HiLoCounter counter = HiLoCounter(deckCount: 6);
      counter.addCards(List<PlayingCard>.filled(52, card(Rank.seven)));
      expect(counter.decksRemaining, 5);
      expect(counter.cardsRemaining, 260);
    });

    test('never reports fewer than zero cards remaining', () {
      final HiLoCounter counter = HiLoCounter(deckCount: 1);
      counter.syncCardsSeen(200);
      expect(counter.cardsRemaining, 0);
      expect(counter.decksRemaining, 0);
    });

    test('estimated decks snap to the nearest half deck', () {
      final HiLoCounter counter = HiLoCounter(deckCount: 6);
      counter.syncCardsSeen(70); // 242 cards left, 4.65 decks
      expect(counter.estimatedDecksRemaining, 4.5);
    });
  });
}
