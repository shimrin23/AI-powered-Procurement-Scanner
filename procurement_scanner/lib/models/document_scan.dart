import 'dart:io';
import 'line_item.dart';
import 'verification_result.dart';

/// Holds all data for a single scanning session.
class DocumentScan {
  /// The original full-resolution captured images.
  final List<File> originalImages;

  /// The user-cropped versions of the document pages.
  final List<File> croppedImages;

  /// Backward-compatibility getter for single-page access.
  File get originalImage =>
      originalImages.isNotEmpty ? originalImages.first : File('');

  /// Backward-compatibility getter for single-page access.
  File get croppedImage =>
      croppedImages.isNotEmpty ? croppedImages.first : File('');

  /// Line items extracted by the OCR service and potentially edited by the user.
  List<LineItem> lineItems;

  /// Verification result, populated after the user triggers "Verify Document".
  VerificationResult? verificationResult;

  /// Timestamp of the scan.
  final DateTime scannedAt;

  DocumentScan({
    List<File>? originalImages,
    List<File>? croppedImages,
    File? originalImage,
    File? croppedImage,
    required this.lineItems,
    this.verificationResult,
    DateTime? scannedAt,
  })  : originalImages = originalImages ??
            (originalImage != null ? [originalImage] : <File>[]),
        croppedImages = croppedImages ??
            (croppedImage != null ? [croppedImage] : <File>[]),
        scannedAt = scannedAt ?? DateTime.now();
}
