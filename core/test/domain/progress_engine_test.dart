import 'package:blackjack_core/domain/models/difficulty.dart';
import 'package:blackjack_core/domain/models/progress.dart';
import 'package:blackjack_core/domain/models/training_stats.dart';
import 'package:blackjack_core/domain/progress/progress_engine.dart';
import 'package:blackjack_core/domain/progress/training_plan.dart';
import 'package:blackjack_core/features/learn/data/lesson_content.dart';
import 'package:test/test.dart';

final DateTime today = DateTime(2026, 8, 26);

Progress answerMany(
  Progress start, {
  required int correct,
  required int wrong,
  TrainingDrill drill = TrainingDrill.runningCount,
  int cards = 0,
}) {
  Progress progress = start;
  for (int i = 0; i < correct; i++) {
    progress = ProgressEngine.recordAnswer(
      progress: progress,
      drill: drill,
      isCorrect: true,
      responseMs: 1000,
      difficulty: Difficulty.beginner,
      cards: cards,
      now: today,
    ).progress;
  }
  for (int i = 0; i < wrong; i++) {
    progress = ProgressEngine.recordAnswer(
      progress: progress,
      drill: drill,
      isCorrect: false,
      responseMs: 2000,
      difficulty: Difficulty.beginner,
      cards: cards,
      now: today,
    ).progress;
  }
  return progress;
}

