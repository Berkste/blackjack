import 'package:meta/meta.dart';

/// The four suits of a standard 52-card deck.
enum Suit {
  hearts('♥', 'Hearts', isRed: true),
  diamonds('♦', 'Diamonds', isRed: true),
  clubs('♣', 'Clubs', isRed: false),
  spades('♠', 'Spades', isRed: false);

  const Suit(this.symbol, this.label, {required this.isRed});

  /// Unicode pip used by the card widgets.
  final String symbol;

  /// Human readable name, used for semantics labels.
  final String label;

  /// Whether the suit is printed in red on a physical card.
  final bool isRed;
}

/// The thirteen ranks of a standard 52-card deck.
enum Rank {
  ace('A', 'Ace', 11),
  two('2', 'Two', 2),
  three('3', 'Three', 3),
  four('4', 'Four', 4),
  five('5', 'Five', 5),
  six('6', 'Six', 6),
  seven('7', 'Seven', 7),
  eight('8', 'Eight', 8),
  nine('9', 'Nine', 9),
  ten('10', 'Ten', 10),
  jack('J', 'Jack', 10),
  queen('Q', 'Queen', 10),
  king('K', 'King', 10);

  const Rank(this.symbol, this.label, this.highValue);

  /// Short symbol rendered on the face of a card.
  final String symbol;

  /// Human readable name, used for semantics labels and explanations.
  final String label;

  /// Blackjack value counting an ace as eleven.
  final int highValue;

  bool get isAce => this == Rank.ace;

  /// True for 10, J, Q, K — the ranks a basic-strategy chart treats as "ten".
  bool get isTenValued => !isAce && highValue == 10;

  /// Blackjack value counting an ace as one.
  int get lowValue => isAce ? 1 : highValue;

  /// Hi-Lo tag: `2-6 => +1`, `7-9 => 0`, `10-A => -1`.
  int get hiLoValue {
    switch (this) {
      case Rank.two:
      case Rank.three:
      case Rank.four:
      case Rank.five:
      case Rank.six:
        return 1;
      case Rank.seven:
      case Rank.eight:
      case Rank.nine:
        return 0;
      case Rank.ten:
      case Rank.jack:
      case Rank.queen:
      case Rank.king:
      case Rank.ace:
        return -1;
    }
  }
}

/// Which bucket of the Hi-Lo system a card falls in.
enum HiLoGroup {
  low('Low cards', '2 3 4 5 6', 1),
  neutral('Neutral cards', '7 8 9', 0),
  high('High cards', '10 J Q K A', -1);

  const HiLoGroup(this.label, this.ranks, this.value);

  final String label;
  final String ranks;
  final int value;

  static HiLoGroup forValue(int value) {
    if (value > 0) return HiLoGroup.low;
    if (value < 0) return HiLoGroup.high;
    return HiLoGroup.neutral;
  }
}

/// An immutable playing card.
@immutable
class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  final Rank rank;
  final Suit suit;

  /// Hi-Lo tag for this card.
  int get hiLoValue => rank.hiLoValue;

  HiLoGroup get hiLoGroup => HiLoGroup.forValue(hiLoValue);

  bool get isAce => rank.isAce;

  bool get isTenValued => rank.isTenValued;

  /// Blackjack value counting an ace as eleven.
  int get highValue => rank.highValue;

  /// Blackjack value counting an ace as one.
  int get lowValue => rank.lowValue;

  /// Compact label such as `5♠` used in count breakdowns.
  String get shortLabel => '${rank.symbol}${suit.symbol}';

  /// Screen-reader friendly label such as `Five of Spades`.
  String get accessibleLabel => '${rank.label} of ${suit.label}';

  /// Stable identifier such as `5S`, handy for keys and test fixtures.
  String get code => '${rank.symbol}${suit.name[0].toUpperCase()}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => shortLabel;
}
