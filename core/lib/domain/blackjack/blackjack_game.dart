import 'package:meta/meta.dart';

import '../counting/hi_lo_counter.dart';
import '../counting/true_count_calculator.dart';
import '../models/playing_card.dart';
import '../models/shoe.dart';
import 'basic_strategy.dart';
import 'blackjack_rules.dart';
import 'hand.dart';

/// Where a round currently is.
enum GamePhase {
  /// Waiting for the player to place a bet.
  betting('Place your bet'),

  /// The insurance decision, offered only when the dealer shows an ace.
  insurance('Insurance?'),

  /// The player is acting on one of their hands.
  playerTurn('Your move'),

  /// The dealer is drawing.
  dealerTurn('Dealer draws'),

  /// The round is over and paid.
  settled('Round complete');

  const GamePhase(this.label);

  final String label;
}

/// An immutable view of the table, safe to hand to the UI layer.
@immutable
class RoundSnapshot {
  const RoundSnapshot({
    required this.phase,
    required this.dealerHand,
    required this.playerHands,
    required this.activeHandIndex,
    required this.holeCardHidden,
    required this.runningCount,
    required this.trueCount,
    required this.decksRemaining,
    required this.cardsRemaining,
    required this.bankroll,
    required this.baseBet,
    required this.insuranceBet,
    required this.availableActions,
    required this.handNumber,
    required this.shoeNumber,
    required this.shufflePending,
    required this.netResult,
    this.message,
  });

  final GamePhase phase;
  final Hand dealerHand;
  final List<Hand> playerHands;

  /// Index into [playerHands] of the hand being played.
  final int activeHandIndex;

  /// True while the dealer's second card is face down.
  final bool holeCardHidden;

  final int runningCount;
  final double trueCount;
  final double decksRemaining;
  final int cardsRemaining;

  /// Educational units, never real currency.
  final int bankroll;
  final int baseBet;
  final int insuranceBet;

  final List<StrategyAction> availableActions;
  final int handNumber;
  final int shoeNumber;

  /// True once the cut card has been passed and the shoe reshuffles next hand.
  final bool shufflePending;

  /// Units won or lost on the round just settled.
  final int netResult;

  final String? message;

  Hand? get activeHand =>
      activeHandIndex >= 0 && activeHandIndex < playerHands.length
      ? playerHands[activeHandIndex]
      : null;

  /// The dealer's face-up card, if any has been dealt.
  PlayingCard? get dealerUpcard =>
      dealerHand.cards.isEmpty ? null : dealerHand.cards.first;

  /// Dealer cards as the player sees them, hole card excluded while hidden.
  List<PlayingCard> get visibleDealerCards => holeCardHidden
      ? dealerHand.cards.take(1).toList(growable: false)
      : dealerHand.cards;

  /// Dealer total as the player sees it.
  String get visibleDealerTotal => holeCardHidden
      ? '${Hand(cards: visibleDealerCards).total}'
      : dealerHand.displayTotal;

  bool get isRoundOver => phase == GamePhase.settled;

  bool get hasSplitHands => playerHands.length > 1;

  String get trueCountLabel => TrueCountCalculator.format(trueCount);

  String get runningCountLabel =>
      TrueCountCalculator.formatRunning(runningCount);

  String get decksRemainingLabel => decksRemaining.toStringAsFixed(1);
}

/// The blackjack engine.
///
/// Deliberately free of Flutter: it owns a shoe, a Hi-Lo counter and the
/// round state machine, and exposes immutable [RoundSnapshot]s. Seed the
/// shoe to replay an exact sequence in a test.
class BlackjackGame {
  BlackjackGame({
    BlackjackRules rules = const BlackjackRules(),
    int bankroll = 1000,
    int? seed,
  }) : _rules = rules,
       _bankroll = bankroll,
       _startingBankroll = bankroll,
       _shoe = Shoe(
         deckCount: rules.deckCount,
         penetration: rules.penetration,
         seed: seed,
       ),
       _counter = HiLoCounter(deckCount: rules.deckCount);

