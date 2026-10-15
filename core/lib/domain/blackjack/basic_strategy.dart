import 'package:meta/meta.dart';

import '../models/playing_card.dart';
import 'blackjack_rules.dart';
import 'hand.dart';

/// A move the player can make.
enum StrategyAction {
  hit('Hit', 'H'),
  stand('Stand', 'S'),
  doubleDown('Double', 'D'),
  split('Split', 'P'),
  surrender('Surrender', 'R');

  const StrategyAction(this.label, this.code);

  final String label;
  final String code;
}

/// One cell of a basic-strategy chart.
///
/// A cell names a preferred action plus the fallback used when the table
/// does not allow it — doubling on three cards, for instance.
enum StrategyCell {
  hit('H', 'Hit', StrategyAction.hit, StrategyAction.hit),
  stand('S', 'Stand', StrategyAction.stand, StrategyAction.stand),
  doubleElseHit(
    'D',
    'Double, otherwise hit',
    StrategyAction.doubleDown,
    StrategyAction.hit,
  ),
  doubleElseStand(
    'Ds',
    'Double, otherwise stand',
    StrategyAction.doubleDown,
    StrategyAction.stand,
  ),
  split('P', 'Split', StrategyAction.split, StrategyAction.hit),
  splitIfDas(
    'P*',
    'Split if double after split is allowed',
    StrategyAction.split,
    StrategyAction.hit,
  ),
  surrenderElseHit(
    'R',
    'Surrender, otherwise hit',
    StrategyAction.surrender,
    StrategyAction.hit,
  ),
  surrenderElseStand(
    'Rs',
    'Surrender, otherwise stand',
    StrategyAction.surrender,
    StrategyAction.stand,
  ),
  surrenderElseSplit(
    'Rp',
    'Surrender, otherwise split',
    StrategyAction.surrender,
    StrategyAction.split,
  );

  const StrategyCell(this.code, this.label, this.primary, this.fallback);

  final String code;
  final String label;
  final StrategyAction primary;
  final StrategyAction fallback;

  bool get requiresDas => this == StrategyCell.splitIfDas;
}

/// Which section of the chart a row belongs to.
enum StrategySection {
  hard('Hard totals', 'No ace, or an ace forced to count as one.'),
  soft('Soft totals', 'A hand holding an ace that can still count as eleven.'),
  pairs('Pairs', 'Two cards of the same rank, where splitting is an option.');

  const StrategySection(this.label, this.description);

  final String label;
  final String description;
}

/// One row of a rendered strategy chart.
@immutable
class StrategyChartRow {
  const StrategyChartRow({
    required this.label,
    required this.cells,
    required this.section,
  });

  /// Row header, such as `16`, `A,7` or `8,8`.
  final String label;

  /// One cell per entry of [BasicStrategyEngine.dealerUpcards].
  final List<StrategyCell> cells;

  final StrategySection section;
}

/// The decision the engine reached for a concrete situation.
@immutable
class StrategyDecision {
  const StrategyDecision({
    required this.action,
    required this.cell,
    required this.explanation,
  });

  /// The action to actually take at this table.
  final StrategyAction action;

  /// The ideal chart cell, before table restrictions were applied.
  final StrategyCell cell;

  final String explanation;

  /// True when a table restriction forced a different move than the chart's.
  bool get wasDowngraded => action != cell.primary;
}

