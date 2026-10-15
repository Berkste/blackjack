import 'package:blackjack_core/domain/blackjack/basic_strategy.dart';
import 'package:blackjack_core/domain/blackjack/blackjack_rules.dart';
import 'package:blackjack_core/domain/blackjack/count_deviations.dart';
import 'package:blackjack_core/domain/blackjack/hand.dart';
import 'package:blackjack_core/domain/models/playing_card.dart';
import 'package:test/test.dart';

const BlackjackRules s17 = BlackjackRules();
const BlackjackRules h17 = BlackjackRules(dealerHitsSoft17: true);

Hand handOf(List<Rank> ranks) => Hand(
  cards: <PlayingCard>[
    for (final Rank rank in ranks) PlayingCard(rank, Suit.clubs),
  ],
  bet: 10,
);

StrategyAction play(
  List<Rank> ranks,
  Rank upcard, {
  BlackjackRules rules = s17,
  bool canDouble = true,
  bool canSplit = true,
  bool canSurrender = true,
}) => BasicStrategyEngine.decide(
  hand: handOf(ranks),
  dealerUpcard: upcard,
  rules: rules,
  canDouble: canDouble,
  canSplit: canSplit,
  canSurrender: canSurrender,
).action;

void main() {
  group('hard totals', () {
    test('always hit eight or less', () {
      for (final Rank up in <Rank>[Rank.two, Rank.six, Rank.ten, Rank.ace]) {
        expect(play(<Rank>[Rank.five, Rank.three], up), StrategyAction.hit);
      }
    });

    test('nine doubles only against 3 through 6', () {
      expect(play(<Rank>[Rank.five, Rank.four], Rank.two), StrategyAction.hit);
      for (final Rank up in <Rank>[
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
      ]) {
        expect(
          play(<Rank>[Rank.five, Rank.four], up),
          StrategyAction.doubleDown,
          reason: 'nine vs ${up.label}',
        );
      }
      expect(
        play(<Rank>[Rank.five, Rank.four], Rank.seven),
        StrategyAction.hit,
      );
    });

    test('ten doubles against everything but a ten or an ace', () {
      expect(
        play(<Rank>[Rank.six, Rank.four], Rank.nine),
        StrategyAction.doubleDown,
      );
      expect(play(<Rank>[Rank.six, Rank.four], Rank.king), StrategyAction.hit);
      expect(play(<Rank>[Rank.six, Rank.four], Rank.ace), StrategyAction.hit);
    });

    test('eleven doubles against everything but an ace under S17', () {
      expect(
        play(<Rank>[Rank.six, Rank.five], Rank.king),
        StrategyAction.doubleDown,
      );
      expect(play(<Rank>[Rank.six, Rank.five], Rank.ace), StrategyAction.hit);
    });

    test('eleven doubles against an ace under H17', () {
      expect(
        play(<Rank>[Rank.six, Rank.five], Rank.ace, rules: h17),
        StrategyAction.doubleDown,
      );
    });

    test('twelve stands only against 4, 5 and 6', () {
      expect(play(<Rank>[Rank.ten, Rank.two], Rank.two), StrategyAction.hit);
      expect(play(<Rank>[Rank.ten, Rank.two], Rank.three), StrategyAction.hit);
      expect(play(<Rank>[Rank.ten, Rank.two], Rank.four), StrategyAction.stand);
      expect(play(<Rank>[Rank.ten, Rank.two], Rank.six), StrategyAction.stand);
      expect(play(<Rank>[Rank.ten, Rank.two], Rank.seven), StrategyAction.hit);
    });

    test('thirteen through sixteen stand against a weak dealer', () {
      for (final int total in <int>[13, 14, 15, 16]) {
        final List<Rank> cards = <Rank>[
          Rank.ten,
          Rank.values.firstWhere((Rank r) => r.highValue == total - 10),
        ];
        expect(play(cards, Rank.six), StrategyAction.stand, reason: '$total');
        expect(play(cards, Rank.seven), StrategyAction.hit, reason: '$total');
      }
    });

    test('sixteen surrenders against 9, 10 and an ace', () {
      for (final Rank up in <Rank>[Rank.nine, Rank.king, Rank.ace]) {
        expect(
          play(<Rank>[Rank.ten, Rank.six], up),
          StrategyAction.surrender,
          reason: '16 vs ${up.label}',
        );
      }
    });

    test('sixteen hits against a ten when surrender is off', () {
      expect(
        play(<Rank>[Rank.ten, Rank.six], Rank.king, canSurrender: false),
        StrategyAction.hit,
      );
      expect(
        play(
          <Rank>[Rank.ten, Rank.six],
          Rank.king,
          rules: const BlackjackRules(surrenderAllowed: false),
        ),
        StrategyAction.hit,
      );
    });

    test('fifteen surrenders against a ten only', () {
      expect(
        play(<Rank>[Rank.ten, Rank.five], Rank.king),
        StrategyAction.surrender,
      );
      expect(play(<Rank>[Rank.ten, Rank.five], Rank.nine), StrategyAction.hit);
      expect(play(<Rank>[Rank.ten, Rank.five], Rank.ace), StrategyAction.hit);
    });

    test('seventeen and up always stand', () {
      for (final Rank up in Rank.values) {
        expect(
          play(<Rank>[Rank.ten, Rank.seven], up),
          StrategyAction.stand,
          reason: '17 vs ${up.label}',
        );
      }
    });

    test('doubling falls back to hitting when the table forbids it', () {
      expect(
        play(<Rank>[Rank.six, Rank.five], Rank.six, canDouble: false),
        StrategyAction.hit,
      );
    });
  });

  group('soft totals', () {
    test('soft 13 and 14 double against 5 and 6 only', () {
      expect(
        play(<Rank>[Rank.ace, Rank.two], Rank.five),
        StrategyAction.doubleDown,
      );
      expect(play(<Rank>[Rank.ace, Rank.two], Rank.four), StrategyAction.hit);
      expect(
        play(<Rank>[Rank.ace, Rank.three], Rank.six),
        StrategyAction.doubleDown,
      );
    });

    test('soft 17 doubles against 3 through 6', () {
      expect(
        play(<Rank>[Rank.ace, Rank.six], Rank.three),
        StrategyAction.doubleDown,
      );
      expect(play(<Rank>[Rank.ace, Rank.six], Rank.two), StrategyAction.hit);
      expect(play(<Rank>[Rank.ace, Rank.six], Rank.seven), StrategyAction.hit);
    });

    test('soft 18 stands against 7 and 8 but hits against 9 and up', () {
      expect(
        play(<Rank>[Rank.ace, Rank.seven], Rank.seven),
        StrategyAction.stand,
      );
      expect(
        play(<Rank>[Rank.ace, Rank.seven], Rank.eight),
        StrategyAction.stand,
      );
      expect(play(<Rank>[Rank.ace, Rank.seven], Rank.nine), StrategyAction.hit);
    });

    test('soft 18 doubles against a weak dealer, standing if it cannot', () {
      expect(
        play(<Rank>[Rank.ace, Rank.seven], Rank.four),
        StrategyAction.doubleDown,
      );
      expect(
        play(<Rank>[Rank.ace, Rank.seven], Rank.four, canDouble: false),
        StrategyAction.stand,
      );
    });

    test('soft 19 stands under S17 and doubles against a six under H17', () {
      expect(
        play(<Rank>[Rank.ace, Rank.eight], Rank.six),
        StrategyAction.stand,
      );
      expect(
        play(<Rank>[Rank.ace, Rank.eight], Rank.six, rules: h17),
        StrategyAction.doubleDown,
      );
    });

    test('soft 20 always stands', () {
      for (final Rank up in Rank.values) {
        expect(play(<Rank>[Rank.ace, Rank.nine], up), StrategyAction.stand);
      }
    });
  });

  group('pairs', () {
    test('always split aces and eights', () {
      for (final Rank up in Rank.values) {
        expect(
          play(<Rank>[Rank.ace, Rank.ace], up),
          StrategyAction.split,
          reason: 'A,A vs ${up.label}',
        );
      }
      for (final Rank up in <Rank>[Rank.two, Rank.seven, Rank.king]) {
        expect(play(<Rank>[Rank.eight, Rank.eight], up), StrategyAction.split);
      }
    });

    test('never split tens or fives', () {
      expect(play(<Rank>[Rank.ten, Rank.ten], Rank.six), StrategyAction.stand);
      expect(
        play(<Rank>[Rank.five, Rank.five], Rank.six),
        StrategyAction.doubleDown,
      );
    });

    test('nines split except against 7, 10 and an ace', () {
      expect(
        play(<Rank>[Rank.nine, Rank.nine], Rank.six),
        StrategyAction.split,
      );
      expect(
        play(<Rank>[Rank.nine, Rank.nine], Rank.seven),
        StrategyAction.stand,
      );
      expect(
        play(<Rank>[Rank.nine, Rank.nine], Rank.nine),
        StrategyAction.split,
      );
      expect(
        play(<Rank>[Rank.nine, Rank.nine], Rank.king),
        StrategyAction.stand,
      );
      expect(
        play(<Rank>[Rank.nine, Rank.nine], Rank.ace),
        StrategyAction.stand,
      );
    });

    test('sevens split against 2 through 7 and hit after', () {
      expect(
        play(<Rank>[Rank.seven, Rank.seven], Rank.seven),
        StrategyAction.split,
      );
      expect(
        play(<Rank>[Rank.seven, Rank.seven], Rank.eight),
        StrategyAction.hit,
      );
    });

    test('twos and threes need DAS against a deuce', () {
      expect(play(<Rank>[Rank.two, Rank.two], Rank.two), StrategyAction.split);
      expect(
        play(
          <Rank>[Rank.two, Rank.two],
          Rank.two,
          rules: const BlackjackRules(doubleAfterSplit: false),
        ),
        StrategyAction.hit,
      );
    });

    test('fours split only against 5 and 6, and only with DAS', () {
      expect(
        play(<Rank>[Rank.four, Rank.four], Rank.five),
        StrategyAction.split,
      );
      expect(play(<Rank>[Rank.four, Rank.four], Rank.four), StrategyAction.hit);
      expect(
        play(
          <Rank>[Rank.four, Rank.four],
          Rank.five,
          rules: const BlackjackRules(doubleAfterSplit: false),
        ),
        StrategyAction.hit,
      );
    });

    test('a pair falls back to its total when splitting is unavailable', () {
      expect(
        play(<Rank>[Rank.eight, Rank.eight], Rank.six, canSplit: false),
        StrategyAction.stand,
      );
      expect(
        play(<Rank>[Rank.eight, Rank.eight], Rank.nine, canSplit: false),
        StrategyAction.surrender,
      );
    });

    test('a ten-jack pair is played as twenty, not split', () {
      expect(play(<Rank>[Rank.ten, Rank.jack], Rank.six), StrategyAction.stand);
    });
  });

  group('chart shape', () {
    test('every section has a full grid of cells', () {
      for (final StrategySection section in StrategySection.values) {
        final List<StrategyChartRow> rows = BasicStrategyEngine.chartRows(
          section,
          s17,
        );
        expect(rows, isNotEmpty, reason: section.label);
        for (final StrategyChartRow row in rows) {
          expect(
            row.cells,
            hasLength(BasicStrategyEngine.dealerUpcards.length),
            reason: '${section.label} row ${row.label}',
          );
        }
      }
    });

    test('upcard labels render an ace as A', () {
      expect(BasicStrategyEngine.upcardLabel(11), 'A');
      expect(BasicStrategyEngine.upcardLabel(10), '10');
    });

    test('upcard values treat every face card as ten', () {
      expect(BasicStrategyEngine.upcardValue(Rank.king), 10);
      expect(BasicStrategyEngine.upcardValue(Rank.ace), 11);
      expect(BasicStrategyEngine.upcardValue(Rank.seven), 7);
    });

    test('every decision carries an explanation', () {
      final StrategyDecision decision = BasicStrategyEngine.decide(
        hand: handOf(<Rank>[Rank.ten, Rank.six]),
        dealerUpcard: Rank.king,
        rules: s17,
      );
      expect(decision.explanation, isNotEmpty);
      expect(decision.cell, StrategyCell.surrenderElseHit);
    });

    test('a downgraded decision is flagged', () {
      final StrategyDecision decision = BasicStrategyEngine.decide(
        hand: handOf(<Rank>[Rank.six, Rank.five]),
        dealerUpcard: Rank.six,
        rules: s17,
        canDouble: false,
      );
      expect(decision.wasDowngraded, isTrue);
      expect(decision.action, StrategyAction.hit);
    });
  });

  group('insurance and deviations', () {
    test('insurance is correct only from a true count of +3', () {
      expect(BasicStrategyEngine.shouldTakeInsurance(2.9), isFalse);
      expect(BasicStrategyEngine.shouldTakeInsurance(3), isTrue);
      expect(BasicStrategyEngine.shouldTakeInsurance(-1), isFalse);
    });

    test('16 vs 10 flips to standing at a true count of zero', () {
      expect(
        CountDeviations.activeFor(
          playerTotal: 16,
          dealerUpcard: 10,
          trueCount: -1,
        ),
        isNull,
      );
      final CountDeviation? applied = CountDeviations.activeFor(
        playerTotal: 16,
        dealerUpcard: 10,
        trueCount: 0,
      );
      expect(applied, isNotNull);
      expect(applied!.deviationAction, StrategyAction.stand);
    });

    test('12 vs 4 flips to hitting only at zero or below', () {
      expect(
        CountDeviations.activeFor(
          playerTotal: 12,
          dealerUpcard: 4,
          trueCount: 1,
        ),
        isNull,
      );
      expect(
        CountDeviations.activeFor(
          playerTotal: 12,
          dealerUpcard: 4,
          trueCount: 0,
        )?.deviationAction,
        StrategyAction.hit,
      );
    });

    test('the Illustrious 18 has eighteen entries with unique ids', () {
      expect(CountDeviations.all, hasLength(18));
      expect(
        CountDeviations.all.map((CountDeviation d) => d.id).toSet(),
        hasLength(18),
      );
    });

    test('every deviation explains itself and shows its index', () {
      for (final CountDeviation deviation in CountDeviations.all) {
        expect(deviation.explanation, isNotEmpty, reason: deviation.id);
        expect(deviation.indexLabel, contains('TC'));
        expect(deviation.title, isNotEmpty);
      }
    });

    test('an unlisted situation has no deviation', () {
      expect(CountDeviations.forTotal(20, 6), isNull);
    });

    test('the core four begin with insurance', () {
      expect(CountDeviations.coreFour.first.isInsurance, isTrue);
      expect(CountDeviations.coreFour, hasLength(4));
    });
  });
}