  BlackjackRules _rules;
  Shoe _shoe;
  HiLoCounter _counter;

  int _bankroll;
  final int _startingBankroll;
  int _baseBet = 10;
  int _insuranceBet = 0;
  int _netResult = 0;
  int _handNumber = 0;

  GamePhase _phase = GamePhase.betting;
  Hand _dealerHand = const Hand();
  List<Hand> _playerHands = <Hand>[];
  int _activeHandIndex = 0;
  bool _holeCardHidden = true;
  String? _message;

  BlackjackRules get rules => _rules;
  Shoe get shoe => _shoe;
  HiLoCounter get counter => _counter;
  int get bankroll => _bankroll;
  int get startingBankroll => _startingBankroll;
  int get handNumber => _handNumber;
  GamePhase get phase => _phase;

  /// Exact true count from the running count and the shoe's real depth.
  double get trueCount =>
      TrueCountCalculator.raw(_counter.runningCount, _shoe.decksRemaining);

  /// Replaces the rules and starts a fresh shoe.
  void applyRules(BlackjackRules rules, {int? seed}) {
    _rules = rules;
    _shoe = Shoe(
      deckCount: rules.deckCount,
      penetration: rules.penetration,
      seed: seed,
    );
    _counter = HiLoCounter(deckCount: rules.deckCount);
    _resetTable();
    _phase = GamePhase.betting;
    _message = null;
  }

  /// Starts a new shoe, keeping the rules and bankroll.
  void newShoe({int? seed}) => applyRules(_rules, seed: seed);

  /// Resets bankroll and statistics but keeps the shoe.
  void resetBankroll() => _bankroll = _startingBankroll;

  /// Deals a new round for [bet] units.
  ///
  /// Reshuffles first when the cut card was passed on the previous round.
  RoundSnapshot startRound(int bet) {
    if (_shoe.isCutCardReached || _shoe.cardsRemaining < 20) {
      _shoe.reshuffle();
      _counter.reset();
      _message = 'New shoe — the count resets to zero.';
    } else {
      _message = null;
    }

    _baseBet = bet.clamp(1, _bankroll <= 0 ? 1 : _bankroll);
    _bankroll -= _baseBet;
    _insuranceBet = 0;
    _netResult = 0;
    _handNumber++;
    _resetTable();

    // Real deal order: player, dealer up, player, dealer hole.
    final PlayingCard playerOne = _drawCounted();
    final PlayingCard dealerUp = _drawCounted();
    final PlayingCard playerTwo = _drawCounted();
    final PlayingCard hole = _drawUncounted();

    _playerHands = <Hand>[
      Hand(cards: <PlayingCard>[playerOne, playerTwo], bet: _baseBet),
    ];
    _dealerHand = Hand(cards: <PlayingCard>[dealerUp, hole]);
    _activeHandIndex = 0;
    _holeCardHidden = true;

    if (dealerUp.isAce) {
      _phase = GamePhase.insurance;
      return snapshot;
    }

    _phase = GamePhase.playerTurn;
    _checkForNaturals();
    return snapshot;
  }

  /// Takes insurance for half the base bet.
  RoundSnapshot takeInsurance() {
    if (_phase != GamePhase.insurance) return snapshot;
    final int wager = (_baseBet / 2).floor();
    if (wager > 0 && _bankroll >= wager) {
      _insuranceBet = wager;
      _bankroll -= wager;
    }
    return _resolveInsurance();
  }

  /// Declines insurance and continues the round.
  RoundSnapshot declineInsurance() {
    if (_phase != GamePhase.insurance) return snapshot;
    return _resolveInsurance();
  }