/// Multi-deck basic strategy.
///
/// The tables below are the standard 4-8 deck charts, with the documented
/// H17 corrections applied when the rules call for them. The engine is pure:
/// it reads a hand and a rule set and returns a decision.
abstract final class BasicStrategyEngine {
  /// Dealer upcard values used as chart columns. `11` is an ace.
  static const List<int> dealerUpcards = <int>[2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

  /// Column header for a dealer upcard value.
  static String upcardLabel(int value) => value == 11 ? 'A' : '$value';

  /// Chart value of a dealer upcard: an ace counts as eleven.
  static int upcardValue(Rank rank) => rank.isAce ? 11 : rank.highValue;

  static const StrategyCell _h = StrategyCell.hit;
  static const StrategyCell _s = StrategyCell.stand;
  static const StrategyCell _d = StrategyCell.doubleElseHit;
  static const StrategyCell _ds = StrategyCell.doubleElseStand;
  static const StrategyCell _p = StrategyCell.split;
  static const StrategyCell _pd = StrategyCell.splitIfDas;
  static const StrategyCell _rh = StrategyCell.surrenderElseHit;
  static const StrategyCell _rs = StrategyCell.surrenderElseStand;
  static const StrategyCell _rp = StrategyCell.surrenderElseSplit;

  /// Hard totals, keyed by total. Columns follow [dealerUpcards].
  static const Map<int, List<StrategyCell>> _hardChart =
      <int, List<StrategyCell>>{
        5: <StrategyCell>[_h, _h, _h, _h, _h, _h, _h, _h, _h, _h],
        6: <StrategyCell>[_h, _h, _h, _h, _h, _h, _h, _h, _h, _h],
        7: <StrategyCell>[_h, _h, _h, _h, _h, _h, _h, _h, _h, _h],
        8: <StrategyCell>[_h, _h, _h, _h, _h, _h, _h, _h, _h, _h],
        9: <StrategyCell>[_h, _d, _d, _d, _d, _h, _h, _h, _h, _h],
        10: <StrategyCell>[_d, _d, _d, _d, _d, _d, _d, _d, _h, _h],
        11: <StrategyCell>[_d, _d, _d, _d, _d, _d, _d, _d, _d, _h],
        12: <StrategyCell>[_h, _h, _s, _s, _s, _h, _h, _h, _h, _h],
        13: <StrategyCell>[_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
        14: <StrategyCell>[_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
        15: <StrategyCell>[_s, _s, _s, _s, _s, _h, _h, _h, _rh, _h],
        16: <StrategyCell>[_s, _s, _s, _s, _s, _h, _h, _rh, _rh, _rh],
        17: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        18: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        19: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        20: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        21: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
      };

  /// Soft totals, keyed by the total with the ace counting as eleven.
  static const Map<int, List<StrategyCell>> _softChart =
      <int, List<StrategyCell>>{
        13: <StrategyCell>[_h, _h, _h, _d, _d, _h, _h, _h, _h, _h],
        14: <StrategyCell>[_h, _h, _h, _d, _d, _h, _h, _h, _h, _h],
        15: <StrategyCell>[_h, _h, _d, _d, _d, _h, _h, _h, _h, _h],
        16: <StrategyCell>[_h, _h, _d, _d, _d, _h, _h, _h, _h, _h],
        17: <StrategyCell>[_h, _d, _d, _d, _d, _h, _h, _h, _h, _h],
        18: <StrategyCell>[_ds, _ds, _ds, _ds, _ds, _s, _s, _h, _h, _h],
        19: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        20: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        21: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
      };

  /// Pairs, keyed by the blackjack value of one card. `11` is a pair of aces.
  static const Map<int, List<StrategyCell>> _pairChart =
      <int, List<StrategyCell>>{
        11: <StrategyCell>[_p, _p, _p, _p, _p, _p, _p, _p, _p, _p],
        10: <StrategyCell>[_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
        9: <StrategyCell>[_p, _p, _p, _p, _p, _s, _p, _p, _s, _s],
        8: <StrategyCell>[_p, _p, _p, _p, _p, _p, _p, _p, _p, _p],
        7: <StrategyCell>[_p, _p, _p, _p, _p, _p, _h, _h, _h, _h],
        6: <StrategyCell>[_pd, _p, _p, _p, _p, _h, _h, _h, _h, _h],
        5: <StrategyCell>[_d, _d, _d, _d, _d, _d, _d, _d, _h, _h],
        4: <StrategyCell>[_h, _h, _h, _pd, _pd, _h, _h, _h, _h, _h],
        3: <StrategyCell>[_pd, _pd, _p, _p, _p, _p, _h, _h, _h, _h],
        2: <StrategyCell>[_pd, _pd, _p, _p, _p, _p, _h, _h, _h, _h],
      };

  static int _columnFor(int upcard) {
    final int index = dealerUpcards.indexOf(upcard);
    assert(index >= 0, 'Dealer upcard $upcard is outside 2-11.');
    return index < 0 ? 0 : index;
  }

  /// Chart cell for a hard total.
  static StrategyCell hardCell(
    int total,
    int upcard, {
    bool dealerHitsSoft17 = false,
  }) {
    final int clamped = total.clamp(5, 21);
    final StrategyCell base = _hardChart[clamped]![_columnFor(upcard)];
    if (!dealerHitsSoft17) return base;
    // H17 corrections: the dealer busts less often and makes 17 more often.
    if (clamped == 11 && upcard == 11) return _d;
    if (clamped == 15 && upcard == 11) return _rh;
    if (clamped == 17 && upcard == 11) return _rs;
    return base;
  }

  /// Chart cell for a soft total, where [total] counts the ace as eleven.
  static StrategyCell softCell(
    int total,
    int upcard, {
    bool dealerHitsSoft17 = false,
  }) {
    final int clamped = total.clamp(13, 21);
    final StrategyCell base = _softChart[clamped]![_columnFor(upcard)];
    if (!dealerHitsSoft17) return base;
    if (clamped == 18 && upcard == 11) return _h;
    if (clamped == 19 && upcard == 6) return _ds;
    return base;
  }

  /// Chart cell for a pair, keyed by the value of a single card.
  static StrategyCell pairCell(
    int cardValue,
    int upcard, {
    bool dealerHitsSoft17 = false,
    bool surrenderAllowed = true,
  }) {
    final StrategyCell base = _pairChart[cardValue]![_columnFor(upcard)];
    if (dealerHitsSoft17 &&
        surrenderAllowed &&
        cardValue == 8 &&
        upcard == 11) {
      return _rp;
    }
    return base;
  }

  /// Every row of the chart for [section] under [rules].
  static List<StrategyChartRow> chartRows(
    StrategySection section,
    BlackjackRules rules,
  ) {
    switch (section) {
      case StrategySection.hard:
        return <StrategyChartRow>[
          for (int total = 8; total <= 17; total++)
            StrategyChartRow(
              label: '$total',
              section: section,
              cells: <StrategyCell>[
                for (final int up in dealerUpcards)
                  hardCell(total, up, dealerHitsSoft17: rules.dealerHitsSoft17),
              ],
            ),
        ];
      case StrategySection.soft:
        return <StrategyChartRow>[
          for (int total = 13; total <= 20; total++)
            StrategyChartRow(
              label: 'A,${total - 11}',
              section: section,
              cells: <StrategyCell>[
                for (final int up in dealerUpcards)
                  softCell(total, up, dealerHitsSoft17: rules.dealerHitsSoft17),
              ],
            ),
        ];
      case StrategySection.pairs:
        return <StrategyChartRow>[
          for (final int value in <int>[11, 10, 9, 8, 7, 6, 5, 4, 3, 2])
            StrategyChartRow(
              label: value == 11 ? 'A,A' : '$value,$value',
              section: section,
              cells: <StrategyCell>[
                for (final int up in dealerUpcards)
                  pairCell(
                    value,
                    up,
                    dealerHitsSoft17: rules.dealerHitsSoft17,
                    surrenderAllowed: rules.surrenderAllowed,
                  ),
              ],
            ),
        ];
    }
  }

  /// The correct basic-strategy play for [hand] against [dealerUpcard].
  ///
  /// [canDouble], [canSplit] and [canSurrender] describe what this table
  /// actually permits right now; the returned action always respects them.
  static StrategyDecision decide({
    required Hand hand,
    required Rank dealerUpcard,
    required BlackjackRules rules,
    bool canDouble = true,
    bool canSplit = true,
    bool canSurrender = true,
  }) {
    final int upcard = upcardValue(dealerUpcard);
    final StrategyCell cell = _cellFor(
      hand: hand,
      upcard: upcard,
      rules: rules,
      canSplit: canSplit,
    );
    final StrategyAction action = resolve(
      cell,
      rules: rules,
      canDouble: canDouble,
      canSplit: canSplit,
      canSurrender: canSurrender,
    );
    return StrategyDecision(
      action: action,
      cell: cell,
      explanation: explain(
        hand: hand,
        upcard: upcard,
        cell: cell,
        action: action,
      ),
    );
  }

  static StrategyCell _cellFor({
    required Hand hand,
    required int upcard,
    required BlackjackRules rules,
    required bool canSplit,
  }) {
    if (canSplit && hand.isPair) {
      final int cardValue = hand.cards.first.isAce
          ? 11
          : hand.cards.first.highValue;
      return pairCell(
        cardValue,
        upcard,
        dealerHitsSoft17: rules.dealerHitsSoft17,
        surrenderAllowed: rules.surrenderAllowed,
      );
    }
    if (hand.isSoft) {
      return softCell(
        hand.total,
        upcard,
        dealerHitsSoft17: rules.dealerHitsSoft17,
      );
    }
    return hardCell(
      hand.total,
      upcard,
      dealerHitsSoft17: rules.dealerHitsSoft17,
    );
  }

  /// Reduces a chart cell to an action this table allows.
  static StrategyAction resolve(
    StrategyCell cell, {
    required BlackjackRules rules,
    bool canDouble = true,
    bool canSplit = true,
    bool canSurrender = true,
  }) {
    if (cell.requiresDas && !rules.doubleAfterSplit) {
      return StrategyAction.hit;
    }
    switch (cell.primary) {
      case StrategyAction.doubleDown:
        return canDouble ? StrategyAction.doubleDown : cell.fallback;
      case StrategyAction.split:
        return canSplit ? StrategyAction.split : cell.fallback;
      case StrategyAction.surrender:
        if (canSurrender && rules.surrenderAllowed) {
          return StrategyAction.surrender;
        }
        if (cell.fallback == StrategyAction.split) {
          return canSplit ? StrategyAction.split : StrategyAction.hit;
        }
        return cell.fallback;
      case StrategyAction.hit:
      case StrategyAction.stand:
        return cell.primary;
    }
  }

  /// Basic strategy never takes insurance; only a high true count does.
  static bool shouldTakeInsurance(double trueCount) => trueCount >= 3;

  /// Plain-language reasoning for a decision, used by the lesson and the
  /// simulator's coaching panel.
  static String explain({
    required Hand hand,
    required int upcard,
    required StrategyCell cell,
    required StrategyAction action,
  }) {
    final String dealer = 'dealer ${upcardLabel(upcard)}';
    final String player = hand.isPair && hand.cards.length == 2
        ? 'a pair of ${hand.cards.first.rank.label.toLowerCase()}s'
        : hand.isSoft
        ? 'soft ${hand.total}'
        : 'hard ${hand.total}';
    final bool dealerWeak = upcard >= 2 && upcard <= 6;
    switch (action) {
      case StrategyAction.stand:
        return dealerWeak
            ? 'With $player against a $dealer, let the dealer take the risk — '
                  'a weak upcard busts often enough that drawing costs you more '
                  'than standing.'
            : 'With $player against a $dealer, standing loses least. Drawing '
                  'busts too often to be worth the extra equity.';
      case StrategyAction.hit:
        return 'With $player against a $dealer, you are behind if you stand. '
            'Taking a card is the lower-loss play.';
      case StrategyAction.doubleDown:
        return 'With $player against a $dealer you are the favourite, so put '
            'more money out while the edge is yours — one card only.';
      case StrategyAction.split:
        return 'A pair of ${hand.cards.first.rank.label.toLowerCase()}s plays '
            'better as two hands against a $dealer than as one bad total.';
      case StrategyAction.surrender:
        return 'With $player against a $dealer you lose more than half the '
            'time. Giving back half the bet is cheaper than playing it out.';
    }
  }
}
