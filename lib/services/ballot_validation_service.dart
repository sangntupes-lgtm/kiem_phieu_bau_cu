class BallotValidationResult {
  const BallotValidationResult({
    required this.isValid,
    required this.reason,
    required this.excluded,
  });

  final bool isValid;
  final String reason;
  final List<int> excluded;
}

class BallotValidationService {
  const BallotValidationService._();

  static BallotValidationResult validate({
    required List<int> excluded,
    required int candidateCount,
    required int requiredExcludeCount,
    required int selectCount,
  }) {
    final values = excluded.toSet().toList()..sort();

    if (values.any((value) => value < 1 || value > candidateCount)) {
      return BallotValidationResult(
        isValid: false,
        reason: 'CÓ SỐ NGOÀI DANH SÁCH',
        excluded: values,
      );
    }

    if (values.length == candidateCount ||
        (values.isEmpty && candidateCount > 0 && selectCount == 0)) {
      return BallotValidationResult(
        isValid: false,
        reason: 'PHIẾU TRẮNG',
        excluded: values,
      );
    }

    if (values.length != requiredExcludeCount) {
      return BallotValidationResult(
        isValid: false,
        reason: 'BỎ SAI SỐ LƯỢNG',
        excluded: values,
      );
    }

    return BallotValidationResult(
      isValid: true,
      reason: '',
      excluded: values,
    );
  }
}