  RoundSnapshot _resolveInsurance() {
    final bool dealerHasBlackjack = _dealerHand.isBlackjack;
    if (_insuranceBet > 0) {
      if (dealerHasBlackjack) {
        // Insurance pays 2:1 — the stake plus twice the stake back.
        _bankroll += _insuranceBet * 3;
        _netResult += _insuranceBet * 2;
        _message = 'Insurance paid 2:1.';
      } else {
        _netResult -= _insuranceBet;
        _message = 'Insurance lost.';
      }
    }
    _phase = GamePhase.playerTurn;
    _checkForNaturals();
    return snapshot;
  }

  void _checkForNaturals() {
    final Hand player = _playerHands.first;
    if (!player.isBlackjack && !_dealerHand.isBlackjack) return;
    _revealHoleCard();
    _settle();
  }

  /// Draws one card to the active hand.
  RoundSnapshot hit() {
    if (_phase != GamePhase.playerTurn) return snapshot;
    Hand hand = _activeHand.add(_drawCounted());
    if (hand.isBust) {
      hand = hand.copyWith(outcome: HandOutcome.bust);
    }
    _replaceActiveHand(hand);
    if (hand.isBust || hand.isTwentyOne) {
      return _advanceHand();
    }
    return snapshot;
  }

  /// Ends action on the active hand.
  RoundSnapshot stand() {
    if (_phase != GamePhase.playerTurn) return snapshot;
    _replaceActiveHand(_activeHand.copyWith(isStood: true));
    return _advanceHand();
  }

  /// Doubles the wager and draws exactly one card.
  RoundSnapshot doubleDown() {
    if (_phase != GamePhase.playerTurn) return snapshot;
    if (!_canDouble(_activeHand)) return snapshot;
    _bankroll -= _activeHand.bet;
    Hand hand = _activeHand.copyWith(isDoubled: true).add(_drawCounted());
    if (hand.isBust) {
      hand = hand.copyWith(outcome: HandOutcome.bust);
    }
    _replaceActiveHand(hand);
    return _advanceHand();
  }

  /// Splits the active pair into two hands.
  RoundSnapshot split() {
    if (_phase != GamePhase.playerTurn) return snapshot;
    final Hand hand = _activeHand;
    if (!_canSplit(hand)) return snapshot;

    _bankroll -= hand.bet;
    final bool aces = hand.cards.first.isAce;
    final Hand first = Hand(
      cards: <PlayingCard>[hand.cards.first],
      bet: hand.bet,
      fromSplit: true,
      splitAces: aces,
    );
    final Hand second = Hand(
      cards: <PlayingCard>[hand.cards.last],
      bet: hand.bet,
      fromSplit: true,
      splitAces: aces,
    );
    _playerHands = <Hand>[
      ..._playerHands.sublist(0, _activeHandIndex),
      first,
      second,
      ..._playerHands.sublist(_activeHandIndex + 1),
    ];
    _dealToActiveHand();
    if (aces) {
      _replaceActiveHand(_activeHand.copyWith(isStood: true));
      return _advanceHand();
    }
    return snapshot;
  }

  /// Gives up the hand for half the wager.
  RoundSnapshot surrender() {
    if (_phase != GamePhase.playerTurn) return snapshot;
    if (!_canSurrender(_activeHand)) return snapshot;
    _replaceActiveHand(
      _activeHand.copyWith(isSurrendered: true, outcome: HandOutcome.surrender),
    );
    return _advanceHand();
  }

  /// Basic-strategy advice for the active hand, for the coaching overlay.
  StrategyDecision? get advice {
    final PlayingCard? upcard = _dealerHand.cards.isEmpty
        ? null
        : _dealerHand.cards.first;
    if (upcard == null || _phase != GamePhase.playerTurn) return null;
    final Hand hand = _activeHand;
    return BasicStrategyEngine.decide(
      hand: hand,
      dealerUpcard: upcard.rank,
      rules: _rules,
      canDouble: _canDouble(hand),
      canSplit: _canSplit(hand),
      canSurrender: _canSurrender(hand),
    );
  }

