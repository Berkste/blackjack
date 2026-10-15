import 'package:meta/meta.dart';

import '../models/difficulty.dart';
import '../models/progress.dart';
import '../models/training_stats.dart';

/// What the "Continue Training" button should do next.
enum NextStepKind { lesson, drill, simulator }

/// A single recommended next action.
@immutable
class NextStep {
  const NextStep({
    required this.kind,
    required this.title,
    required this.reason,
    this.lessonId,
    this.drill,
  });

  final NextStepKind kind;

  /// Label for the primary call to action.
  final String title;

  /// One line explaining why this was chosen.
  final String reason;

  final String? lessonId;
  final TrainingDrill? drill;
}

/// Chooses what the user should do next.
///
/// The rule is simple and legible: finish the teaching first, then drill the
/// weakest skill you have unlocked, then put it together in a full shoe.
abstract final class TrainingPlan {
  /// Accuracy below which a drill is considered the weak spot.
  static const double masteryThreshold = 0.85;

  /// Attempts needed before a drill's accuracy is treated as meaningful.
  static const int minimumAttempts = 10;

  static NextStep recommend({
    required Progress progress,
    required List<String> lessonIds,
    required Map<String, String> lessonTitles,
  }) {
    // 1. Any unfinished lesson comes first.
    for (final String id in lessonIds) {
      if (!progress.hasCompletedLesson(id)) {
        return NextStep(
          kind: NextStepKind.lesson,
          title: 'Lesson: ${lessonTitles[id] ?? id}',
          reason: 'Next in the curriculum',
          lessonId: id,
        );
      }
    }

    // 2. The unlocked drill with the weakest accuracy.
    final TrainingDrill? weakest = _weakestDrill(progress);
    if (weakest != null) {
      final DrillStats stats = progress.stats.statsFor(weakest);
      return NextStep(
        kind: NextStepKind.drill,
        title: weakest.title,
        reason: stats.hasData
            ? 'Your weakest drill at ${stats.accuracyPercent}%'
            : 'You have not tried this one yet',
        drill: weakest,
      );
    }

    // 3. Everything is sharp — go count a real shoe.
    return const NextStep(
      kind: NextStepKind.simulator,
      title: 'Count a full shoe',
      reason: 'Every drill is above 85% — put it together',
    );
  }

  /// The drill most in need of work, or `null` when all are strong.
  static TrainingDrill? _weakestDrill(Progress progress) {
    TrainingDrill? weakest;
    double weakestAccuracy = 1;

    for (final TrainingDrill drill in TrainingDrill.values) {
      if (drill == TrainingDrill.fullDrill) continue;
      final DrillStats stats = progress.stats.statsFor(drill);
      if (stats.attempts < minimumAttempts) {
        // Untouched or barely touched drills are always the priority.
        return drill;
      }
      if (stats.accuracy < weakestAccuracy) {
        weakestAccuracy = stats.accuracy;
        weakest = drill;
      }
    }

    return weakestAccuracy < masteryThreshold ? weakest : null;
  }

  /// Drills offered as one-tap quick practice on the home screen.
  static const List<TrainingDrill> quickDrills = <TrainingDrill>[
    TrainingDrill.runningCount,
    TrainingDrill.trueCount,
    TrainingDrill.singleCard,
  ];
}
