import 'package:meta/meta.dart';

import '../../../domain/models/playing_card.dart';

/// The kinds of block a lesson page can contain.
enum LessonBlockType {
  /// A paragraph of prose.
  text,

  /// A short, emphasised takeaway.
  callout,

  /// A row of cards with their Hi-Lo tags shown.
  cardTags,

  /// A worked running-count example, revealed card by card.
  countExample,

  /// The three-group Hi-Lo summary table.
  valueTable,

  /// The interactive true-count calculator.
  trueCountCalculator,

  /// The interactive deck-estimation shoe.
  deckEstimator,

  /// A link through to the full basic-strategy chart.
  strategyChart,

  /// The Illustrious 18 list.
  deviationList,

  /// A multiple-choice check for understanding.
  quiz,
}

/// One block of lesson content.
@immutable
class LessonBlock {
  const LessonBlock({
    required this.type,
    this.text,
    this.title,
    this.cards = const <PlayingCard>[],
    this.question,
    this.options = const <String>[],
    this.correctIndex = 0,
    this.explanation,
  });

  const LessonBlock.text(String body)
    : this(type: LessonBlockType.text, text: body);

  const LessonBlock.callout(String body, {String? title})
    : this(type: LessonBlockType.callout, text: body, title: title);

  const LessonBlock.cards(List<PlayingCard> cards, {String? title})
    : this(type: LessonBlockType.cardTags, cards: cards, title: title);

  const LessonBlock.countExample(List<PlayingCard> cards, {String? title})
    : this(type: LessonBlockType.countExample, cards: cards, title: title);

  const LessonBlock.quiz({
    required String question,
    required List<String> options,
    required int correctIndex,
    required String explanation,
    List<PlayingCard> cards = const <PlayingCard>[],
  }) : this(
         type: LessonBlockType.quiz,
         question: question,
         options: options,
         correctIndex: correctIndex,
         explanation: explanation,
         cards: cards,
       );

  final LessonBlockType type;
  final String? text;
  final String? title;
  final List<PlayingCard> cards;
  final String? question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
}

/// A lesson: a title, a goal and an ordered list of blocks.
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.goal,
    required this.blocks,
    this.requiresLessonId,
  });

  final String id;
  final int number;
  final String title;
  final String subtitle;

  /// One sentence describing what the user will be able to do afterwards.
  final String goal;

  final List<LessonBlock> blocks;

  /// Lesson that must be finished first. Deviations are gated behind basic
  /// strategy on purpose.
  final String? requiresLessonId;

  int get quizCount =>
      blocks.where((LessonBlock b) => b.type == LessonBlockType.quiz).length;
}

const PlayingCard _fiveSpades = PlayingCard(Rank.five, Suit.spades);
const PlayingCard _kingHearts = PlayingCard(Rank.king, Suit.hearts);
const PlayingCard _eightDiamonds = PlayingCard(Rank.eight, Suit.diamonds);
const PlayingCard _threeClubs = PlayingCard(Rank.three, Suit.clubs);
const PlayingCard _aceSpades = PlayingCard(Rank.ace, Suit.spades);
const PlayingCard _sixHearts = PlayingCard(Rank.six, Suit.hearts);
const PlayingCard _nineClubs = PlayingCard(Rank.nine, Suit.clubs);
const PlayingCard _queenDiamonds = PlayingCard(Rank.queen, Suit.diamonds);
const PlayingCard _twoHearts = PlayingCard(Rank.two, Suit.hearts);
const PlayingCard _tenClubs = PlayingCard(Rank.ten, Suit.clubs);
const PlayingCard _fourDiamonds = PlayingCard(Rank.four, Suit.diamonds);
const PlayingCard _sevenSpades = PlayingCard(Rank.seven, Suit.spades);

