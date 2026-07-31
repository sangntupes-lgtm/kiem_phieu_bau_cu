class ElectionSummary {
  const ElectionSummary({
    required this.totalBallots,
    required this.enteredBallots,
    required this.validBallots,
    required this.invalidBallots,
  });

  final int totalBallots;
  final int enteredBallots;
  final int validBallots;
  final int invalidBallots;

  double get progress =>
      totalBallots <= 0 ? 0 : enteredBallots / totalBallots;
}
