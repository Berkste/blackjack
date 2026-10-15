/// The four training tiers.
///
/// Difficulty controls how many cards a drill deals, how fast they arrive and
/// which exercises are on offer. Tiers unlock on demonstrated accuracy rather
/// than on time spent.
enum Difficulty {
  beginner(
    label: 'Beginner',
    tagline: 'Card values and short sequences',
    sequenceLength: 5,
    dealInterval: Duration(milliseconds: 1600),
    xpMultiplier: 1,
    requiredLevel: 1,
  ),
  intermediate(
    label: 'Intermediate',
    tagline: 'Ten to twenty cards, running count',
    sequenceLength: 10,
    dealInterval: Duration(milliseconds: 1100),
    xpMultiplier: 1.25,
    requiredLevel: 3,
  ),
  advanced(
    label: 'Advanced',
    tagline: 'True count, deck estimation, faster deals',
    sequenceLength: 20,
    dealInterval: Duration(milliseconds: 750),
    xpMultiplier: 1.6,
    requiredLevel: 5,
  ),
  expert(
    label: 'Expert',
    tagline: 'Full shoes, checkpoints and distractions',
    sequenceLength: 40,
    dealInterval: Duration(milliseconds: 480),
    xpMultiplier: 2,
    requiredLevel: 8,
  );

  const Difficulty({
    required this.label,
    required this.tagline,
    required this.sequenceLength,
    required this.dealInterval,
    required this.xpMultiplier,
    required this.requiredLevel,
  });

  final String label;
  final String tagline;

  /// Cards dealt in a running-count drill at this tier.
  final int sequenceLength;

  /// Gap between cards when they are dealt automatically.
  final Duration dealInterval;

  /// Scales the XP awarded for a correct answer.
  final double xpMultiplier;

  /// Player level at which this tier unlocks.
  final int requiredLevel;

  bool isUnlockedAt(int level) => level >= requiredLevel;

  static Difficulty highestUnlockedAt(int level) => Difficulty.values.lastWhere(
    (Difficulty d) => d.isUnlockedAt(level),
    orElse: () => Difficulty.beginner,
  );
}

/// How quickly cards arrive in the speed-count drill.
enum CountSpeed {
  slow('Slow', Duration(milliseconds: 1500)),
  normal('Normal', Duration(milliseconds: 1000)),
  fast('Fast', Duration(milliseconds: 650)),
  expert('Expert', Duration(milliseconds: 420));

  const CountSpeed(this.label, this.interval);

  final String label;
  final Duration interval;

  /// Cards per minute at this speed, for the stats readout.
  int get cardsPerMinute => (60000 / interval.inMilliseconds).round();
}

/// The training exercises the app offers.
enum TrainingDrill {
  singleCard(
    id: 'single_card',
    title: 'Card Values',
    subtitle: 'One card, one tag',
    description:
        'A single card, three choices. This is where the Hi-Lo tags stop '
        'being something you work out and start being something you know.',
  ),
  runningCount(
    id: 'running_count',
    title: 'Running Count',
    subtitle: 'Add a sequence',
    description:
        'A sequence of cards dealt one after another. Keep a single number in '
        'your head and report it at the end.',
  ),
  speedCount(
    id: 'speed_count',
    title: 'Speed Count',
    subtitle: 'Keep up with the deal',
    description:
        'Cards arrive on their own and stop without warning. Counting has to '
        'survive a pace you do not control.',
  ),
  trueCount(
    id: 'true_count',
    title: 'True Count',
    subtitle: 'Divide by decks left',
    description:
        'Convert a running count into a true count. This is the number that '
        'actually describes your edge.',
  ),
  deckEstimation(
    id: 'deck_estimation',
    title: 'Deck Estimation',
    subtitle: 'Read the shoe',
    description:
        'Judge the decks remaining from the look of the discard tray. A true '
        'count is only as good as this estimate.',
  ),
  fullDrill(
    id: 'full_drill',
    title: 'Full Counting Drill',
    subtitle: 'Count a real shoe',
    description:
        'Hands are dealt from a real shoe. Between hands you are asked for the '
        'running count, the decks remaining and the true count.',
  );

  const TrainingDrill({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;

  static TrainingDrill? fromId(String id) {
    for (final TrainingDrill drill in TrainingDrill.values) {
      if (drill.id == id) return drill;
    }
    return null;
  }
}