void main() {
  group('levels', () {
    test('a new player is level 1', () {
      expect(const Progress().level, 1);
      expect(const Progress().levelTitle, 'Hi-Lo Novice');
    });

    test('levels rise with XP and each one costs more', () {
      expect(LevelSystem.levelForXp(0), 1);
      expect(LevelSystem.levelForXp(149), 1);
      expect(LevelSystem.levelForXp(150), 2);
      expect(LevelSystem.xpForLevel(1), 150);
      expect(LevelSystem.xpForLevel(2), 250);
      expect(LevelSystem.xpForLevel(3), 350);
    });

    test('cumulative XP matches the sum of the level costs', () {
      expect(LevelSystem.cumulativeXpFor(1), 0);
      expect(LevelSystem.cumulativeXpFor(2), 150);
      expect(LevelSystem.cumulativeXpFor(3), 400);
      expect(LevelSystem.cumulativeXpFor(4), 750);
    });

    test('progress within a level runs from zero to one', () {
      expect(LevelSystem.levelProgress(0), 0);
      expect(LevelSystem.levelProgress(75), closeTo(0.5, 1e-9));
      expect(LevelSystem.levelProgress(150), 0);
    });

    test('the level caps rather than running away', () {
      expect(LevelSystem.levelForXp(1000000), LevelSystem.maxLevel);
      expect(LevelSystem.xpToNextLevel(1000000), 0);
      expect(LevelSystem.levelProgress(1000000), 1);
    });

    test('titles change as the level rises', () {
      expect(LevelSystem.titleFor(1), 'Hi-Lo Novice');
      expect(LevelSystem.titleFor(3), 'Hi-Lo Apprentice');
      expect(LevelSystem.titleFor(5), 'Hi-Lo Intermediate');
      expect(LevelSystem.titleFor(8), 'Hi-Lo Advanced');
      expect(LevelSystem.titleFor(12), 'Hi-Lo Expert');
      expect(LevelSystem.titleFor(16), 'Hi-Lo Master');
    });
  });

  group('recording answers', () {
    test('a correct answer awards XP and a wrong one does not', () {
      final ProgressDelta right = ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 900,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(right.xpGained, XpAwards.correctAnswer);

      final ProgressDelta wrong = ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: false,
        responseMs: 900,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(wrong.xpGained, 0);
    });

    test('harder tiers pay more XP for the same answer', () {
      int xpAt(Difficulty difficulty) => ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 900,
        difficulty: difficulty,
        now: today,
      ).xpGained;

      expect(xpAt(Difficulty.beginner), 10);
      expect(xpAt(Difficulty.intermediate), 13);
      expect(xpAt(Difficulty.advanced), 16);
      expect(xpAt(Difficulty.expert), 20);
    });

    test('accuracy and cards accumulate across answers', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 8,
        wrong: 2,
        cards: 5,
      );
      final DrillStats stats = progress.stats.statsFor(
        TrainingDrill.runningCount,
      );
      expect(stats.attempts, 10);
      expect(stats.correct, 8);
      expect(stats.wrong, 2);
      expect(stats.accuracyPercent, 80);
      expect(stats.cardsSeen, 50);
    });

    test('a streak breaks on a wrong answer but the best is kept', () {
      Progress progress = answerMany(const Progress(), correct: 5, wrong: 0);
      progress = answerMany(progress, correct: 0, wrong: 1);
      final DrillStats stats = progress.stats.statsFor(
        TrainingDrill.runningCount,
      );
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 5);
    });

    test('average response time is the mean across answers', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 1,
        wrong: 1,
      );
      expect(
        progress.stats.statsFor(TrainingDrill.runningCount).averageResponse,
        const Duration(milliseconds: 1500),
      );
    });

    test('a level-up is reported once, when it happens', () {
      Progress progress = const Progress(xp: 140);
      final ProgressDelta delta = ProgressEngine.recordAnswer(
        progress: progress,
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(delta.leveledUp, isTrue);
      expect(delta.progress.level, 2);

      progress = delta.progress;
      final ProgressDelta next = ProgressEngine.recordAnswer(
        progress: progress,
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(next.leveledUp, isFalse);
    });
  });

  group('day streak', () {
    test('training for the first time starts a streak of one', () {
      final ProgressDelta delta = ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(delta.progress.dayStreak, 1);
      expect(delta.progress.bestDayStreak, 1);
    });

    test('training again the same day does not extend the streak', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 5,
        wrong: 0,
      );
      expect(progress.dayStreak, 1);
    });

    test('training on consecutive days extends the streak', () {
      Progress progress = ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      ).progress;

      progress = ProgressEngine.recordAnswer(
        progress: progress,
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today.add(const Duration(days: 1)),
      ).progress;

      expect(progress.dayStreak, 2);
    });

    test('a missed day resets the streak but keeps the best', () {
      Progress progress = const Progress();
      for (int day = 0; day < 3; day++) {
        progress = ProgressEngine.recordAnswer(
          progress: progress,
          drill: TrainingDrill.singleCard,
          isCorrect: true,
          responseMs: 500,
          difficulty: Difficulty.beginner,
          now: today.add(Duration(days: day)),
        ).progress;
      }
      expect(progress.dayStreak, 3);

      progress = ProgressEngine.recordAnswer(
        progress: progress,
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today.add(const Duration(days: 6)),
      ).progress;

      expect(progress.dayStreak, 1);
      expect(progress.bestDayStreak, 3);
    });
  });

  group('badges', () {
    test('the first answer earns the first badge', () {
      final ProgressDelta delta = ProgressEngine.recordAnswer(
        progress: const Progress(),
        drill: TrainingDrill.singleCard,
        isCorrect: false,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(delta.newBadges, contains(AchievementBadge.firstCount));
      expect(delta.hasCelebration, isTrue);
    });

    test('a badge is awarded once, not on every answer', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 3,
        wrong: 0,
      );
      final ProgressDelta delta = ProgressEngine.recordAnswer(
        progress: progress,
        drill: TrainingDrill.singleCard,
        isCorrect: true,
        responseMs: 500,
        difficulty: Difficulty.beginner,
        now: today,
      );
      expect(delta.newBadges, isNot(contains(AchievementBadge.firstCount)));
    });

    test('card milestones unlock in order', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 20,
        wrong: 0,
        cards: 5,
      );
      expect(progress.stats.cardsCounted, 100);
      expect(progress.hasBadge(AchievementBadge.hundredCards), isTrue);
      expect(progress.hasBadge(AchievementBadge.fiveHundredCards), isFalse);
    });

    test('ten correct answers unlock the streak and accuracy badges', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 10,
        wrong: 0,
      );
      expect(progress.hasBadge(AchievementBadge.tenCorrect), isTrue);
      expect(progress.hasBadge(AchievementBadge.streakTen), isTrue);
    });

    test('a perfect session unlocks the perfect-run badge', () {
      final Progress progress = answerMany(
        const Progress(),
        correct: 10,
        wrong: 0,
      );
      final ProgressDelta delta = ProgressEngine.completeSession(
        progress: progress,
        drill: TrainingDrill.runningCount,
        correct: 10,
        total: 10,
        now: today,
      );
      expect(delta.newBadges, contains(AchievementBadge.perfectRun));
      expect(delta.xpGained, XpAwards.perfectSequence);
    });

    test('an imperfect session awards no bonus', () {
      final ProgressDelta delta = ProgressEngine.completeSession(
        progress: const Progress(),
        drill: TrainingDrill.runningCount,
        correct: 8,
        total: 10,
        now: today,
      );
      expect(delta.xpGained, 0);
      expect(delta.newBadges, isNot(contains(AchievementBadge.perfectRun)));
    });

    test('completing a shoe awards XP and the full-shoe badge', () {
      final ProgressDelta delta = ProgressEngine.completeShoe(
        progress: const Progress(),
        now: today,
      );
      expect(delta.xpGained, XpAwards.completeShoe);
      expect(delta.newBadges, contains(AchievementBadge.fullShoe));
      expect(delta.progress.stats.shoesCompleted, 1);
    });

    test('true-count mastery needs both volume and accuracy', () {
      Progress progress = answerMany(
        const Progress(),
        correct: 15,
        wrong: 0,
        drill: TrainingDrill.trueCount,
      );
      expect(progress.hasBadge(AchievementBadge.trueCountMaster), isFalse);

      progress = answerMany(
        progress,
        correct: 6,
        wrong: 0,
        drill: TrainingDrill.trueCount,
      );
      expect(progress.hasBadge(AchievementBadge.trueCountMaster), isTrue);
    });

    test('finishing every lesson awards the scholar badge', () {
      Progress progress = const Progress();
      for (final String id in LessonLibrary.allIds) {
        progress = ProgressEngine.completeLesson(
          progress: progress,
          lessonId: id,
          now: today,
        ).progress;
      }
      progress = ProgressEngine.checkLessonCompletion(
        progress,
        LessonLibrary.allIds,
      );
      expect(progress.hasBadge(AchievementBadge.scholar), isTrue);
    });
  });

  group('lessons', () {
    test('completing a lesson awards XP the first time only', () {
      final ProgressDelta first = ProgressEngine.completeLesson(
        progress: const Progress(),
        lessonId: 'card_values',
        now: today,
      );
      expect(first.xpGained, XpAwards.completeLesson);

      final ProgressDelta again = ProgressEngine.completeLesson(
        progress: first.progress,
        lessonId: 'card_values',
        now: today,
      );
      expect(again.xpGained, 0);
    });

    test('lessons unlock in order', () {
      final Lesson second = LessonLibrary.lessons[1];
      expect(LessonLibrary.isUnlocked(second, <String>{}), isFalse);
      expect(LessonLibrary.isUnlocked(second, <String>{'card_values'}), isTrue);
      expect(
        LessonLibrary.isUnlocked(LessonLibrary.lessons.first, <String>{}),
        isTrue,
      );
    });

    test('every lesson has content, a goal and at least one quiz', () {
      for (final Lesson lesson in LessonLibrary.lessons) {
        expect(lesson.blocks, isNotEmpty, reason: lesson.id);
        expect(lesson.goal, isNotEmpty, reason: lesson.id);
        expect(lesson.quizCount, greaterThan(0), reason: lesson.id);
      }
    });

    test('every quiz has a valid correct answer', () {
      for (final Lesson lesson in LessonLibrary.lessons) {
        for (final LessonBlock block in lesson.blocks) {
          if (block.type != LessonBlockType.quiz) continue;
          expect(block.options.length, greaterThanOrEqualTo(2));
          expect(
            block.correctIndex,
            inInclusiveRange(0, block.options.length - 1),
          );
          expect(block.explanation, isNotNull);
        }
      }
    });

    test('the next lesson is the first unfinished one', () {
      expect(LessonLibrary.nextFor(<String>{})?.id, 'card_values');
      expect(
        LessonLibrary.nextFor(<String>{'card_values'})?.id,
        'running_count',
      );
      expect(LessonLibrary.nextFor(LessonLibrary.allIds.toSet()), isNull);
    });
  });

  group('difficulty unlocks', () {
    test('beginner is always available', () {
      expect(Difficulty.beginner.isUnlockedAt(1), isTrue);
    });

    test('higher tiers need levels', () {
      expect(Difficulty.intermediate.isUnlockedAt(2), isFalse);
      expect(Difficulty.intermediate.isUnlockedAt(3), isTrue);
      expect(Difficulty.expert.isUnlockedAt(7), isFalse);
      expect(Difficulty.expert.isUnlockedAt(8), isTrue);
    });

    test('the highest unlocked tier tracks the level', () {
      expect(Difficulty.highestUnlockedAt(1), Difficulty.beginner);
      expect(Difficulty.highestUnlockedAt(4), Difficulty.intermediate);
      expect(Difficulty.highestUnlockedAt(6), Difficulty.advanced);
      expect(Difficulty.highestUnlockedAt(20), Difficulty.expert);
    });
  });

  group('what to do next', () {
    final Map<String, String> titles = <String, String>{
      for (final Lesson lesson in LessonLibrary.lessons)
        lesson.id: lesson.title,
    };

    test('a new user is sent to the first lesson', () {
      final NextStep step = TrainingPlan.recommend(
        progress: const Progress(),
        lessonIds: LessonLibrary.allIds,
        lessonTitles: titles,
      );
      expect(step.kind, NextStepKind.lesson);
      expect(step.lessonId, 'card_values');
    });

    test('with lessons done, an untried drill comes next', () {
      Progress progress = const Progress();
      for (final String id in LessonLibrary.allIds) {
        progress = ProgressEngine.completeLesson(
          progress: progress,
          lessonId: id,
          now: today,
        ).progress;
      }
      final NextStep step = TrainingPlan.recommend(
        progress: progress,
        lessonIds: LessonLibrary.allIds,
        lessonTitles: titles,
      );
      expect(step.kind, NextStepKind.drill);
    });

    test('with everything sharp, the simulator comes next', () {
      Progress progress = const Progress();
      for (final String id in LessonLibrary.allIds) {
        progress = ProgressEngine.completeLesson(
          progress: progress,
          lessonId: id,
          now: today,
        ).progress;
      }
      for (final TrainingDrill drill in TrainingDrill.values) {
        if (drill == TrainingDrill.fullDrill) continue;
        progress = answerMany(progress, correct: 20, wrong: 0, drill: drill);
      }
      final NextStep step = TrainingPlan.recommend(
        progress: progress,
        lessonIds: LessonLibrary.allIds,
        lessonTitles: titles,
      );
      expect(step.kind, NextStepKind.simulator);
    });

    test('the weakest drill is prioritised once all are practised', () {
      Progress progress = const Progress();
      for (final String id in LessonLibrary.allIds) {
        progress = ProgressEngine.completeLesson(
          progress: progress,
          lessonId: id,
          now: today,
        ).progress;
      }
      for (final TrainingDrill drill in TrainingDrill.values) {
        if (drill == TrainingDrill.fullDrill) continue;
        progress = answerMany(progress, correct: 20, wrong: 0, drill: drill);
      }
      progress = answerMany(
        progress,
        correct: 0,
        wrong: 20,
        drill: TrainingDrill.trueCount,
      );

      final NextStep step = TrainingPlan.recommend(
        progress: progress,
        lessonIds: LessonLibrary.allIds,
        lessonTitles: titles,
      );
      expect(step.kind, NextStepKind.drill);
      expect(step.drill, TrainingDrill.trueCount);
    });
  });

  group('persistence round trip', () {
    test('progress survives a JSON round trip', () {
      Progress progress = answerMany(
        const Progress(),
        correct: 12,
        wrong: 3,
        cards: 4,
      );
      progress = ProgressEngine.completeLesson(
        progress: progress,
        lessonId: 'card_values',
        now: today,
      ).progress;
      progress = ProgressEngine.markOnboardingSeen(progress);

      final Progress restored = Progress.fromJson(progress.toJson());

      expect(restored.xp, progress.xp);
      expect(restored.level, progress.level);
      expect(restored.dayStreak, progress.dayStreak);
      expect(restored.completedLessons, progress.completedLessons);
      expect(restored.unlockedBadges, progress.unlockedBadges);
      expect(restored.hasSeenOnboarding, isTrue);
      expect(restored.stats.statsFor(TrainingDrill.runningCount).attempts, 15);
      expect(restored.stats.cardsCounted, progress.stats.cardsCounted);
      expect(restored.stats.history.length, progress.stats.history.length);
    });

    test('an empty JSON object yields sane defaults', () {
      final Progress progress = Progress.fromJson(<String, dynamic>{});
      expect(progress.xp, 0);
      expect(progress.level, 1);
      expect(progress.hasSeenOnboarding, isFalse);
      expect(progress.stats.hasData, isFalse);
    });

    test('history is capped at a fortnight', () {
      Progress progress = const Progress();
      for (int day = 0; day < 30; day++) {
        progress = ProgressEngine.recordAnswer(
          progress: progress,
          drill: TrainingDrill.singleCard,
          isCorrect: true,
          responseMs: 500,
          difficulty: Difficulty.beginner,
          now: today.add(Duration(days: day)),
        ).progress;
      }
      expect(progress.stats.history.length, TrainingStats.historyLength);
    });
  });
}
