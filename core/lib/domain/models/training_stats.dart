import 'package:meta/meta.dart';

import 'difficulty.dart';

/// Accuracy and speed for one drill type.
@immutable
class DrillStats {
  const DrillStats({
    this.attempts = 0,
    this.correct = 0,
    this.totalResponseMs = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.cardsSeen = 0,
    this.bestAccuracy = 0,
  });

  final int attempts;
  final int correct;

  /// Summed response time across every answered question.
  final int totalResponseMs;

  final int currentStreak;
  final int bestStreak;

  /// Cards shown while practising this drill.
  final int cardsSeen;

  /// Best single-session accuracy, `0..1`.
  final double bestAccuracy;

  int get wrong => attempts - correct;

  /// Lifetime accuracy in `0..1`. An untouched drill reports `0`.
  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  int get accuracyPercent => (accuracy * 100).round();

  Duration get averageResponse => attempts == 0
      ? Duration.zero
      : Duration(milliseconds: (totalResponseMs / attempts).round());

  /// Average response in seconds, one decimal, e.g. `1.8s`.
  String get averageResponseLabel => attempts == 0
      ? '—'
      : '${(averageResponse.inMilliseconds / 1000).toStringAsFixed(1)}s';

  bool get hasData => attempts > 0;

  /// Folds one answered question into the stats.
  DrillStats record({
    required bool isCorrect,
    required int responseMs,
    int cards = 0,
  }) {
    final int streak = isCorrect ? currentStreak + 1 : 0;
    return DrillStats(
      attempts: attempts + 1,
      correct: correct + (isCorrect ? 1 : 0),
      totalResponseMs: totalResponseMs + responseMs,
      currentStreak: streak,
      bestStreak: streak > bestStreak ? streak : bestStreak,
      cardsSeen: cardsSeen + cards,
      bestAccuracy: bestAccuracy,
    );
  }

  /// Records the accuracy of a finished session if it beat the previous best.
  DrillStats withSessionAccuracy(double sessionAccuracy) => copyWith(
    bestAccuracy: sessionAccuracy > bestAccuracy
        ? sessionAccuracy
        : bestAccuracy,
  );

  DrillStats copyWith({
    int? attempts,
    int? correct,
    int? totalResponseMs,
    int? currentStreak,
    int? bestStreak,
    int? cardsSeen,
    double? bestAccuracy,
  }) => DrillStats(
    attempts: attempts ?? this.attempts,
    correct: correct ?? this.correct,
    totalResponseMs: totalResponseMs ?? this.totalResponseMs,
    currentStreak: currentStreak ?? this.currentStreak,
    bestStreak: bestStreak ?? this.bestStreak,
    cardsSeen: cardsSeen ?? this.cardsSeen,
    bestAccuracy: bestAccuracy ?? this.bestAccuracy,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'attempts': attempts,
    'correct': correct,
    'totalResponseMs': totalResponseMs,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'cardsSeen': cardsSeen,
    'bestAccuracy': bestAccuracy,
  };

  factory DrillStats.fromJson(Map<String, dynamic> json) => DrillStats(
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    totalResponseMs: (json['totalResponseMs'] as num?)?.toInt() ?? 0,
    currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
    bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
    cardsSeen: (json['cardsSeen'] as num?)?.toInt() ?? 0,
    bestAccuracy: (json['bestAccuracy'] as num?)?.toDouble() ?? 0,
  );
}

/// One day of practice, used to draw the accuracy trend.
@immutable
class DailyRecord {
  const DailyRecord({
    required this.day,
    this.attempts = 0,
    this.correct = 0,
    this.xp = 0,
  });

  /// Midnight of the day this record covers.
  final DateTime day;

  final int attempts;
  final int correct;
  final int xp;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  int get accuracyPercent => (accuracy * 100).round();

  /// Two-letter weekday label used on the chart axis.
  String get weekdayLabel =>
      const <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][day.weekday - 1];

  DailyRecord record({required bool isCorrect, int xp = 0}) => DailyRecord(
    day: day,
    attempts: attempts + 1,
    correct: correct + (isCorrect ? 1 : 0),
    xp: this.xp + xp,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day.toIso8601String(),
    'attempts': attempts,
    'correct': correct,
    'xp': xp,
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    day: DateTime.parse(json['day'] as String),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    xp: (json['xp'] as num?)?.toInt() ?? 0,
  );
}

/// Every statistic the app keeps, across all drills.
@immutable
class TrainingStats {
  const TrainingStats({
    this.byDrill = const <String, DrillStats>{},
    this.history = const <DailyRecord>[],
    this.bestSpeedCardsPerMinute = 0,
    this.shoesCompleted = 0,
  });

  /// Keyed by [TrainingDrill.id].
  final Map<String, DrillStats> byDrill;

