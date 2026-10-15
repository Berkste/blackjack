import 'package:meta/meta.dart';

import 'basic_strategy.dart';

/// Whether a deviation switches on at or above its index, or at or below it.
enum DeviationDirection {
  atOrAbove('at or above'),
  atOrBelow('at or below');

  const DeviationDirection(this.label);

  final String label;
}

/// A count-based departure from basic strategy.
///
/// Deviations are only meaningful once basic strategy is automatic; playing
/// them without that foundation costs more than it gains.
@immutable
class CountDeviation {
  const CountDeviation({
    required this.id,
    required this.handLabel,
    required this.dealerUpcard,
    required this.index,
    required this.direction,
    required this.deviationAction,
    required this.baseAction,
    required this.explanation,
    this.playerTotal,
    this.isPair = false,
    this.isInsurance = false,
  });

  final String id;

  /// Player hand as shown on an index card, such as `16` or `10,10`.
  final String handLabel;

  /// Dealer upcard value, `11` for an ace.
  final int dealerUpcard;

  /// True-count threshold at which the deviation applies.
  final double index;

  final DeviationDirection direction;

  /// What to do once the threshold is crossed.
  final StrategyAction deviationAction;

  /// What basic strategy would do without a count.
  final StrategyAction baseAction;

  final String explanation;

  /// Hard total this applies to, when it is a total rather than a pair.
  final int? playerTotal;

  final bool isPair;

  /// Insurance is a side bet, not a playing decision, so it is flagged.
  final bool isInsurance;

  String get dealerLabel => BasicStrategyEngine.upcardLabel(dealerUpcard);

  /// Title used in lists, e.g. `16 vs 10`.
  String get title => isInsurance ? 'Insurance' : '$handLabel vs $dealerLabel';

  /// Index expressed the way counters memorise it, e.g. `TC >= +4`.
  String get indexLabel {
    final String sign = index > 0 ? '+' : '';
    final String value = index == index.roundToDouble()
        ? index.toStringAsFixed(0)
        : '$index';
    final String comparator = direction == DeviationDirection.atOrAbove
        ? '≥'
        : '≤';
    return 'TC $comparator $sign$value';
  }

  /// True when [trueCount] has crossed this deviation's threshold.
  bool appliesAt(double trueCount) => direction == DeviationDirection.atOrAbove
      ? trueCount >= index
      : trueCount <= index;
}

/// The Illustrious 18: the highest-value Hi-Lo playing deviations.
abstract final class CountDeviations {
  static const CountDeviation insurance = CountDeviation(
    id: 'insurance',
    handLabel: 'Any hand',
    dealerUpcard: 11,
    index: 3,
    direction: DeviationDirection.atOrAbove,
    deviationAction: StrategyAction.stand,
    baseAction: StrategyAction.hit,
    isInsurance: true,
    explanation:
        'Insurance is a bet that the hole card is a ten. It needs the shoe to '
        'be richer than one ten in three to break even, which happens at a '
        'true count of +3. It is the single most valuable index there is.',
  );

