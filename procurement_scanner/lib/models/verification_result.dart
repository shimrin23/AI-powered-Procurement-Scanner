/// The overall verification status of a scanned document.
enum VerificationStatus {
  /// All extracted calculations match the computed values.
  calculationsMatch,

  /// At least one discrepancy was found between written and calculated amounts.
  discrepancyDetected,

  /// Fields with low OCR confidence prevent a reliable determination.
  manualReviewRequired,
}

extension VerificationStatusX on VerificationStatus {
  String get label {
    switch (this) {
      case VerificationStatus.calculationsMatch:
        return 'Calculations Match';
      case VerificationStatus.discrepancyDetected:
        return 'Discrepancy Detected';
      case VerificationStatus.manualReviewRequired:
        return 'Manual Review Required';
    }
  }

  String get description {
    switch (this) {
      case VerificationStatus.calculationsMatch:
        return 'All extracted line-item amounts and totals match the computed values.';
      case VerificationStatus.discrepancyDetected:
        return 'One or more written amounts differ from computed values. Please review the highlighted fields.';
      case VerificationStatus.manualReviewRequired:
        return 'Some values could not be recognised with sufficient confidence. Human review is required before accepting this document.';
    }
  }
}

/// Result produced by the CalculatorService for one complete document scan.
class VerificationResult {
  final VerificationStatus status;

  /// Per-item: (writtenAmount, calculatedAmount, difference)
  final List<ItemVerification> itemResults;

  /// Written subtotal / grand total found in the document, if any.
  final String? writtenTotal;

  /// Computed sum of all item amounts.
  final String computedTotal;

  /// Difference between written and computed total (negative = document has less).
  final String? totalDifference;

  /// Raw OCR text extracted from the entire image.
  final String rawOcrText;

  /// Any general warnings accumulated during extraction or verification.
  final List<String> warnings;

  const VerificationResult({
    required this.status,
    required this.itemResults,
    this.writtenTotal,
    required this.computedTotal,
    this.totalDifference,
    required this.rawOcrText,
    this.warnings = const [],
  });
}

class ItemVerification {
  final String description;
  final String rawQuantity;
  final String rawUnitPrice;
  final String writtenAmount;
  final String calculatedAmount;
  final String difference;
  final bool matches;
  final bool lowConfidence;

  const ItemVerification({
    required this.description,
    required this.rawQuantity,
    required this.rawUnitPrice,
    required this.writtenAmount,
    required this.calculatedAmount,
    required this.difference,
    required this.matches,
    required this.lowConfidence,
  });
}
