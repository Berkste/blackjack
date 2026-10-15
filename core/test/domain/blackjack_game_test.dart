import 'package:blackjack_core/domain/blackjack/basic_strategy.dart';
import 'package:blackjack_core/domain/blackjack/blackjack_game.dart';
import 'package:blackjack_core/domain/blackjack/blackjack_rules.dart';
import 'package:blackjack_core/domain/blackjack/hand.dart';
import 'package:blackjack_core/domain/models/playing_card.dart';
import 'package:test/test.dart';

PlayingCard c(Rank rank, [Suit suit = Suit.spades]) => PlayingCard(rank, suit);

/// Builds a game whose shoe deals exactly [cards], in order.
///
/// Deal order is player, dealer up, player, dealer hole, then draws.
BlackjackGame stackedGame(
  List<PlayingCard> cards, {
  BlackjackRules rules = const BlackjackRules(),
  int bankroll = 1000,
}) {
  final BlackjackGame game = BlackjackGame(
    rules: rules,
    bankroll: bankroll,
    seed: 1,
  );
  game.shoe.stack(<PlayingCard>[
    ...cards,
    // Padding so the engine never runs the shoe dry mid-test.
    ...List<PlayingCard>.filled(60, c(Rank.seven, Suit.clubs)),
  ]);
  return game;
}