  /// Every deviation, insurance first.
  static const List<CountDeviation> all = <CountDeviation>[
    insurance,
    CountDeviation(
      id: '16v10',
      handLabel: '16',
      playerTotal: 16,
      dealerUpcard: 10,
      index: 0,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.stand,
      baseAction: StrategyAction.hit,
      explanation:
          'The most frequent deviation of all. 16 against a ten is close to a '
          'coin flip, so any positive count is enough to make standing better '
          'than drawing into a deck full of tens.',
    ),
    CountDeviation(
      id: '15v10',
      handLabel: '15',
      playerTotal: 15,
      dealerUpcard: 10,
      index: 4,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.stand,
      baseAction: StrategyAction.hit,
      explanation:
          'Same idea as 16 vs 10 but you have one more drawing card to work '
          'with, so it takes a stronger count before standing wins out.',
    ),
    CountDeviation(
      id: '10-10v5',
      handLabel: '10,10',
      dealerUpcard: 5,
      isPair: true,
      index: 5,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.split,
      baseAction: StrategyAction.stand,
      explanation:
          'Breaking up twenty feels wrong, and it is wrong at a neutral count. '
          'At +5 the dealer busts often enough that two hands starting with a '
          'ten beat one twenty.',
    ),
    CountDeviation(
      id: '10-10v6',
      handLabel: '10,10',
      dealerUpcard: 6,
      isPair: true,
      index: 4,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.split,
      baseAction: StrategyAction.stand,
      explanation:
          'A six is the dealer’s worst upcard, so the threshold for '
          'splitting tens is a little lower than against a five.',
    ),
    CountDeviation(
      id: '10v10',
      handLabel: '10',
      playerTotal: 10,
      dealerUpcard: 10,
      index: 4,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.doubleDown,
      baseAction: StrategyAction.hit,
      explanation:
          'A ten-rich shoe makes your twenty far more likely, which is worth '
          'doubling for even against the dealer’s strongest upcard.',
    ),
    CountDeviation(
      id: '12v3',
      handLabel: '12',
      playerTotal: 12,
      dealerUpcard: 3,
      index: 2,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.stand,
      baseAction: StrategyAction.hit,
      explanation:
          'Twelve busts on any ten. Once the shoe is ten-rich, standing and '
          'letting a weak dealer upcard break is the better side of the bet.',
    ),
    CountDeviation(
      id: '12v2',
      handLabel: '12',
      playerTotal: 12,
      dealerUpcard: 2,
      index: 3,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.stand,
      baseAction: StrategyAction.hit,
      explanation:
          'A deuce is the dealer’s strongest of the weak upcards, so it '
          'takes a higher count than 12 vs 3 before standing pays.',
    ),
    CountDeviation(
      id: '11vA',
      handLabel: '11',
      playerTotal: 11,
      dealerUpcard: 11,
      index: 1,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.doubleDown,
      baseAction: StrategyAction.hit,
      explanation:
          'Against an ace this is nearly a coin flip at a neutral count. Any '
          'ten-rich shoe tips it far enough to double.',
    ),
    CountDeviation(
      id: '9v2',
      handLabel: '9',
      playerTotal: 9,
      dealerUpcard: 2,
      index: 1,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.doubleDown,
      baseAction: StrategyAction.hit,
      explanation:
          'Nine against a deuce is a marginal double at a neutral count and a '
          'clear one as soon as the count turns positive.',
    ),
    CountDeviation(
      id: '10vA',
      handLabel: '10',
      playerTotal: 10,
      dealerUpcard: 11,
      index: 4,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.doubleDown,
      baseAction: StrategyAction.hit,
      explanation:
          'The ace is dangerous, so the shoe has to be strongly ten-rich '
          'before doubling ten against it becomes correct.',
    ),
    CountDeviation(
      id: '9v7',
      handLabel: '9',
      playerTotal: 9,
      dealerUpcard: 7,
      index: 3,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.doubleDown,
      baseAction: StrategyAction.hit,
      explanation:
          'A seven makes seventeen very often. You need a ten-rich shoe to '
          'expect the nineteen or twenty that beats it.',
    ),
    CountDeviation(
      id: '16v9',
      handLabel: '16',
      playerTotal: 16,
      dealerUpcard: 9,
      index: 5,
      direction: DeviationDirection.atOrAbove,
      deviationAction: StrategyAction.stand,
      baseAction: StrategyAction.hit,
      explanation:
          'The nine version of 16 vs 10, but the dealer is weaker, so the '
          'index sits much higher.',
    ),
    CountDeviation(
      id: '13v2',
      handLabel: '13',
      playerTotal: 13,
      dealerUpcard: 2,
      index: -1,
      direction: DeviationDirection.atOrBelow,
      deviationAction: StrategyAction.hit,
      baseAction: StrategyAction.stand,
      explanation:
          'A negative count means small cards are left. The dealer breaks less '
          'often, and you are safer drawing than waiting.',
    ),
    CountDeviation(
      id: '12v4',
      handLabel: '12',
      playerTotal: 12,
      dealerUpcard: 4,
      index: 0,
      direction: DeviationDirection.atOrBelow,
      deviationAction: StrategyAction.hit,
      baseAction: StrategyAction.stand,
      explanation:
          'Standing on twelve only pays while the shoe is ten-rich. At zero or '
          'below, take the card.',
    ),
    CountDeviation(
      id: '12v5',
      handLabel: '12',
      playerTotal: 12,
      dealerUpcard: 5,
      index: -2,
      direction: DeviationDirection.atOrBelow,
      deviationAction: StrategyAction.hit,
      baseAction: StrategyAction.stand,
      explanation:
          'A five is a weak upcard, so it takes a clearly negative count '
          'before hitting twelve becomes correct.',
    ),
    CountDeviation(
      id: '12v6',
      handLabel: '12',
      playerTotal: 12,
      dealerUpcard: 6,
      index: -1,
      direction: DeviationDirection.atOrBelow,
      deviationAction: StrategyAction.hit,
      baseAction: StrategyAction.stand,
      explanation:
          'Even against the dealer’s worst card, a small-card-rich shoe '
          'means fewer dealer busts and a safer draw for you.',
    ),
    CountDeviation(
      id: '13v3',
      handLabel: '13',
      playerTotal: 13,
      dealerUpcard: 3,
      index: -2,
      direction: DeviationDirection.atOrBelow,
      deviationAction: StrategyAction.hit,
      baseAction: StrategyAction.stand,
      explanation:
          'The mirror of 13 vs 2, one upcard weaker, so the index is lower.',
    ),
  ];

  /// The deviations taught first, in the order most trainers recommend.
  static List<CountDeviation> get coreFour => <CountDeviation>[
    all.firstWhere((CountDeviation d) => d.id == 'insurance'),
    all.firstWhere((CountDeviation d) => d.id == '16v10'),
    all.firstWhere((CountDeviation d) => d.id == '15v10'),
    all.firstWhere((CountDeviation d) => d.id == '10v10'),
  ];

  /// Deviation covering a hard total against an upcard, if one exists.
  static CountDeviation? forTotal(int playerTotal, int dealerUpcard) {
    for (final CountDeviation deviation in all) {
      if (!deviation.isInsurance &&
          !deviation.isPair &&
          deviation.playerTotal == playerTotal &&
          deviation.dealerUpcard == dealerUpcard) {
        return deviation;
      }
    }
    return null;
  }

  /// The deviation to apply right now, or `null` when basic strategy stands.
  static CountDeviation? activeFor({
    required int playerTotal,
    required int dealerUpcard,
    required double trueCount,
  }) {
    final CountDeviation? deviation = forTotal(playerTotal, dealerUpcard);
    if (deviation == null) return null;
    return deviation.appliesAt(trueCount) ? deviation : null;
  }
}
