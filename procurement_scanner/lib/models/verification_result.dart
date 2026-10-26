/// Item-level verification outcome
enum ItemStatus {
  correct,
  incorrect,
  needsReview,
}

extension ItemStatusX on ItemStatus {
  String get label {
    switch (this) {
      case ItemStatus.correct:
        return 'CORRECT';
      case ItemStatus.incorrect:
        return 'INCORRECT';
      case ItemStatus.needsReview:
        return 'NEEDS REVIEW';
    }
  }
}

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
        return 'All extracted line-item amounts, VAT calculations, and totals match the computed values.';
      case VerificationStatus.discrepancyDetected:
        return 'One or more written amounts or VAT calculations differ from computed values. Please review the highlighted fields.';
      case VerificationStatus.manualReviewRequired:
        return 'Some values could not be recognised with sufficient confidence or require user confirmation. Human review is recommended.';
    }
  }
}

/// Result produced by the CalculatorService for one complete document scan.
class VerificationResult {
  final VerificationStatus status;

  /// Per-item verification results.
  final List<ItemVerification> itemResults;

  /// Written subtotal / grand total found in the document, if any.
  final String? writtenTotal;

  /// Computed sum of all expected item totals.
  final String computedTotal;

  /// Difference between written and computed total (negative = document has less).
  final String? totalDifference;

  /// Raw OCR text extracted from the document.
  final String rawOcrText;

  /// Any general warnings accumulated during extraction or verification.
  final List<String> warnings;

  // ── Document-level audit summaries ──────────────────────────────────────────
  final int vatErrorsCount;
  final int itemTotalErrorsCount;
  final bool grandTotalDiscrepancy;
  final String? totalVatCalculated;
  final String? writtenVatTotal;
  final String? subtotalCalculated;
  final String? writtenSubtotal;
  final List<String> discrepancyNotes;

  const VerificationResult({
    required this.status,
    required this.itemResults,
    this.writtenTotal,
    required this.computedTotal,
    this.totalDifference,
    required this.rawOcrText,
    this.warnings = const [],
    this.vatErrorsCount = 0,
    this.itemTotalErrorsCount = 0,
    this.grandTotalDiscrepancy = false,
    this.totalVatCalculated,
    this.writtenVatTotal,
    this.subtotalCalculated,
    this.writtenSubtotal,
    this.discrepancyNotes = const [],
  });
}

class ItemVerification {
  final String description;
  final String rawQuantity;
  final String rawUnitPrice;
  final String writtenAmount;

  // ── Granular VAT & Price Audit Fields ───────────────────────────────────────
  final String? unitPriceExclVat;
  final String? unitPriceInclVat;
  final String vatRatePercent; // e.g. "18%" or "0%" or "Unspecified"
  final String calculatedVatAmount; // Calculated VAT per item total
  final String expectedItemTotal; // Expected line amount from deterministic math
  final String difference;
  final ItemStatus itemStatus; // CORRECT, INCORRECT, NEEDS REVIEW
  final String? errorMessage;
  final bool matches;
  final bool lowConfidence;

  const ItemVerification({
    required this.description,
    required this.rawQuantity,
    required this.rawUnitPrice,
    required this.writtenAmount,
    this.unitPriceExclVat,
    this.unitPriceInclVat,
    required this.vatRatePercent,
    required this.calculatedVatAmount,
    required this.expectedItemTotal,
    required this.difference,
    required this.itemStatus,
    this.errorMessage,
    required this.matches,
    required this.lowConfidence,
  });

  /// Backward-compatibility getter for existing code referencing calculatedAmount.
  String get calculatedAmount => expectedItemTotal;
}
