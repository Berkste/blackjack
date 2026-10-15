import 'package:blackjack_core/domain/counting/hi_lo_counter.dart';
import 'package:blackjack_core/domain/counting/true_count_calculator.dart';
import 'package:blackjack_core/domain/models/difficulty.dart';
import 'package:blackjack_core/domain/training/drill_question.dart';
import 'package:test/test.dart';

void main() {
  group('question shape', () {
    test('every drill produces a well-formed question at every tier', () {
      for (final TrainingDrill drill in TrainingDrill.values) {
        for (final Difficulty difficulty in Difficulty.values) {
          final DrillGenerator generator = DrillGenerator(seed: 7);
          for (int i = 0; i < 25; i++) {
            final DrillQuestion question = generator.next(drill, difficulty);
            final String where = '${drill.id}/${difficulty.name}#$i';

            expect(question.prompt, isNotEmpty, reason: where);
            expect(question.explanation, isNotEmpty, reason: where);
            expect(
              question.options.length,
              greaterThanOrEqualTo(3),
              reason: where,
            );
            expect(
              question.correctIndex,
              inInclusiveRange(0, question.options.length - 1),
              reason: where,
            );
            expect(
              question.options.toSet().length,
              question.options.length,
              reason: 'duplicate options at $where',
            );
          }
        }
      }
    });

    test('the same seed replays the same questions', () {
      final DrillGenerator a = DrillGenerator(seed: 99);
      final DrillGenerator b = DrillGenerator(seed: 99);
      for (int i = 0; i < 10; i++) {
        final DrillQuestion qa = a.next(
          TrainingDrill.runningCount,
          Difficulty.intermediate,
        );
        final DrillQuestion qb = b.next(
          TrainingDrill.runningCount,
          Difficulty.intermediate,
        );
        expect(qa.cards, qb.cards);
        expect(qa.options, qb.options);
        expect(qa.correctIndex, qb.correctIndex);
      }
    });

    test('different seeds diverge', () {
      final DrillQuestion a = DrillGenerator(seed: 1)
          .next(TrainingDrill.runningCount, Difficulty.advanced);
      final DrillQuestion b = DrillGenerator(seed: 2)
          .next(TrainingDrill.runningCount, Difficulty.advanced);
      expect(a.cards, isNot(b.cards));
    });
  });

  group('single card', () {
    test('the answer always matches the card tag', () {
      final DrillGenerator generator = DrillGenerator(seed: 3);
      for (int i = 0; i < 100; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.singleCard,
          Difficulty.beginner,
        );
        expect(question.cards, hasLength(1));
        final String expected = switch (question.cards.first.hiLoValue) {
          1 => '+1',
          0 => '0',
          _ => '-1',
        };
        expect(question.correctLabel, expected);
      }
    });

    test('the options are exactly the three tags', () {
      final DrillQuestion question = DrillGenerator(seed: 4)
          .next(TrainingDrill.singleCard, Difficulty.beginner);
      expect(question.options, <String>['+1', '0', '-1']);
    });
  });

  group('running count', () {
    test('the sequence length follows the difficulty', () {
      for (final Difficulty difficulty in Difficulty.values) {
        final DrillQuestion question = DrillGenerator(seed: 5)
            .next(TrainingDrill.runningCount, difficulty);
        expect(question.cards, hasLength(difficulty.sequenceLength));
      }
    });

    test('the answer equals the Hi-Lo total of the cards', () {
      final DrillGenerator generator = DrillGenerator(seed: 6);
      for (int i = 0; i < 50; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.runningCount,
          Difficulty.intermediate,
        );
        final int expected = HiLoCounter.countOf(question.cards);
        expect(
          question.correctLabel,
          expected > 0 ? '+$expected' : '$expected',
        );
      }
    });

    test('the breakdown ends on the answer', () {
      final DrillQuestion question = DrillGenerator(seed: 8)
          .next(TrainingDrill.runningCount, Difficulty.intermediate);
      final List<CountStep> steps = question.breakdown;
      expect(steps, hasLength(question.cards.length));
      expect(steps.last.runningTotal, HiLoCounter.countOf(question.cards));
    });
  });

  group('true count', () {
    test('the answer is the running count divided by the decks left', () {
      final DrillGenerator generator = DrillGenerator(seed: 11);
      for (int i = 0; i < 60; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.trueCount,
          Difficulty.advanced,
        );
        expect(question.runningCount, isNotNull);
        expect(question.decksRemaining, isNotNull);
        final double expected = TrueCountCalculator.compute(
          question.runningCount!,
          question.decksRemaining!,
        );
        expect(question.correctLabel, TrueCountCalculator.format(expected));
      }
    });

    test('the decks remaining never exceed the shoe', () {
      final DrillGenerator generator = DrillGenerator(seed: 12);
      for (int i = 0; i < 60; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.trueCount,
          Difficulty.expert,
        );
        expect(question.decksRemaining, greaterThan(0));
        expect(
          question.decksRemaining,
          lessThanOrEqualTo(question.totalDecks.toDouble()),
        );
      }
    });
  });

  group('deck estimation', () {
    test('the shoe is partly dealt and the answer is in range', () {
      final DrillGenerator generator = DrillGenerator(seed: 13);
      for (int i = 0; i < 60; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.deckEstimation,
          Difficulty.beginner,
        );
        expect(question.decksRemaining, greaterThan(0));
        expect(
          question.decksRemaining,
          lessThan(question.totalDecks.toDouble()),
        );
        expect(
          question.options,
          contains(question.decksRemaining!.toStringAsFixed(0)),
        );
      }
    });

    test('advanced estimation asks for half decks', () {
      final DrillGenerator generator = DrillGenerator(seed: 14);
      bool sawHalf = false;
      for (int i = 0; i < 40; i++) {
        final DrillQuestion question = generator.next(
          TrainingDrill.deckEstimation,
          Difficulty.advanced,
        );
        if (question.decksRemaining! % 1 != 0) sawHalf = true;
      }
      expect(sawHalf, isTrue);
    });
  });

  group('decks left helper', () {
    test('converts cards dealt into decks remaining', () {
      expect(DrillGenerator.decksLeft(6, 0), 6);
      expect(DrillGenerator.decksLeft(6, 52), 5);
      expect(DrillGenerator.decksLeft(6, 26), 5.5);
    });
  });
}