  /// Immutable view of the table right now.
  RoundSnapshot get snapshot => RoundSnapshot(
    phase: _phase,
    dealerHand: _dealerHand,
    playerHands: List<Hand>.unmodifiable(_playerHands),
    activeHandIndex: _activeHandIndex,
    holeCardHidden: _holeCardHidden,
    runningCount: _counter.runningCount,
    trueCount: trueCount,
    decksRemaining: _shoe.decksRemaining,
    cardsRemaining: _shoe.cardsRemaining,
    bankroll: _bankroll,
    baseBet: _baseBet,
    insuranceBet: _insuranceBet,
    availableActions: _availableActions(),
    handNumber: _handNumber,
    shoeNumber: _shoe.shuffleNumber,
    shufflePending: _shoe.isCutCardReached,
    netResult: _netResult,
    message: _message,
  );

  // ---------------------------------------------------------------- internals

  Hand get _activeHand => _playerHands[_activeHandIndex];

  void _resetTable() {
    _dealerHand = const Hand();
    _playerHands = <Hand>[];
    _activeHandIndex = 0;
    _holeCardHidden = true;
  }

  PlayingCard _drawCounted() {
    final PlayingCard card = _shoe.deal();
    _counter.addCard(card);
    _counter.syncCardsSeen(_shoe.cardsDealt);
    return card;
  }

  /// The hole card leaves the shoe but is not counted until it is exposed.
  PlayingCard _drawUncounted() {
    final PlayingCard card = _shoe.deal();
    _counter.syncCardsSeen(_shoe.cardsDealt);
    return card;
  }

  void _replaceActiveHand(Hand hand) {
    _playerHands = <Hand>[
      ..._playerHands.sublist(0, _activeHandIndex),
      hand,
      ..._playerHands.sublist(_activeHandIndex + 1),
    ];
  }

  void _dealToActiveHand() {
    _replaceActiveHand(_activeHand.add(_drawCounted()));
  }

  bool _canDouble(Hand hand) {
    if (hand.cards.length != 2 || hand.isDoubled) return false;
    if (hand.fromSplit && !_rules.doubleAfterSplit) return false;
    if (hand.splitAces) return false;
    if (!_rules.doubleOnAnyTwoCards && !<int>[9, 10, 11].contains(hand.total)) {
      return false;
    }
    return _bankroll >= hand.bet;
  }

  bool _canSplit(Hand hand) {
    if (!hand.isPair) return false;
    if (_playerHands.length >= _rules.maxSplitHands) return false;
    if (hand.splitAces && !_rules.resplitAces) return false;
    return _bankroll >= hand.bet;
  }

  bool _canSurrender(Hand hand) =>
      _rules.surrenderAllowed && hand.cards.length == 2 && !hand.fromSplit;

  List<StrategyAction> _availableActions() {
    if (_phase != GamePhase.playerTurn || _playerHands.isEmpty) {
      return const <StrategyAction>[];
    }
    final Hand hand = _activeHand;
    if (hand.isFinished) return const <StrategyAction>[];
    return <StrategyAction>[
      StrategyAction.hit,
      StrategyAction.stand,
      if (_canDouble(hand)) StrategyAction.doubleDown,
      if (_canSplit(hand)) StrategyAction.split,
      if (_canSurrender(hand)) StrategyAction.surrender,
    ];
  }

  RoundSnapshot _advanceHand() {
    // Move to the next hand that still needs a decision.
    while (_activeHandIndex < _playerHands.length - 1) {
      _activeHandIndex++;
      if (_activeHand.cards.length == 1) {
        _dealToActiveHand();
      }
      if (_activeHand.splitAces) {
        _replaceActiveHand(_activeHand.copyWith(isStood: true));
        continue;
      }
      if (!_activeHand.isFinished) return snapshot;
    }
    return _playDealer();
  }

