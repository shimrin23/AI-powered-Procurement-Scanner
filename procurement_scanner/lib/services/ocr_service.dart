import '../models/line_item.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Result of document analysis containing transcribed text and extracted items.
/// ─────────────────────────────────────────────────────────────────────────────
class OcrResult {
  final String rawText;
  final List<LineItem> lineItems;
  final List<String> warnings;
  final String? writtenTotal;
  final String? writtenSubtotal;
  final String? writtenVatTotal;
  final String? documentVatRate;
  final PriceVatStatus documentPriceStatus;

  const OcrResult({
    required this.rawText,
    required this.lineItems,
    required this.warnings,
    this.writtenTotal,
    this.writtenSubtotal,
    this.writtenVatTotal,
    this.documentVatRate,
    this.documentPriceStatus = PriceVatStatus.unspecified,
  });
}
