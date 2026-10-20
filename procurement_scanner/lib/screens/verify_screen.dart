import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../models/document_scan.dart';
import '../services/ocr_service.dart';
import '../services/calculator_service.dart';
import '../theme.dart';
import 'results_screen.dart';

/// Screen 3 — Shows the cropped image and triggers OCR + verification.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.originalImage,
    required this.croppedImage,
  });

  final File originalImage;
  final File croppedImage;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _processing = false;
  String _statusText = '';

  Future<void> _verifyDocument() async {
    setState(() {
      _processing = true;
      _statusText = 'Running OCR…';
    });

    try {
      // Step 1: OCR
      final ocrResult =
          await OcrService.instance.recognise(widget.croppedImage);

      if (!mounted) return;
      setState(() => _statusText = 'Verifying calculations…');

      // Step 2: Calculate & verify
      final verResult = CalculatorService.instance.verify(
        items: ocrResult.lineItems,
        rawText: ocrResult.rawText,
        ocrWarnings: ocrResult.warnings,
      );

      if (!mounted) return;

      final scan = DocumentScan(
        originalImage: widget.originalImage,
        croppedImage: widget.croppedImage,
        lineItems: ocrResult.lineItems,
        verificationResult: verResult,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(scan: scan)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusText = '';
      });
      _showError('Verification failed: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Verify Document'),
        backgroundColor: AppTheme.background,
        leading: _processing
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Cropped image preview ───────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.06),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    widget.croppedImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.97),
            ),

            // ── Hint / status ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (!_processing) ...[
                    _InfoCard(),
                    const Gap(16),
                  ] else ...[
                    _ProcessingIndicator(status: _statusText),
                    const Gap(16),
                  ],
                ],
              ),
            ),

            // ── Action buttons ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _verifyDocument,
                  icon: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fact_check_rounded),
                  label: Text(
                    _processing ? 'Processing…' : 'Verify Document',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
          Gap(10),
          Expanded(
            child: Text(
              'Tap "Verify Document" to run on-device AI recognition '
              'and check the financial calculations.',
              style: TextStyle(
                  color: AppTheme.textSecond, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
          const Gap(14),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(color: AppTheme.textSecond, fontSize: 14),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: AppTheme.primary.withOpacity(0.15),
        );
  }
}
