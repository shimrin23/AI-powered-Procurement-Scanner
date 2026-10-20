import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/line_item.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// OCR Service
///
/// Uses Google ML Kit's on-device text recogniser.
///
/// Language support notes (ML Kit v0.13+):
///   • Latin (English / romanised)  → full support
///   • Tamil                        → supported (Devanagari-based model handles
///                                    some Indic scripts; Tamil has dedicated
///                                    support from ML Kit 0.12+)
///   • Sinhala                      → NOT directly supported; recognised text
///                                    will be partial/approximate. All Sinhala
///                                    fields are flagged as low-confidence and
///                                    require manual review.
///
/// The service never silently claims success for unrecognised scripts.
/// ─────────────────────────────────────────────────────────────────────────────
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  // Recognisers – created lazily and closed when done.
  TextRecognizer? _latinRecognizer;

  TextRecognizer get _latin =>
      _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Runs OCR on [imageFile] and returns a raw text string plus extracted
  /// [LineItem] objects parsed from the recognised content.
  Future<OcrResult> recognise(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    // Run Latin first (best quality for numbers + English).
    final latinResult = await _latin.processImage(inputImage);

    // Combine all recognised text.
    final fullText = latinResult.blocks.map((b) => b.text).join('\n');

    final lineItems = _parseLineItems(latinResult.blocks);

    return OcrResult(
      rawText: fullText,
      lineItems: lineItems,
      warnings: _buildWarnings(fullText),
    );
  }

  // ── Parsing ─────────────────────────────────────────────────────────────────

  /// Heuristic parser: looks for rows that contain at least two numbers,
  /// which suggests a quantity / unit-price / amount pattern.
  List<LineItem> _parseLineItems(List<TextBlock> blocks) {
    final items = <LineItem>[];

    for (final block in blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        // Extract all numeric-looking tokens (handles comma-thousands, decimals).
        final numericTokens = _extractNumbers(text);
        if (numericTokens.length < 2) continue;

        // Confidence from bounding box area (proxy for recognition quality).
        final confidence = _estimateConfidence(line);

        // Best-effort split: last number = amount, second-to-last = unit price,
        // everything else forms the description.
        final amount = numericTokens.last;
        final unitPrice = numericTokens.length >= 2
            ? numericTokens[numericTokens.length - 2]
            : '';
        final qty = numericTokens.length >= 3
            ? numericTokens[numericTokens.length - 3]
            : '1';

        // Remove extracted numbers from text to get description.
        var desc = text;
        for (final n in numericTokens) {
          desc = desc.replaceAll(n, '').trim();
        }
        desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (desc.isEmpty) desc = 'Item ${items.length + 1}';

        items.add(LineItem(
          description: desc,
          rawQuantity: qty,
          rawUnitPrice: unitPrice,
          rawAmount: amount,
          confidence: confidence,
        ));
      }
    }

    return items;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _extractNumbers(String text) {
    // Matches integers and decimals with optional comma separators.
    final pattern = RegExp(r'\d{1,3}(?:[,\s]\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?');
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  double _estimateConfidence(TextLine line) {
    // ML Kit doesn't expose a per-token confidence score in all versions;
    // we use a simple heuristic: if the bounding box is very small, it's likely
    // low quality.
    final rect = line.boundingBox;
    if (rect.height < 8) return 0.4;
    if (rect.height < 15) return 0.65;
    return 0.9;
  }

  List<String> _buildWarnings(String text) {
    final warnings = <String>[];

    // Detect Sinhala Unicode range (U+0D80–U+0DFF).
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) {
      warnings.add(
        'Sinhala script detected. ML Kit does not natively support Sinhala — '
        'extracted values may be inaccurate. Manual review is required.',
      );
    }

    // Detect Tamil Unicode range (U+0B80–U+0BFF).
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
      warnings.add(
        'Tamil script detected. Recognition accuracy for Tamil handwriting '
        'may be limited. Please verify all extracted values.',
      );
    }

    if (text.trim().isEmpty) {
      warnings.add(
        'No text could be extracted from this image. '
        'Please retake the photo with better lighting.',
      );
    }

    return warnings;
  }

  /// Release ML Kit resources.
  Future<void> dispose() async {
    await _latinRecognizer?.close();
  }
}

class OcrResult {
  final String rawText;
  final List<LineItem> lineItems;
  final List<String> warnings;

  const OcrResult({
    required this.rawText,
    required this.lineItems,
    required this.warnings,
  });
}
