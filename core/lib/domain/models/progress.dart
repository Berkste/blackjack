import 'package:meta/meta.dart';

import 'training_stats.dart';

/// XP awards. Kept in one place so the economy stays consistent.
abstract final class XpAwards {
  static const int correctAnswer = 10;
  static const int perfectSequence = 25;
  static const int completeLesson = 50;
  static const int completeShoe = 100;
}

/// Maps XP onto levels and level titles.
///
/// The curve is gentle early so the first few sessions feel like progress,
/// and widens later so a high level actually means something.
abstract final class LevelSystem {
  static const int maxLevel = 20;

  /// XP required to go from [level] to the next one.
  static int xpForLevel(int level) => 150 + (level - 1) * 100;

  /// Total XP required to have reached [level].
  static int cumulativeXpFor(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  static int levelForXp(int xp) {
    int level = 1;
    while (level < maxLevel && xp >= cumulativeXpFor(level + 1)) {
      level++;
    }
    return level;
  }

  /// XP earned inside the current level.
  static int xpIntoLevel(int xp) => xp - cumulativeXpFor(levelForXp(xp));

  /// XP needed to finish the current level.
  static int xpToNextLevel(int xp) {
    final int level = levelForXp(xp);
    if (level >= maxLevel) return 0;
    return xpForLevel(level);
  }

  /// Progress through the current level, `0..1`.
  static double levelProgress(int xp) {
    final int needed = xpToNextLevel(xp);
    if (needed == 0) return 1;
    return (xpIntoLevel(xp) / needed).clamp(0.0, 1.0);
  }

  /// The rank shown under the level number.
  static String titleFor(int level) {
    if (level >= 16) return 'Hi-Lo Master';
    if (level >= 12) return 'Hi-Lo Expert';
    if (level >= 8) return 'Hi-Lo Advanced';
    if (level >= 5) return 'Hi-Lo Intermediate';
    if (level >= 3) return 'Hi-Lo Apprentice';
    return 'Hi-Lo Novice';
  }
}

/// An unlockable badge.
enum AchievementBadge {
  firstCount(
    id: 'first_count',
    title: 'First Count',
    description: 'Answer your first drill question.',
    icon: '◆',
  ),
  tenCorrect(
    id: 'ten_correct',
    title: '10 Correct',
    description: 'Get ten answers right.',
    icon: '◆',
  ),
  hundredCards(
    id: 'hundred_cards',
    title: '100 Cards',
    description: 'Count one hundred cards.',
    icon: '❖',
  ),
  fiveHundredCards(
    id: 'five_hundred_cards',
    title: '500 Cards',
    description: 'Count five hundred cards.',
    icon: '❖',
  ),
  thousandCards(
    id: 'thousand_cards',
    title: '1000 Cards',
    description: 'Count a thousand cards.',
    icon: '❖',
  ),
  perfectRun(
    id: 'perfect_run',
    title: 'Perfect Run',
    description: 'Finish a drill session without a single mistake.',
    icon: '★',
  ),
  trueCountMaster(
    id: 'true_count_master',
    title: 'True Count Master',
    description: 'Reach 90% accuracy on true-count drills.',
    icon: '★',
  ),
  fullShoe(
    id: 'full_shoe',
    title: 'Full Shoe',
    description: 'Count an entire shoe from first card to cut card.',
    icon: '⬢',
  ),
  speedCounter(
    id: 'speed_counter',
    title: 'Speed Counter',
    description: 'Hold the count at expert speed.',
    icon: '⚡',
  ),
  streakTen(
    id: 'streak_ten',
    title: 'On A Roll',
    description: 'Answer ten in a row correctly.',
    icon: '▲',
  ),
  scholar(
    id: 'scholar',
    title: 'Scholar',
    description: 'Complete every lesson.',
    icon: '❍',
  );

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;

  /// A glyph rather than an icon font, to keep the look restrained.
  final String icon;

  static AchievementBadge? fromId(String id) {
    for (final AchievementBadge badge in AchievementBadge.values) {
      if (badge.id == id) return badge;
    }
    return null;
  }
}

/// Everything the app knows about how far the user has got.
@immutable
class Progress {
  const Progress({
    this.xp = 0,
    this.completedLessons = const <String>{},
    this.unlockedBadges = const <String>{},
    this.dayStreak = 0,
    this.bestDayStreak = 0,
    this.lastTrainedIso,
    this.hasSeenOnboarding = false,
    this.stats = const TrainingStats(),
  });

  final int xp;
  final Set<String> completedLessons;
  final Set<String> unlockedBadges;

  /// Consecutive days with at least one drill answered.
  final int dayStreak;
  final int bestDayStreak;

  /// Midnight of the last day the user trained, ISO-8601.
  final String? lastTrainedIso;

  final bool hasSeenOnboarding;
  final TrainingStats stats;

  int get level => LevelSystem.levelForXp(xp);

  String get levelTitle => LevelSystem.titleFor(level);

  double get levelProgress => LevelSystem.levelProgress(xp);

  int get xpIntoLevel => LevelSystem.xpIntoLevel(xp);

  int get xpToNextLevel => LevelSystem.xpToNextLevel(xp);

  DateTime? get lastTrained =>
      lastTrainedIso == null ? null : DateTime.tryParse(lastTrainedIso!);

  bool hasBadge(AchievementBadge badge) => unlockedBadges.contains(badge.id);

  bool hasCompletedLesson(String lessonId) =>
      completedLessons.contains(lessonId);

  List<AchievementBadge> get earnedBadges => AchievementBadge.values
      .where((AchievementBadge b) => unlockedBadges.contains(b.id))
      .toList(growable: false);

  Progress copyWith({
    int? xp,
    Set<String>? completedLessons,
    Set<String>? unlockedBadges,
    int? dayStreak,
    int? bestDayStreak,
    String? lastTrainedIso,
    bool? hasSeenOnboarding,
    TrainingStats? stats,
  }) => Progress(
    xp: xp ?? this.xp,
    completedLessons: completedLessons ?? this.completedLessons,
    unlockedBadges: unlockedBadges ?? this.unlockedBadges,
    dayStreak: dayStreak ?? this.dayStreak,
    bestDayStreak: bestDayStreak ?? this.bestDayStreak,
    lastTrainedIso: lastTrainedIso ?? this.lastTrainedIso,
    hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    stats: stats ?? this.stats,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'xp': xp,
    'completedLessons': completedLessons.toList(),
    'unlockedBadges': unlockedBadges.toList(),
    'dayStreak': dayStreak,
    'bestDayStreak': bestDayStreak,
    'lastTrainedIso': lastTrainedIso,
    'hasSeenOnboarding': hasSeenOnboarding,
    'stats': stats.toJson(),
  };

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    completedLessons:
        ((json['completedLessons'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) => e as String)
            .toSet(),
    unlockedBadges:
        ((json['unlockedBadges'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) => e as String)
            .toSet(),
    dayStreak: (json['dayStreak'] as num?)?.toInt() ?? 0,
    bestDayStreak: (json['bestDayStreak'] as num?)?.toInt() ?? 0,
    lastTrainedIso: json['lastTrainedIso'] as String?,
    hasSeenOnboarding: json['hasSeenOnboarding'] as bool? ?? false,
    stats: json['stats'] == null
        ? const TrainingStats()
        : TrainingStats.fromJson(json['stats'] as Map<String, dynamic>),
  );
}