  RoundSnapshot _playDealer() {
    _phase = GamePhase.dealerTurn;
    _revealHoleCard();

    final bool everyoneOut = _playerHands.every(
      (Hand h) => h.isBust || h.isSurrendered,
    );
    if (!everyoneOut) {
      while (_shouldDealerDraw(_dealerHand)) {
        _dealerHand = _dealerHand.add(_drawCounted());
      }
    }
    return _settle();
  }

  void _revealHoleCard() {
    if (!_holeCardHidden) return;
    _holeCardHidden = false;
    if (_dealerHand.cards.length > 1) {
      _counter.addCard(_dealerHand.cards[1]);
      _counter.syncCardsSeen(_shoe.cardsDealt);
    }
  }

  bool _shouldDealerDraw(Hand dealer) {
    if (dealer.total < 17) return true;
    if (dealer.total == 17 && dealer.isSoft && _rules.dealerHitsSoft17) {
      return true;
    }
    return false;
  }

  RoundSnapshot _settle() {
    _revealHoleCard();
    final bool dealerBlackjack = _dealerHand.isBlackjack;
    final int dealerTotal = _dealerHand.total;
    final bool dealerBust = _dealerHand.isBust;

    _playerHands = <Hand>[
      for (final Hand hand in _playerHands)
        hand.copyWith(
          outcome: _outcomeFor(
            hand,
            dealerBlackjack: dealerBlackjack,
            dealerBust: dealerBust,
            dealerTotal: dealerTotal,
          ),
        ),
    ];

    for (final Hand hand in _playerHands) {
      _netResult += _payout(hand);
    }

    _phase = GamePhase.settled;
    _message ??= _summaryMessage();
    return snapshot;
  }

  HandOutcome _outcomeFor(
    Hand hand, {
    required bool dealerBlackjack,
    required bool dealerBust,
    required int dealerTotal,
  }) {
    if (hand.isSurrendered) return HandOutcome.surrender;
    if (hand.isBust) return HandOutcome.bust;
    if (hand.isBlackjack) {
      return dealerBlackjack ? HandOutcome.push : HandOutcome.blackjack;
    }
    if (dealerBlackjack) return HandOutcome.lose;
    if (dealerBust) return HandOutcome.win;
    if (hand.total > dealerTotal) return HandOutcome.win;
    if (hand.total < dealerTotal) return HandOutcome.lose;
    return HandOutcome.push;
  }

  /// Credits the bankroll for a settled hand and returns its net units.
  int _payout(Hand hand) {
    final int wager = hand.totalWager;
    switch (hand.outcome) {
      case HandOutcome.blackjack:
        final int win = (wager * _rules.blackjackPayout).round();
        _bankroll += wager + win;
        return win;
      case HandOutcome.win:
        _bankroll += wager * 2;
        return wager;
      case HandOutcome.push:
        _bankroll += wager;
        return 0;
      case HandOutcome.surrender:
        final int returned = (wager / 2).floor();
        _bankroll += returned;
        return returned - wager;
      case HandOutcome.bust:
      case HandOutcome.lose:
        return -wager;
      case HandOutcome.pending:
        return 0;
    }
  }

  String _summaryMessage() {
    if (_playerHands.length == 1) {
      final Hand hand = _playerHands.first;
      switch (hand.outcome) {
        case HandOutcome.blackjack:
          return 'Blackjack!';
        case HandOutcome.win:
          return _dealerHand.isBust ? 'Dealer busts — you win.' : 'You win.';
        case HandOutcome.push:
          return 'Push.';
        case HandOutcome.bust:
          return 'Bust.';
        case HandOutcome.lose:
          return 'Dealer wins.';
        case HandOutcome.surrender:
          return 'Surrendered — half the bet returned.';
        case HandOutcome.pending:
          return '';
      }
    }
    if (_netResult > 0) return 'Up $_netResult units on the round.';
    if (_netResult < 0) return 'Down ${_netResult.abs()} units on the round.';
    return 'Break even on the round.';
  }
}