/// The lesson library.
abstract final class LessonLibrary {
  static const List<Lesson> lessons = <Lesson>[
    Lesson(
      id: 'card_values',
      number: 1,
      title: 'Card Values',
      subtitle: 'The three Hi-Lo groups',
      goal: 'Name the Hi-Lo tag of any card without thinking about it.',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'Hi-Lo splits the deck into three groups. Small cards help the '
          'dealer, big cards help you, and the middle cards barely matter. '
          'You track the balance between them with a single number.',
        ),
        LessonBlock(type: LessonBlockType.valueTable),
        LessonBlock.text(
          'That is the entire system. Every card you see adds +1, 0 or -1 to '
          'a number you keep in your head. There is nothing to memorise '
          'beyond these three groups.',
        ),
        LessonBlock.cards(<PlayingCard>[
          _twoHearts,
          _threeClubs,
          _fourDiamonds,
          _fiveSpades,
          _sixHearts,
        ], title: 'Low cards: +1'),
        LessonBlock.text(
          'When small cards leave the shoe, what remains is richer in tens '
          'and aces. That is good for you: more blackjacks, more strong '
          'doubles, and a dealer who breaks more often on a stiff hand.',
        ),
        LessonBlock.cards(<PlayingCard>[
          _sevenSpades,
          _eightDiamonds,
          _nineClubs,
        ], title: 'Neutral cards: 0'),
        LessonBlock.text(
          'Sevens, eights and nines are close enough to neutral that Hi-Lo '
          'ignores them. Skipping them is what makes the system fast enough '
          'to run at a real table.',
        ),
        LessonBlock.cards(<PlayingCard>[
          _tenClubs,
          _kingHearts,
          _queenDiamonds,
          _aceSpades,
        ], title: 'High cards: -1'),
        LessonBlock.callout(
          'Ten, jack, queen, king and ace all count as -1. There are sixteen '
          'ten-valued cards in a deck and only four aces, but Hi-Lo treats '
          'them the same.',
          title: 'Watch for this',
        ),
        LessonBlock.quiz(
          question: 'What is the Hi-Lo value of this card?',
          cards: <PlayingCard>[_fiveSpades],
          options: <String>['+1', '0', '-1'],
          correctIndex: 0,
          explanation:
              'A five is a low card, so it tags +1. Every card from two '
              'through six does.',
        ),
        LessonBlock.quiz(
          question: 'What is the Hi-Lo value of this card?',
          cards: <PlayingCard>[_eightDiamonds],
          options: <String>['+1', '0', '-1'],
          correctIndex: 1,
          explanation:
              'An eight is neutral. Sevens, eights and nines are all 0 and '
              'you skip straight past them.',
        ),
        LessonBlock.quiz(
          question: 'What is the Hi-Lo value of this card?',
          cards: <PlayingCard>[_aceSpades],
          options: <String>['+1', '0', '-1'],
          correctIndex: 2,
          explanation:
              'An ace counts as -1, exactly like a ten or a face card. It is '
              'the card beginners most often get wrong.',
        ),
      ],
    ),
    Lesson(
      id: 'running_count',
      number: 2,
      title: 'Running Count',
      subtitle: 'Keeping one number',
      goal: 'Hold an accurate running count through a sequence of cards.',
      requiresLessonId: 'card_values',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'The running count starts at zero when the shoe is shuffled. Every '
          'card you see moves it by its tag. That is the whole procedure.',
        ),
        LessonBlock.countExample(<PlayingCard>[
          _fiveSpades,
          _kingHearts,
          _eightDiamonds,
          _threeClubs,
          _aceSpades,
        ], title: 'Worked example'),
        LessonBlock.text(
          'Notice what you did not do: you never held five separate numbers, '
          'and you never went back to check. You held one number and adjusted '
          'it. If you lose it, you cannot recover it — you wait for the next '
          'shuffle and start again at zero.',
        ),
        LessonBlock.callout(
          'A full deck is balanced: twenty cards tag +1, twenty tag -1 and '
          'twelve are neutral. Count an entire deck correctly and you must '
          'finish on zero. That is how you check yourself.',
          title: 'The self-check',
        ),
        LessonBlock.text(
          'Speed comes from cancelling. When a five and a king land together '
          'they are +1 and -1, so the pair is worth nothing and you skip both. '
          'Experienced counters read a whole table this way, in pairs, rather '
          'than one card at a time.',
        ),
        LessonBlock.countExample(<PlayingCard>[
          _sixHearts,
          _queenDiamonds,
          _twoHearts,
          _fourDiamonds,
          _nineClubs,
          _tenClubs,
        ], title: 'Try cancelling'),
        LessonBlock.quiz(
          question: 'A deck is dealt out completely. Where must the count end?',
          options: <String>['+4', '0', '-4', 'It depends on the order'],
          correctIndex: 1,
          explanation:
              'Hi-Lo is a balanced system. Twenty +1 cards and twenty -1 '
              'cards cancel exactly, so a full deck always ends at zero '
              'whatever order it came out in.',
        ),
        LessonBlock.quiz(
          question: 'What is the running count after 5, K, 8, 3, A?',
          cards: <PlayingCard>[
            _fiveSpades,
            _kingHearts,
            _eightDiamonds,
            _threeClubs,
            _aceSpades,
          ],
          options: <String>['-2', '0', '+2', '+1'],
          correctIndex: 1,
          explanation:
              '+1 for the five, -1 for the king, 0 for the eight, +1 for the '
              'three and -1 for the ace. They cancel out at zero.',
        ),
      ],
    ),
    Lesson(
      id: 'true_count',
      number: 3,
      title: 'True Count',
      subtitle: 'What the count is actually worth',
      goal: 'Convert a running count into a true count in your head.',
      requiresLessonId: 'running_count',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'A running count of +6 means six more low cards than high cards '
          'have gone. Spread across six decks that is barely noticeable. '
          'Concentrated into one deck it is enormous. The running count on '
          'its own does not tell you which situation you are in.',
        ),
        LessonBlock.callout(
          'True Count = Running Count ÷ Decks Remaining',
          title: 'The conversion',
        ),
        LessonBlock.text(
          'The true count is what every betting and playing decision is '
          'actually based on. A running count of +6 with three decks left is '
          'a true count of +2 — a real but modest edge. The same +6 with one '
          'deck left is +6, which is a different game entirely.',
        ),
        LessonBlock(type: LessonBlockType.trueCountCalculator),
        LessonBlock.text(
          'Round toward zero when you are unsure. A true count you have '
          'rounded down is conservative: it makes you bet and deviate '
          'slightly less than optimally, which costs far less than '
          'overestimating your edge.',
        ),
        LessonBlock.callout(
          'Divide by decks remaining, not decks dealt. It is the single most '
          'common mistake, and it inverts your estimate late in the shoe when '
          'accuracy matters most.',
          title: 'Watch for this',
        ),
        LessonBlock.quiz(
          question: 'Running count +8, two decks remaining. True count?',
          options: <String>['+2', '+4', '+8', '+16'],
          correctIndex: 1,
          explanation: '8 ÷ 2 = 4. The true count is +4.',
        ),
        LessonBlock.quiz(
          question: 'Running count +6, six decks remaining. True count?',
          options: <String>['+1', '+2', '+3', '+6'],
          correctIndex: 0,
          explanation:
              '6 ÷ 6 = 1. The same +6 running count is worth six times less '
              'at the start of a shoe than at the end of it.',
        ),
        LessonBlock.quiz(
          question: 'Running count -4, two decks remaining. True count?',
          options: <String>['-8', '-2', '+2', '0'],
          correctIndex: 1,
          explanation:
              '-4 ÷ 2 = -2. Negative counts convert exactly the same way, and '
              'they matter: they are when you bet least.',
        ),
      ],
    ),
    Lesson(
      id: 'deck_estimation',
      number: 4,
      title: 'Deck Estimation',
      subtitle: 'Reading the shoe',
      goal: 'Judge the decks remaining to within half a deck.',
      requiresLessonId: 'true_count',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'Your true count is a division, and you have to supply the divisor '
          'yourself by looking at the shoe. Nobody counts the cards left. You '
          'learn what a given thickness looks like.',
        ),
        LessonBlock(type: LessonBlockType.deckEstimator),
        LessonBlock.text(
          'Half a deck is about the finest distinction worth making. Estimate '
          'to the nearest half deck and you will be accurate enough for every '
          'decision this system asks you to make.',
        ),
        LessonBlock.callout(
          'Practise on the discard tray rather than the shoe. It sits still, '
          'it grows steadily, and it is usually easier to see.',
          title: 'A practical trick',
        ),
        LessonBlock.text(
          'One deck is roughly the thickness of your thumb. Anchor to a '
          'physical reference you always have with you, then work from it: '
          'two thumbs is two decks, and so on.',
        ),
        LessonBlock.quiz(
          question:
              'A six-deck shoe is about two-thirds dealt. Decks remaining?',
          options: <String>['1', '2', '3', '4'],
          correctIndex: 1,
          explanation:
              'Two-thirds of six decks is four dealt, so two remain. With a '
              'running count of +6 that is a true count of +3.',
        ),
        LessonBlock.quiz(
          question: 'Why does an overestimate of decks remaining hurt you?',
          options: <String>[
            'It makes the true count look smaller than it is',
            'It makes the true count look larger than it is',
            'It has no effect on the true count',
            'It only matters at negative counts',
          ],
          correctIndex: 0,
          explanation:
              'Dividing by too large a number shrinks the true count, so you '
              'under-bet a good shoe. Overestimating in the other direction is '
              'worse still: it makes you bet into an edge you do not have.',
        ),
      ],
    ),
    Lesson(
      id: 'basic_strategy',
      number: 5,
      title: 'Basic Strategy',
      subtitle: 'The foundation under everything',
      goal: 'Play every hand correctly before the count is involved at all.',
      requiresLessonId: 'deck_estimation',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'Basic strategy is the mathematically best play for every '
          'combination of your hand and the dealer\'s upcard, ignoring the '
          'count entirely. It is not a matter of opinion or feel — it is a '
          'solved table.',
        ),
        LessonBlock.text(
          'Counting without basic strategy is worthless. The edge a count '
          'provides is around half a percent; the cost of guessing your way '
          'through hands is several times that. Learn the chart first.',
        ),
        LessonBlock(type: LessonBlockType.strategyChart),
        LessonBlock.callout(
          'Tap any cell in the chart to see why that play is correct. The '
          'reasoning matters more than the memorisation: hands you understand '
          'are hands you do not forget under pressure.',
          title: 'How to use it',
        ),
        LessonBlock.text(
          'A few anchors carry most of the value. Always split aces and '
          'eights. Never split tens or fives. Stand on hard 17 or more. Hit '
          'hard 12 through 16 unless the dealer shows 2 through 6. Double 11 '
          'against anything but an ace.',
        ),
        LessonBlock.quiz(
          question:
              'You hold 16, the dealer shows 10. Surrender is not '
              'offered. What does basic strategy say?',
          options: <String>['Stand', 'Hit', 'Split', 'Double'],
          correctIndex: 1,
          explanation:
              'Without surrender, hitting 16 against a ten loses slightly '
              'less than standing. It is a bad hand either way — basic '
              'strategy picks the cheaper loss.',
        ),
        LessonBlock.quiz(
          question: 'You hold a pair of eights against a dealer 10. Play?',
          options: <String>['Hit', 'Stand', 'Split', 'Double'],
          correctIndex: 2,
          explanation:
              'Always split eights. Sixteen is the worst hand in blackjack; '
              'two hands starting at eight are both better than keeping it.',
        ),
        LessonBlock.quiz(
          question: 'Soft 18 against a dealer 9. Play?',
          options: <String>['Stand', 'Hit', 'Double', 'Surrender'],
          correctIndex: 1,
          explanation:
              'Eighteen loses to the dealer\'s likely nineteen or twenty, and '
              'the ace means drawing cannot bust you. Hitting is correct '
              'against 9, 10 and ace.',
        ),
      ],
    ),
    Lesson(
      id: 'deviations',
      number: 6,
      title: 'Count-Based Deviations',
      subtitle: 'When the count overrules the chart',
      goal: 'Apply the highest-value index plays at the right true count.',
      requiresLessonId: 'basic_strategy',
      blocks: <LessonBlock>[
        LessonBlock.text(
          'Basic strategy assumes an average shoe. When the count tells you '
          'the shoe is not average, a handful of decisions flip. These are '
          'called deviations, or index plays.',
        ),
        LessonBlock.callout(
          'Do not start here. Deviations are worth a fraction of what correct '
          'basic strategy and correct counting are worth. Learn them last, '
          'and learn only a few.',
          title: 'Order matters',
        ),
        LessonBlock.text(
          'Insurance is the one that pays for itself. It is a bet that the '
          'hole card is a ten, and it becomes profitable at a true count of '
          '+3 or higher. At any lower count, decline it every time.',
        ),
        LessonBlock(type: LessonBlockType.deviationList),
        LessonBlock.text(
          'Learn the first four before touching the rest. Insurance, 16 vs '
          '10, 15 vs 10 and 10 vs 10 capture most of the available gain, and '
          'four indices are few enough to apply reliably at speed.',
        ),
        LessonBlock.callout(
          'None of this makes an outcome certain. Rules, penetration, '
          'bankroll and plain variance decide results over any period you '
          'will actually play. Treat every number here as a long-run average, '
          'not a promise.',
          title: 'Keep this in view',
        ),
        LessonBlock.quiz(
          question: 'At what true count does insurance become correct?',
          options: <String>['+1', '+2', '+3', 'Never'],
          correctIndex: 2,
          explanation:
              'Insurance needs better than one ten in three among the '
              'remaining cards, which arrives at a true count of +3.',
        ),
        LessonBlock.quiz(
          question:
              'You hold 16 against a dealer 10 at a true count of +1. '
              'Play?',
          options: <String>['Hit', 'Stand', 'Surrender', 'Split'],
          correctIndex: 1,
          explanation:
              'The 16 vs 10 index is 0, so any count of zero or above means '
              'stand. It is the most frequently used deviation there is.',
        ),
        LessonBlock.quiz(
          question:
              'The true count is -2 and you hold 13 against a dealer 2. '
              'Play?',
          options: <String>['Stand', 'Hit', 'Double', 'Surrender'],
          correctIndex: 1,
          explanation:
              'Deviations run in both directions. At -1 or below, the shoe is '
              'small-card rich, the dealer breaks less often, and hitting 13 '
              'against a deuce becomes correct.',
        ),
      ],
    ),
  ];

  static List<String> get allIds =>
      lessons.map((Lesson l) => l.id).toList(growable: false);

  static Lesson? byId(String id) {
    for (final Lesson lesson in lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  /// The next lesson the user has not finished, or `null` when all are done.
  static Lesson? nextFor(Set<String> completed) {
    for (final Lesson lesson in lessons) {
      if (!completed.contains(lesson.id)) return lesson;
    }
    return null;
  }

  /// True when [lesson] is available given what has been completed.
  static bool isUnlocked(Lesson lesson, Set<String> completed) =>
      lesson.requiresLessonId == null ||
      completed.contains(lesson.requiresLessonId);
}
