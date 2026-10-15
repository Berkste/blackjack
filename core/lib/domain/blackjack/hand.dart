import 'package:meta/meta.dart';

import '../models/playing_card.dart';

/// How a hand finished once the round is settled.
enum HandOutcome {
  pending('In play'),
  blackjack('Blackjack'),
  win('Win'),
  push('Push'),
  lose('Lose'),
  bust('Bust'),
  surrender('Surrendered');

  const HandOutcome(this.label);

  final String label;

  bool get isResolved => this != HandOutcome.pending;
}

/// An immutable blackjack hand.
///
/// Totals are derived rather than stored, so a hand can never disagree with
/// its own cards.
@immutable
class Hand {
  const Hand({
    this.cards = const <PlayingCard>[],
    this.bet = 0,
    this.isDoubled = false,
    this.isStood = false,
    this.isSurrendered = false,
    this.fromSplit = false,
    this.splitAces = false,
    this.outcome = HandOutcome.pending,
  });

  final List<PlayingCard> cards;

  /// Wager in educational units. The simulator never handles real money.
  final int bet;

  final bool isDoubled;
  final bool isStood;
  final bool isSurrendered;

  /// True when this hand was produced by splitting a pair, which disqualifies
  /// it from paying as a natural blackjack.
  final bool fromSplit;

  /// True when this hand came from splitting aces, which normally receives
  /// exactly one more card.
  final bool splitAces;

  final HandOutcome outcome;

  /// Total counting every ace as one.
  int get hardTotal =>
      cards.fold<int>(0, (int sum, PlayingCard c) => sum + c.lowValue);

  bool get hasAce => cards.any((PlayingCard c) => c.isAce);

  /// True when an ace can still be counted as eleven without busting.
  bool get isSoft => hasAce && hardTotal + 10 <= 21;

  /// Best total that does not bust.
  int get total => isSoft ? hardTotal + 10 : hardTotal;

  bool get isBust => hardTotal > 21;

  bool get isTwentyOne => total == 21;

  /// A natural: exactly two cards totalling 21, not produced by a split.
  bool get isBlackjack => cards.length == 2 && total == 21 && !fromSplit;

  /// Two cards of equal blackjack value, so 10-J counts as a pair.
  bool get isPair =>
      cards.length == 2 && cards[0].rank.highValue == cards[1].rank.highValue;

  /// Two cards of the exact same rank, which is what a strategy chart keys on.
  bool get isRankPair => cards.length == 2 && cards[0].rank == cards[1].rank;

  bool get isEmpty => cards.isEmpty;

  int get cardCount => cards.length;

  /// Total wagered on this hand once doubling is taken into account.
  int get totalWager => isDoubled ? bet * 2 : bet;

  /// True when the player can no longer act on this hand.
  bool get isFinished =>
      isStood || isSurrendered || isBust || isDoubled || outcome.isResolved;

  /// Display total, such as 17, Soft 18 or Blackjack.
  String get displayTotal {
    if (isBlackjack) return 'Blackjack';
    if (isBust) return 'Bust $hardTotal';
    if (isSoft) return 'Soft $total';
    return '$total';
  }

  Hand add(PlayingCard card) => copyWith(cards: <PlayingCard>[...cards, card]);

  Hand copyWith({
    List<PlayingCard>? cards,
    int? bet,
    bool? isDoubled,
    bool? isStood,
    bool? isSurrendered,
    bool? fromSplit,
    bool? splitAces,
    HandOutcome? outcome,
  }) => Hand(
    cards: cards ?? this.cards,
    bet: bet ?? this.bet,
    isDoubled: isDoubled ?? this.isDoubled,
    isStood: isStood ?? this.isStood,
    isSurrendered: isSurrendered ?? this.isSurrendered,
    fromSplit: fromSplit ?? this.fromSplit,
    splitAces: splitAces ?? this.splitAces,
    outcome: outcome ?? this.outcome,
  );

  @override
  String toString() =>
      '${cards.map((PlayingCard c) => c.shortLabel).join(' ')} ($displayTotal)';
}
