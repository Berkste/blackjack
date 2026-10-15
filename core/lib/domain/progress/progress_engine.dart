import 'package:meta/meta.dart';

import '../models/difficulty.dart';
import '../models/progress.dart';
import '../models/training_stats.dart';

/// What changed when progress was updated, so the UI can celebrate it.
@immutable
class ProgressDelta {
  const ProgressDelta({
    required this.progress,
    this.xpGained = 0,
    this.leveledUp = false,
    this.newBadges = const <AchievementBadge>[],
  });

  final Progress progress;
  final int xpGained;
  final bool leveledUp;
  final List<AchievementBadge> newBadges;

  bool get hasCelebration => leveledUp || newBadges.isNotEmpty;
}

/// Pure progression rules: XP, levels, streaks and badges.
///
/// Kept free of Riverpod and Flutter so the whole economy is unit-testable.
abstract final class ProgressEngine {
  /// Folds a single answered drill question into [progress].
  static ProgressDelta recordAnswer({
    required Progress progress,
    required TrainingDrill drill,
    required bool isCorrect,
    required int responseMs,
    required Difficulty difficulty,
    int cards = 0,
    DateTime? now,
  }) {
    final DateTime today = now ?? DateTime.now();
    final int xp = isCorrect
        ? (XpAwards.correctAnswer * difficulty.xpMultiplier).round()
        : 0;

    final TrainingStats stats = progress.stats.record(
      drill: drill,
      isCorrect: isCorrect,
      responseMs: responseMs,
      cards: cards,
      xp: xp,
      now: today,
    );

    return _apply(
      progress: progress.copyWith(stats: stats),
      xpGained: xp,
      previousLevel: progress.level,
      now: today,
    );
  }

  /// Awards the bonus for finishing a drill session.
  static ProgressDelta completeSession({
    required Progress progress,
    required TrainingDrill drill,
    required int correct,
    required int total,
    DateTime? now,
  }) {
    if (total == 0) return ProgressDelta(progress: progress);
    final bool perfect = correct == total;
    final int xp = perfect ? XpAwards.perfectSequence : 0;
    final double accuracy = correct / total;

    final Map<String, DrillStats> drills = Map<String, DrillStats>.of(
      progress.stats.byDrill,
    );
    drills[drill.id] = progress.stats
        .statsFor(drill)
        .withSessionAccuracy(accuracy);

    return _apply(
      progress: progress.copyWith(
        stats: progress.stats.copyWith(byDrill: drills),
      ),
      xpGained: xp,
      previousLevel: progress.level,
      now: now ?? DateTime.now(),
      perfectSession: perfect && total >= 5,
    );
  }

  /// Marks a lesson complete, awarding XP the first time only.
  static ProgressDelta completeLesson({
    required Progress progress,
    required String lessonId,
    DateTime? now,
  }) {
    if (progress.hasCompletedLesson(lessonId)) {
      return ProgressDelta(progress: progress);
    }
    return _apply(
      progress: progress.copyWith(
        completedLessons: <String>{...progress.completedLessons, lessonId},
      ),
      xpGained: XpAwards.completeLesson,
      previousLevel: progress.level,
      now: now ?? DateTime.now(),
    );
  }

  /// Awards the bonus for counting an entire shoe.
  static ProgressDelta completeShoe({
    required Progress progress,
    DateTime? now,
  }) => _apply(
    progress: progress.copyWith(
      stats: progress.stats.copyWith(
        shoesCompleted: progress.stats.shoesCompleted + 1,
      ),
    ),
    xpGained: XpAwards.completeShoe,
    previousLevel: progress.level,
    now: now ?? DateTime.now(),
  );

  /// Records a sustained speed the user counted accurately.
  static Progress recordSpeed({
    required Progress progress,
    required int cardsPerMinute,
  }) {
    if (cardsPerMinute <= progress.stats.bestSpeedCardsPerMinute) {
      return progress;
    }
    return progress.copyWith(
      stats: progress.stats.copyWith(bestSpeedCardsPerMinute: cardsPerMinute),
    );
  }

  static Progress markOnboardingSeen(Progress progress) =>
      progress.copyWith(hasSeenOnboarding: true);

  /// Applies XP, the day streak and badge checks in one pass.
  static ProgressDelta _apply({
    required Progress progress,
    required int xpGained,
    required int previousLevel,
    required DateTime now,
    bool perfectSession = false,
    bool countedFullShoe = false,
    bool heldExpertSpeed = false,
  }) {
    Progress next = progress.copyWith(xp: progress.xp + xpGained);
    next = _updateStreak(next, now);

    final Set<String> badges = <String>{...next.unlockedBadges};
    final List<AchievementBadge> earned = <AchievementBadge>[];

    void award(AchievementBadge badge) {
      if (badges.add(badge.id)) earned.add(badge);
    }

    final TrainingStats stats = next.stats;
    if (stats.totalAttempts >= 1) award(AchievementBadge.firstCount);
    if (stats.totalCorrect >= 10) award(AchievementBadge.tenCorrect);
    if (stats.cardsCounted >= 100) award(AchievementBadge.hundredCards);
    if (stats.cardsCounted >= 500) award(AchievementBadge.fiveHundredCards);
    if (stats.cardsCounted >= 1000) award(AchievementBadge.thousandCards);
    if (stats.longestStreak >= 10) award(AchievementBadge.streakTen);
    if (perfectSession) award(AchievementBadge.perfectRun);
    if (countedFullShoe || stats.shoesCompleted >= 1)
      award(AchievementBadge.fullShoe);
    if (heldExpertSpeed ||
        stats.bestSpeedCardsPerMinute >= CountSpeed.expert.cardsPerMinute) {
      award(AchievementBadge.speedCounter);
    }

    final DrillStats trueCount = stats.statsFor(TrainingDrill.trueCount);
    if (trueCount.attempts >= 20 && trueCount.accuracy >= 0.9) {
      award(AchievementBadge.trueCountMaster);
    }

    next = next.copyWith(unlockedBadges: badges);

    return ProgressDelta(
      progress: next,
      xpGained: xpGained,
      leveledUp: next.level > previousLevel,
      newBadges: earned,
    );
  }

  /// Awards the scholar badge once every lesson id in [allLessonIds] is done.
  static Progress checkLessonCompletion(
    Progress progress,
    Iterable<String> allLessonIds,
  ) {
    final bool complete = allLessonIds.every(
      progress.completedLessons.contains,
    );
    if (!complete || progress.hasBadge(AchievementBadge.scholar))
      return progress;
    return progress.copyWith(
      unlockedBadges: <String>{
        ...progress.unlockedBadges,
        AchievementBadge.scholar.id,
      },
    );
  }

  static Progress _updateStreak(Progress progress, DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? last = progress.lastTrained;
    if (last != null && last == today) return progress;

    final int streak = last != null && today.difference(last).inDays == 1
        ? progress.dayStreak + 1
        : 1;

    return progress.copyWith(
      dayStreak: streak,
      bestDayStreak: streak > progress.bestDayStreak
          ? streak
          : progress.bestDayStreak,
      lastTrainedIso: today.toIso8601String(),
    );
  }
}