  /// Most recent days first is *not* assumed; the list is oldest first.
  final List<DailyRecord> history;

  /// Fastest sustained deal the user has counted accurately.
  final int bestSpeedCardsPerMinute;

  final int shoesCompleted;

  /// How many days of history the trend chart keeps.
  static const int historyLength = 14;

  DrillStats statsFor(TrainingDrill drill) =>
      byDrill[drill.id] ?? const DrillStats();

  int get totalAttempts =>
      byDrill.values.fold(0, (int sum, DrillStats s) => sum + s.attempts);

  int get totalCorrect =>
      byDrill.values.fold(0, (int sum, DrillStats s) => sum + s.correct);

  int get totalWrong => totalAttempts - totalCorrect;

  int get cardsCounted =>
      byDrill.values.fold(0, (int sum, DrillStats s) => sum + s.cardsSeen);

  double get overallAccuracy =>
      totalAttempts == 0 ? 0 : totalCorrect / totalAttempts;

  int get overallAccuracyPercent => (overallAccuracy * 100).round();

  int get longestStreak => byDrill.values.fold(
    0,
    (int best, DrillStats s) => s.bestStreak > best ? s.bestStreak : best,
  );

  int get currentStreak => byDrill.values.fold(
    0,
    (int best, DrillStats s) => s.currentStreak > best ? s.currentStreak : best,
  );

  Duration get averageResponse {
    final int attempts = totalAttempts;
    if (attempts == 0) return Duration.zero;
    final int total = byDrill.values.fold(
      0,
      (int sum, DrillStats s) => sum + s.totalResponseMs,
    );
    return Duration(milliseconds: (total / attempts).round());
  }

  String get averageResponseLabel => totalAttempts == 0
      ? '—'
      : '${(averageResponse.inMilliseconds / 1000).toStringAsFixed(1)}s';

  bool get hasData => totalAttempts > 0;

  /// Days that actually contain practice, oldest first.
  List<DailyRecord> get activeDays =>
      history.where((DailyRecord d) => d.attempts > 0).toList(growable: false);

  /// Records one answer against a drill and today's history entry.
  TrainingStats record({
    required TrainingDrill drill,
    required bool isCorrect,
    required int responseMs,
    int cards = 0,
    int xp = 0,
    DateTime? now,
  }) {
    final DateTime today = _midnight(now ?? DateTime.now());
    final Map<String, DrillStats> drills = Map<String, DrillStats>.of(byDrill);
    drills[drill.id] = statsFor(drill)
        .record(isCorrect: isCorrect, responseMs: responseMs, cards: cards);

    final List<DailyRecord> days = List<DailyRecord>.of(history);
    final int index = days.indexWhere((DailyRecord d) => d.day == today);
    if (index >= 0) {
      days[index] = days[index].record(isCorrect: isCorrect, xp: xp);
    } else {
      days.add(
        DailyRecord(
          day: today,
          attempts: 1,
          correct: isCorrect ? 1 : 0,
          xp: xp,
        ),
      );
    }
    days.sort((DailyRecord a, DailyRecord b) => a.day.compareTo(b.day));

    return copyWith(
      byDrill: drills,
      history: days.length > historyLength
          ? days.sublist(days.length - historyLength)
          : days,
    );
  }

  static DateTime _midnight(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  TrainingStats copyWith({
    Map<String, DrillStats>? byDrill,
    List<DailyRecord>? history,
    int? bestSpeedCardsPerMinute,
    int? shoesCompleted,
  }) => TrainingStats(
    byDrill: byDrill ?? this.byDrill,
    history: history ?? this.history,
    bestSpeedCardsPerMinute:
        bestSpeedCardsPerMinute ?? this.bestSpeedCardsPerMinute,
    shoesCompleted: shoesCompleted ?? this.shoesCompleted,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'byDrill': byDrill.map(
      (String key, DrillStats value) =>
          MapEntry<String, dynamic>(key, value.toJson()),
    ),
    'history': history.map((DailyRecord d) => d.toJson()).toList(),
    'bestSpeedCardsPerMinute': bestSpeedCardsPerMinute,
    'shoesCompleted': shoesCompleted,
  };

  factory TrainingStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> drills =
        (json['byDrill'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> days =
        (json['history'] as List<dynamic>?) ?? <dynamic>[];
    return TrainingStats(
      byDrill: drills.map(
        (String key, dynamic value) => MapEntry<String, DrillStats>(
          key,
          DrillStats.fromJson(value as Map<String, dynamic>),
        ),
      ),
      history: days
          .map((dynamic d) => DailyRecord.fromJson(d as Map<String, dynamic>))
          .toList(growable: false),
      bestSpeedCardsPerMinute:
          (json['bestSpeedCardsPerMinute'] as num?)?.toInt() ?? 0,
      shoesCompleted: (json['shoesCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}
