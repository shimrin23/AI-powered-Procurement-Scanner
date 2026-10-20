/// Represents a single line item extracted from a procurement document.
class LineItem {
  String description;
  String rawQuantity;
  String rawUnitPrice;
  String rawAmount;

  /// Whether the user has manually reviewed this field.
  bool quantityReviewed;
  bool unitPriceReviewed;
  bool amountReviewed;

  /// Confidence (0.0 – 1.0) reported by the OCR model.
  double confidence;

  LineItem({
    required this.description,
    required this.rawQuantity,
    required this.rawUnitPrice,
    required this.rawAmount,
    this.quantityReviewed = false,
    this.unitPriceReviewed = false,
    this.amountReviewed = false,
    this.confidence = 1.0,
  });

  /// Returns true if any field is unreviewed AND had low confidence.
  bool get needsReview =>
      (!quantityReviewed || !unitPriceReviewed || !amountReviewed) &&
      confidence < 0.8;

  LineItem copyWith({
    String? description,
    String? rawQuantity,
    String? rawUnitPrice,
    String? rawAmount,
    bool? quantityReviewed,
    bool? unitPriceReviewed,
    bool? amountReviewed,
    double? confidence,
  }) {
    return LineItem(
      description: description ?? this.description,
      rawQuantity: rawQuantity ?? this.rawQuantity,
      rawUnitPrice: rawUnitPrice ?? this.rawUnitPrice,
      rawAmount: rawAmount ?? this.rawAmount,
      quantityReviewed: quantityReviewed ?? this.quantityReviewed,
      unitPriceReviewed: unitPriceReviewed ?? this.unitPriceReviewed,
      amountReviewed: amountReviewed ?? this.amountReviewed,
      confidence: confidence ?? this.confidence,
    );
  }
}