void main() {
  group('dealing', () {
    test('a round deals two cards each with the hole card face down', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.seven),
        c(Rank.nine),
      ]);
      final RoundSnapshot state = game.startRound(10);
      expect(state.playerHands.single.cards, hasLength(2));
      expect(state.dealerHand.cards, hasLength(2));
      expect(state.holeCardHidden, isTrue);
      expect(state.visibleDealerCards, hasLength(1));
      expect(state.phase, GamePhase.playerTurn);
    });

    test('the hole card is not counted until it is exposed', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.five), // player  +1
        c(Rank.nine), // dealer up 0
        c(Rank.six), // player  +1
        c(Rank.king), // hole    -1, hidden
      ]);
      final RoundSnapshot dealt = game.startRound(10);
      expect(dealt.runningCount, 2);

      final RoundSnapshot done = game.stand();
      // Hole card is now exposed and counted.
      expect(done.runningCount, lessThan(2));
      expect(done.holeCardHidden, isFalse);
    });

    test('decks remaining reflect every card physically removed', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.seven),
        c(Rank.nine),
      ]);
      final RoundSnapshot state = game.startRound(10);
      expect(game.shoe.cardsDealt, 4);
      expect(state.cardsRemaining, game.shoe.cardsRemaining);
    });

    test('the bet leaves the bankroll when the round starts', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.seven),
        c(Rank.nine),
      ], bankroll: 100);
      final RoundSnapshot state = game.startRound(25);
      expect(state.bankroll, 75);
      expect(state.baseBet, 25);
    });

    test('hand numbers increase across rounds', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[]);
      expect(game.startRound(10).handNumber, 1);
      game.stand();
      expect(game.startRound(10).handNumber, 2);
    });
  });

  group('naturals', () {
    test('a player blackjack pays 3:2 and ends the round immediately', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ace),
        c(Rank.six),
        c(Rank.king),
        c(Rank.nine),
      ], bankroll: 100);
      final RoundSnapshot state = game.startRound(10);
      expect(state.phase, GamePhase.settled);
      expect(state.playerHands.single.outcome, HandOutcome.blackjack);
      expect(state.bankroll, 115);
      expect(state.netResult, 15);
    });

    test('a 6:5 table pays a natural less', () {
      final BlackjackGame game = stackedGame(
        <PlayingCard>[c(Rank.ace), c(Rank.six), c(Rank.king), c(Rank.nine)],
        rules: const BlackjackRules(blackjackPayout: 1.2),
        bankroll: 100,
      );
      expect(game.startRound(10).netResult, 12);
    });

    test('two naturals push', () {
      // Dealer shows a king, so the round settles on the peek rather than
      // detouring through the insurance decision.
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ace),
        c(Rank.king, Suit.hearts),
        c(Rank.queen),
        c(Rank.ace, Suit.diamonds),
      ], bankroll: 100);
      final RoundSnapshot state = game.startRound(10);
      expect(state.playerHands.single.outcome, HandOutcome.push);
      expect(state.bankroll, 100);
    });

    test('a dealer natural beats a normal twenty', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.king),
        c(Rank.queen),
        c(Rank.ace),
      ], bankroll: 100);
      final RoundSnapshot state = game.startRound(10);
      expect(state.phase, GamePhase.settled);
      expect(state.playerHands.single.outcome, HandOutcome.lose);
      expect(state.bankroll, 90);
    });
  });

  group('player actions', () {
    test('hitting draws a card and busting resolves the hand', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.nine),
        c(Rank.six),
        c(Rank.eight),
        c(Rank.king), // player draws to 26
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.hit();
      expect(state.playerHands.single.isBust, isTrue);
      expect(state.playerHands.single.outcome, HandOutcome.bust);
      expect(state.phase, GamePhase.settled);
    });

    test('a busted player still loses to a busted dealer', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.six),
        c(Rank.nine),
        c(Rank.king), // player busts at 26
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.hit();
      expect(state.playerHands.single.outcome, HandOutcome.bust);
      expect(state.netResult, -10);
    });

    test('standing hands play over to the dealer', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.nine),
        c(Rank.nine), // dealer 15
        c(Rank.five), // dealer draws to 20
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.stand();
      expect(state.phase, GamePhase.settled);
      expect(state.dealerHand.total, 20);
      expect(state.playerHands.single.outcome, HandOutcome.lose);
    });

    test('doubling adds a wager and takes exactly one card', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.six),
        c(Rank.five), // dealer up 5
        c(Rank.five), // player 11
        c(Rank.nine), // hole -> dealer 14
        c(Rank.king), // player doubles to 21
        c(Rank.four), // dealer draws to 18
      ], bankroll: 100);
      game.startRound(10);
      final RoundSnapshot state = game.doubleDown();
      expect(state.playerHands.single.isDoubled, isTrue);
      expect(state.playerHands.single.cards, hasLength(3));
      expect(state.playerHands.single.total, 21);
      expect(state.phase, GamePhase.settled);
      expect(state.netResult, 20);
      expect(state.bankroll, 120);
    });

    test('surrender returns half the bet', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.king),
        c(Rank.six),
        c(Rank.nine),
      ], bankroll: 100);
      game.startRound(10);
      final RoundSnapshot state = game.surrender();
      expect(state.playerHands.single.outcome, HandOutcome.surrender);
      expect(state.bankroll, 95);
      expect(state.netResult, -5);
    });

    test('surrender is unavailable when the table forbids it', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.king),
        c(Rank.six),
        c(Rank.nine),
      ], rules: const BlackjackRules(surrenderAllowed: false));
      final RoundSnapshot state = game.startRound(10);
      expect(state.availableActions, isNot(contains(StrategyAction.surrender)));
      expect(game.surrender().playerHands.single.isSurrendered, isFalse);
    });

    test('actions outside the player turn are ignored', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[]);
      expect(game.hit().phase, GamePhase.betting);
      expect(game.stand().phase, GamePhase.betting);
    });
  });

  group('splitting', () {
    test('splitting eights creates two hands and deals a second card', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.eight),
        c(Rank.six), // dealer up
        c(Rank.eight, Suit.hearts),
        c(Rank.nine), // hole
        c(Rank.three), // to first split hand
        c(Rank.two), // to second split hand
      ], bankroll: 100);
      game.startRound(10);
      final RoundSnapshot state = game.split();
      expect(state.playerHands, hasLength(2));
      expect(state.playerHands.first.cards, hasLength(2));
      expect(state.playerHands.first.fromSplit, isTrue);
      expect(state.bankroll, 80);
      expect(state.activeHandIndex, 0);
    });

    test('split aces get one card each and stand automatically', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ace),
        c(Rank.six),
        c(Rank.ace, Suit.hearts),
        c(Rank.nine),
        c(Rank.king),
        c(Rank.queen),
        c(Rank.five), // dealer draws
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.split();
      expect(state.playerHands, hasLength(2));
      expect(state.playerHands.every((Hand h) => h.cards.length == 2), isTrue);
      expect(state.playerHands.every((Hand h) => h.isBlackjack), isFalse);
      expect(state.phase, GamePhase.settled);
    });

    test('a non-pair cannot be split', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.nine),
        c(Rank.nine),
      ]);
      final RoundSnapshot state = game.startRound(10);
      expect(state.availableActions, isNot(contains(StrategyAction.split)));
      expect(game.split().playerHands, hasLength(1));
    });

    test('splits are capped at the table maximum', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.eight),
        c(Rank.six),
        c(Rank.eight, Suit.hearts),
        c(Rank.nine),
        c(Rank.eight, Suit.clubs),
        c(Rank.eight, Suit.diamonds),
      ], rules: const BlackjackRules(maxSplitHands: 2));
      game.startRound(10);
      final RoundSnapshot state = game.split();
      expect(state.playerHands, hasLength(2));
      expect(state.availableActions, isNot(contains(StrategyAction.split)));
    });

    test('each split hand settles on its own merit', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.eight),
        c(Rank.six), // dealer up 6
        c(Rank.eight, Suit.hearts),
        c(Rank.ten), // hole -> dealer 16
        c(Rank.king), // first hand -> 18
        c(Rank.two), // second hand -> 10
        c(Rank.two, Suit.hearts), // dealer draws to 18
      ], bankroll: 100);
      game.startRound(10);
      game.split();
      game.stand(); // first hand 18
      final RoundSnapshot state = game.stand(); // second hand 10
      expect(state.playerHands, hasLength(2));
      expect(state.phase, GamePhase.settled);
      expect(state.playerHands.first.outcome, HandOutcome.push);
      expect(state.playerHands.last.outcome, HandOutcome.lose);
    });
  });

  group('insurance', () {
    test('a dealer ace offers insurance before the player acts', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace), // dealer up
        c(Rank.six),
        c(Rank.nine),
      ]);
      final RoundSnapshot state = game.startRound(10);
      expect(state.phase, GamePhase.insurance);
    });

    test('insurance pays 2:1 when the dealer has a natural', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace),
        c(Rank.six),
        c(Rank.king),
      ], bankroll: 100);
      game.startRound(10);
      final RoundSnapshot state = game.takeInsurance();
      // Base bet lost, insurance won: 10 out, 5 insurance, 15 back.
      expect(state.bankroll, 100 - 10 - 5 + 15);
      expect(state.netResult, 0);
      expect(state.phase, GamePhase.settled);
    });

    test('insurance is lost when the dealer has no natural', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace),
        c(Rank.eight),
        c(Rank.six), // dealer 17, no natural
      ], bankroll: 100);
      game.startRound(10);
      final RoundSnapshot state = game.takeInsurance();
      expect(state.phase, GamePhase.playerTurn);
      expect(state.insuranceBet, 5);
      expect(state.netResult, -5);
    });

    test('declining insurance moves straight to the player turn', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace),
        c(Rank.eight),
        c(Rank.six),
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.declineInsurance();
      expect(state.phase, GamePhase.playerTurn);
      expect(state.insuranceBet, 0);
    });
  });

  group('dealer rules', () {
    test('the dealer stands on soft 17 under S17', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace), // dealer up ace
        c(Rank.eight),
        c(Rank.six), // hole -> soft 17
      ]);
      game.startRound(10);
      game.declineInsurance();
      final RoundSnapshot state = game.stand();
      expect(state.dealerHand.cards, hasLength(2));
      expect(state.dealerHand.total, 17);
    });

    test('the dealer draws on soft 17 under H17', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.ace),
        c(Rank.eight),
        c(Rank.six), // soft 17
        c(Rank.two), // draws to soft 19
      ], rules: const BlackjackRules(dealerHitsSoft17: true));
      game.startRound(10);
      game.declineInsurance();
      final RoundSnapshot state = game.stand();
      expect(state.dealerHand.cards, hasLength(3));
      expect(state.dealerHand.total, 19);
    });

    test('the dealer draws until reaching seventeen', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.two), // dealer up 2
        c(Rank.nine), // player 19
        c(Rank.three), // hole -> 5
        c(Rank.four), // 9
        c(Rank.five), // 14
        c(Rank.four, Suit.hearts), // 18
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.stand();
      expect(state.dealerHand.total, 18);
      expect(state.playerHands.single.outcome, HandOutcome.win);
    });

    test('the dealer does not draw when every player hand is out', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.two),
        c(Rank.six),
        c(Rank.three), // dealer 5, would normally draw
        c(Rank.king), // player busts at 26
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.hit();
      expect(state.dealerHand.cards, hasLength(2));
      expect(state.dealerHand.total, 5);
    });

    test('a dealer bust wins every standing hand', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.two), // player 12
        c(Rank.ten, Suit.hearts), // dealer 16
        c(Rank.king), // dealer busts at 26
      ]);
      game.startRound(10);
      final RoundSnapshot state = game.stand();
      expect(state.dealerHand.isBust, isTrue);
      expect(state.playerHands.single.outcome, HandOutcome.win);
    });
  });

  group('count integration', () {
    test('the running count tracks every exposed card', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.five), // +1
        c(Rank.six), // +1
        c(Rank.king), // -1
        c(Rank.seven), // hole, 0
      ]);
      final RoundSnapshot dealt = game.startRound(10);
      expect(dealt.runningCount, 1);
      final RoundSnapshot done = game.stand();
      expect(done.runningCount, 1); // hole card is a seven
    });

    test('the true count divides by the shoe depth', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[]);
      game.startRound(10);
      final RoundSnapshot state = game.snapshot;
      expect(
        state.trueCount,
        closeTo(state.runningCount / state.decksRemaining, 1e-9),
      );
    });

    test('a new shoe resets the count to zero', () {
      final BlackjackGame game = BlackjackGame(seed: 3);
      game.startRound(10);
      game.stand();
      game.newShoe(seed: 4);
      expect(game.counter.runningCount, 0);
      expect(game.shoe.cardsRemaining, 312);
    });

    test('the shoe reshuffles once the cut card is passed', () {
      final BlackjackGame game = BlackjackGame(
        rules: const BlackjackRules(deckCount: 1, penetration: 0.5),
        seed: 8,
      );
      while (!game.shoe.isCutCardReached) {
        game.startRound(10);
        if (game.phase == GamePhase.insurance) {
          game.declineInsurance();
        }
        if (game.phase == GamePhase.playerTurn) {
          game.stand();
        }
      }
      final RoundSnapshot next = game.startRound(10);
      expect(next.shoeNumber, greaterThan(1));
      expect(next.message, contains('New shoe'));
    });
  });

  group('rules and configuration', () {
    test('changing the rules starts a fresh shoe of the right size', () {
      final BlackjackGame game = BlackjackGame(seed: 1);
      game.applyRules(const BlackjackRules(deckCount: 2), seed: 2);
      expect(game.shoe.deckCount, 2);
      expect(game.shoe.cardsRemaining, 104);
      expect(game.phase, GamePhase.betting);
    });

    test('the same seed replays an identical round', () {
      RoundSnapshot playOne() {
        final BlackjackGame game = BlackjackGame(seed: 777);
        final RoundSnapshot dealt = game.startRound(10);
        return dealt;
      }

      final RoundSnapshot a = playOne();
      final RoundSnapshot b = playOne();
      expect(a.playerHands.single.cards, b.playerHands.single.cards);
      expect(a.dealerHand.cards, b.dealerHand.cards);
      expect(a.runningCount, b.runningCount);
    });

    test('the rules summary names the table conditions', () {
      const BlackjackRules rules = BlackjackRules();
      expect(rules.summary, contains('6 decks'));
      expect(rules.summary, contains('S17'));
      expect(rules.summary, contains('DAS'));
      expect(rules.summary, contains('75%'));
      expect(rules.blackjackPayoutLabel, '3:2');
    });

    test('advice is offered only during the player turn', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[
        c(Rank.ten),
        c(Rank.six),
        c(Rank.six, Suit.hearts),
        c(Rank.nine),
      ]);
      expect(game.advice, isNull);
      game.startRound(10);
      expect(game.advice?.action, StrategyAction.stand);
      game.stand();
      expect(game.advice, isNull);
    });

    test('resetting the bankroll restores the starting stack', () {
      final BlackjackGame game = stackedGame(<PlayingCard>[], bankroll: 500);
      game.startRound(50);
      game.resetBankroll();
      expect(game.bankroll, 500);
    });
  });
}
