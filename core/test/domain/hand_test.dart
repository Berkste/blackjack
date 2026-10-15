import 'package:blackjack_core/domain/blackjack/hand.dart';
import 'package:blackjack_core/domain/models/playing_card.dart';
import 'package:test/test.dart';

Hand handOf(List<Rank> ranks, {bool fromSplit = false}) => Hand(
  cards: <PlayingCard>[
    for (final Rank rank in ranks) PlayingCard(rank, Suit.spades),
  ],
  fromSplit: fromSplit,
);

void main() {
  group('hand totals', () {
    test('adds pip values', () {
      expect(handOf(<Rank>[Rank.five, Rank.seven]).total, 12);
    });

    test('face cards are worth ten', () {
      expect(handOf(<Rank>[Rank.jack, Rank.queen]).total, 20);
      expect(handOf(<Rank>[Rank.king, Rank.ten]).total, 20);
    });

    test('an empty hand totals zero', () {
      expect(const Hand().total, 0);
      expect(const Hand().isEmpty, isTrue);
    });
  });

  group('ace handling', () {
    test('a lone ace with a small card is soft', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.six]);
      expect(hand.total, 17);
      expect(hand.isSoft, isTrue);
      expect(hand.hardTotal, 7);
      expect(hand.displayTotal, 'Soft 17');
    });

    test('an ace drops to one when eleven would bust', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.six, Rank.ten]);
      expect(hand.total, 17);
      expect(hand.isSoft, isFalse);
      expect(hand.isBust, isFalse);
    });

    test('two aces total twelve, counting one as eleven', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.ace]);
      expect(hand.total, 12);
      expect(hand.isSoft, isTrue);
    });

    test('three aces total thirteen', () {
      expect(handOf(<Rank>[Rank.ace, Rank.ace, Rank.ace]).total, 13);
    });

    test('four aces total fourteen and stay soft', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.ace, Rank.ace, Rank.ace]);
      expect(hand.total, 14);
      expect(hand.isSoft, isTrue);
    });

    test('a soft hand hardens once a ten arrives', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.two, Rank.king]);
      expect(hand.total, 13);
      expect(hand.isSoft, isFalse);
    });

    test('an ace-heavy hand can still reach exactly 21', () {
      final Hand hand = handOf(<Rank>[Rank.ace, Rank.ace, Rank.nine]);
      expect(hand.total, 21);
      expect(hand.isTwentyOne, isTrue);
      expect(hand.isBlackjack, isFalse);
    });
  });

  group('blackjack detection', () {
    test('ace plus ten is a natural', () {
      expect(handOf(<Rank>[Rank.ace, Rank.king]).isBlackjack, isTrue);
      expect(handOf(<Rank>[Rank.queen, Rank.ace]).isBlackjack, isTrue);
    });

    test('21 on three cards is not a natural', () {
      expect(
        handOf(<Rank>[Rank.seven, Rank.seven, Rank.seven]).isBlackjack,
        isFalse,
      );
    });

    test('21 after a split is not a natural', () {
      expect(
        handOf(<Rank>[Rank.ace, Rank.king], fromSplit: true).isBlackjack,
        isFalse,
      );
    });

    test('a natural reports itself as such', () {
      expect(handOf(<Rank>[Rank.ace, Rank.ten]).displayTotal, 'Blackjack');
    });
  });

  group('busting', () {
    test('over 21 with no usable ace is a bust', () {
      final Hand hand = handOf(<Rank>[Rank.king, Rank.queen, Rank.five]);
      expect(hand.isBust, isTrue);
      expect(hand.displayTotal, 'Bust 25');
    });

    test('exactly 21 is not a bust', () {
      expect(handOf(<Rank>[Rank.king, Rank.ace]).isBust, isFalse);
    });

    test('a bust hand is finished', () {
      final Hand hand = handOf(<Rank>[Rank.king, Rank.queen, Rank.five]);
      expect(hand.isFinished, isTrue);
    });
  });

  group('pairs', () {
    test('same rank is a pair', () {
      expect(handOf(<Rank>[Rank.eight, Rank.eight]).isPair, isTrue);
      expect(handOf(<Rank>[Rank.eight, Rank.eight]).isRankPair, isTrue);
    });

    test('two different ten-valued cards are a splittable pair', () {
      final Hand hand = handOf(<Rank>[Rank.ten, Rank.jack]);
      expect(hand.isPair, isTrue);
      expect(hand.isRankPair, isFalse);
    });

    test('three cards are never a pair', () {
      expect(
        handOf(<Rank>[Rank.eight, Rank.eight, Rank.eight]).isPair,
        isFalse,
      );
    });
  });

  group('wagers and state', () {
    test('doubling doubles the wager', () {
      const Hand hand = Hand(bet: 10);
      expect(hand.totalWager, 10);
      expect(hand.copyWith(isDoubled: true).totalWager, 20);
    });

    test('adding a card leaves the original hand untouched', () {
      final Hand original = handOf(<Rank>[Rank.five]);
      final Hand next = original.add(const PlayingCard(Rank.six, Suit.hearts));
      expect(original.cardCount, 1);
      expect(next.cardCount, 2);
      expect(next.total, 11);
    });

    test('standing and surrendering both finish a hand', () {
      expect(const Hand(isStood: true).isFinished, isTrue);
      expect(const Hand(isSurrendered: true).isFinished, isTrue);
      expect(const Hand().isFinished, isFalse);
    });

    test('outcomes report whether the hand is resolved', () {
      expect(HandOutcome.pending.isResolved, isFalse);
      expect(HandOutcome.win.isResolved, isTrue);
      expect(HandOutcome.push.isResolved, isTrue);
    });
  });
}
