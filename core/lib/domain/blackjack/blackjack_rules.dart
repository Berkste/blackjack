import 'package:meta/meta.dart';

/// Table rules for the educational simulator.
///
/// Every field maps to a real table condition, because those conditions —
/// not the count alone — decide whether an advantage exists at all.
@immutable
class BlackjackRules {
  const BlackjackRules({
    this.deckCount = 6,
    this.dealerHitsSoft17 = false,
    this.doubleAfterSplit = true,
    this.surrenderAllowed = true,
    this.doubleOnAnyTwoCards = true,
    this.maxSplitHands = 4,
    this.resplitAces = false,
    this.penetration = 0.75,
    this.blackjackPayout = 1.5,
  }) : assert(deckCount > 0, 'A shoe needs at least one deck.'),
       assert(
         penetration >= 0.5 && penetration <= 0.9,
         'Penetration is expressed as 0.5-0.9.',
       ),
       assert(maxSplitHands >= 1, 'At least one hand must be playable.');

  /// Deck counts the simulator offers.
  static const List<int> availableDeckCounts = <int>[1, 2, 4, 6, 8];

  final int deckCount;

  /// When true the dealer draws on soft 17 (H17), which is worse for the
  /// player and shifts a handful of strategy decisions.
  final bool dealerHitsSoft17;

  final bool doubleAfterSplit;
  final bool surrenderAllowed;

  /// When false, doubling is restricted to hard 9, 10 and 11.
  final bool doubleOnAnyTwoCards;

  final int maxSplitHands;
  final bool resplitAces;

  /// Fraction of the shoe dealt before the cut card, 0.5 to 0.9.
  final double penetration;

  /// Payout multiplier for a natural: 1.5 is 3:2, 1.2 is 6:5.
  final double blackjackPayout;

  String get dealerRuleLabel => dealerHitsSoft17 ? 'H17' : 'S17';

  String get penetrationLabel => '${(penetration * 100).round()}%';

  String get blackjackPayoutLabel =>
      blackjackPayout == 1.5 ? '3:2' : '${(blackjackPayout * 5).round()}:5';

  /// Short summary such as: 6 decks - S17 - DAS - Surrender - 75%.
  String get summary => <String>[
    '$deckCount deck${deckCount == 1 ? '' : 's'}',
    dealerRuleLabel,
    if (doubleAfterSplit) 'DAS' else 'No DAS',
    if (surrenderAllowed) 'Surrender',
    penetrationLabel,
  ].join(' · ');

  BlackjackRules copyWith({
    int? deckCount,
    bool? dealerHitsSoft17,
    bool? doubleAfterSplit,
    bool? surrenderAllowed,
    bool? doubleOnAnyTwoCards,
    int? maxSplitHands,
    bool? resplitAces,
    double? penetration,
    double? blackjackPayout,
  }) => BlackjackRules(
    deckCount: deckCount ?? this.deckCount,
    dealerHitsSoft17: dealerHitsSoft17 ?? this.dealerHitsSoft17,
    doubleAfterSplit: doubleAfterSplit ?? this.doubleAfterSplit,
    surrenderAllowed: surrenderAllowed ?? this.surrenderAllowed,
    doubleOnAnyTwoCards: doubleOnAnyTwoCards ?? this.doubleOnAnyTwoCards,
    maxSplitHands: maxSplitHands ?? this.maxSplitHands,
    resplitAces: resplitAces ?? this.resplitAces,
    penetration: penetration ?? this.penetration,
    blackjackPayout: blackjackPayout ?? this.blackjackPayout,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlackjackRules &&
          other.deckCount == deckCount &&
          other.dealerHitsSoft17 == dealerHitsSoft17 &&
          other.doubleAfterSplit == doubleAfterSplit &&
          other.surrenderAllowed == surrenderAllowed &&
          other.doubleOnAnyTwoCards == doubleOnAnyTwoCards &&
          other.maxSplitHands == maxSplitHands &&
          other.resplitAces == resplitAces &&
          other.penetration == penetration &&
          other.blackjackPayout == blackjackPayout;

  @override
  int get hashCode => Object.hash(
    deckCount,
    dealerHitsSoft17,
    doubleAfterSplit,
    surrenderAllowed,
    doubleOnAnyTwoCards,
    maxSplitHands,
    resplitAces,
    penetration,
    blackjackPayout,
  );
}
