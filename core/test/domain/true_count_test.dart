import 'package:blackjack_core/domain/counting/true_count_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('true count arithmetic', () {
    test('the lesson example: +6 over 3 decks is +2', () {
      expect(TrueCountCalculator.compute(6, 3), 2);
    });

    test('the drill example: +8 over 2 decks is +4', () {
      expect(TrueCountCalculator.compute(8, 2), 4);
    });

    test('a negative running count gives a negative true count', () {
      expect(TrueCountCalculator.compute(-6, 2), -3);
    });

    test('a zero running count is a zero true count at any depth', () {
      for (final double decks in <double>[0.5, 1, 3, 6, 8]) {
        expect(TrueCountCalculator.compute(0, decks), 0);
      }
    });

    test('half decks divide correctly', () {
      expect(TrueCountCalculator.raw(3, 1.5), closeTo(2, 1e-9));
      expect(TrueCountCalculator.compute(3, 1.5), 2);
    });

    test('the same running count is worth more in a shallower shoe', () {
      expect(
        TrueCountCalculator.raw(6, 1) > TrueCountCalculator.raw(6, 6),
        isTrue,
      );
      expect(TrueCountCalculator.compute(6, 6), 1);
      expect(TrueCountCalculator.compute(6, 1), 6);
    });

    test(
      'zero or negative decks remaining yields zero rather than infinity',
      () {
        expect(TrueCountCalculator.raw(10, 0), 0);
        expect(TrueCountCalculator.raw(10, -1), 0);
        expect(TrueCountCalculator.compute(10, 0), 0);
      },
    );

    test('a sliver of a shoe is floored so the count cannot explode', () {
      expect(TrueCountCalculator.raw(4, 0.01), 16);
    });
  });

  group('rounding rules', () {
    test('toward zero truncates in both directions', () {
      expect(TrueCountCalculator.compute(7, 3), 2);
      expect(TrueCountCalculator.compute(-7, 3), -2);
    });

    test('nearest rounds up past the halfway point', () {
      expect(
        TrueCountCalculator.compute(7, 3, rounding: TrueCountRounding.nearest),
        2,
      );
      expect(
        TrueCountCalculator.compute(8, 3, rounding: TrueCountRounding.nearest),
        3,
      );
    });

    test('one decimal keeps a single fractional digit', () {
      expect(
        TrueCountCalculator.compute(
          7,
          3,
          rounding: TrueCountRounding.oneDecimal,
        ),
        2.3,
      );
    });
  });

  group('formatting', () {
    test('positive counts carry an explicit plus', () {
      expect(TrueCountCalculator.format(2), '+2');
      expect(TrueCountCalculator.formatRunning(5), '+5');
    });

    test('negative counts carry a minus', () {
      expect(TrueCountCalculator.format(-1.5), '-1.5');
      expect(TrueCountCalculator.formatRunning(-3), '-3');
    });

    test('zero is unsigned', () {
      expect(TrueCountCalculator.format(0), '0');
      expect(TrueCountCalculator.formatRunning(0), '0');
    });

    test('whole values drop the decimal', () {
      expect(TrueCountCalculator.format(2.0), '+2');
    });
  });

  group('deck estimation', () {
    test('snaps to the nearest half deck', () {
      expect(TrueCountCalculator.nearestHalfDeck(2.4), 2.5);
      expect(TrueCountCalculator.nearestHalfDeck(2.2), 2.0);
      expect(TrueCountCalculator.nearestHalfDeck(0.1), 0.0);
      expect(TrueCountCalculator.nearestHalfDeck(3.75), 4.0);
    });

    test('formats to one decimal place', () {
      expect(TrueCountCalculator.formatDecks(2.4), '2.5');
      expect(TrueCountCalculator.formatDecks(6), '6.0');
    });
  });
}
