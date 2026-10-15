import 'dart:math' as math;

/// How a true count is rounded before it is compared to an index.
enum TrueCountRounding {
  /// Round toward zero — the conservative convention most books teach.
  floorTowardZero('Toward zero', 'Drops the fraction: +2.7 becomes +2.'),

  /// Round to the nearest whole number.
  nearest('Nearest', 'Rounds to the closest whole number: +2.7 becomes +3.'),

  /// Keep one decimal place.
  oneDecimal('One decimal', 'Keeps a decimal: +2.7 stays +2.7.');

  const TrueCountRounding(this.label, this.description);

  final String label;
  final String description;
}

/// Converts a running count into a true count.
///
/// Pure arithmetic, deliberately free of any Flutter or state dependency.
abstract final class TrueCountCalculator {
  /// The smallest decks-remaining value used as a divisor. Below this the
  /// division explodes, so real counters floor their estimate.
  static const double minimumDivisor = 0.25;

  /// Raw true count: running count divided by decks remaining.
  ///
  /// Returns `0` when [decksRemaining] is not positive.
  static double raw(int runningCount, double decksRemaining) {
    if (decksRemaining <= 0) return 0;
    return runningCount / math.max(decksRemaining, minimumDivisor);
  }

  /// True count rounded with [rounding].
  static double compute(
    int runningCount,
    double decksRemaining, {
    TrueCountRounding rounding = TrueCountRounding.floorTowardZero,
  }) => round(raw(runningCount, decksRemaining), rounding);

  /// Applies [rounding] to an already-computed true count.
  static double round(double value, TrueCountRounding rounding) {
    switch (rounding) {
      case TrueCountRounding.floorTowardZero:
        return value.truncateToDouble();
      case TrueCountRounding.nearest:
        return value.roundToDouble();
      case TrueCountRounding.oneDecimal:
        return (value * 10).roundToDouble() / 10;
    }
  }

  /// Formats a true count for display, always signed: `+2`, `-1.5`, `0`.
  static String format(double value) {
    final double normalised = value == 0 ? 0 : value;
    final String text = normalised == normalised.roundToDouble()
        ? normalised.toStringAsFixed(0)
        : normalised.toStringAsFixed(1);
    return normalised > 0 ? '+$text' : text;
  }

  /// Formats a running count, always signed: `+5`, `-3`, `0`.
  static String formatRunning(int value) => value > 0 ? '+$value' : '$value';

  /// Formats decks remaining to the nearest half deck, e.g. `2.5`.
  static String formatDecks(double decks) =>
      (nearestHalfDeck(decks)).toStringAsFixed(1);

  /// Snaps [decks] to the nearest half deck, the granularity counters use.
  static double nearestHalfDeck(double decks) => (decks * 2).round() / 2;
}
