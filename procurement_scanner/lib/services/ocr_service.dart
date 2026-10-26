import '../models/line_item.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Result of document analysis containing transcribed text and extracted items.
/// ─────────────────────────────────────────────────────────────────────────────
class OcrResult {
  final String rawText;
  final List<LineItem> lineItems;
  final List<String> warnings;
  final String? writtenTotal;

  const OcrResult({
    required this.rawText,
    required this.lineItems,
    required this.warnings,
    this.writtenTotal,
  });
}
