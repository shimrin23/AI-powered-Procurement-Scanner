import 'dart:io';
import 'line_item.dart';
import 'verification_result.dart';

/// Holds all data for a single scanning session.
class DocumentScan {
  /// The original full-resolution captured image.
  final File originalImage;

  /// The user-cropped version of the document.
  final File croppedImage;

  /// Line items extracted by the OCR service and potentially edited by the user.
  List<LineItem> lineItems;

  /// Verification result, populated after the user triggers "Verify Document".
  VerificationResult? verificationResult;

  /// Timestamp of the scan.
  final DateTime scannedAt;

  DocumentScan({
    required this.originalImage,
    required this.croppedImage,
    required this.lineItems,
    this.verificationResult,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();
}
