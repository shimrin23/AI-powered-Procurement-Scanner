import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import 'scan_screen.dart';
import 'verify_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo / Icon ───────────────────────────────────────────────
              Center(
                child: _LogoWidget(),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

              const Gap(32),

              // ── Title ──────────────────────────────────────────────────────
              Text(
                'Procurement\nScanner',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      fontSize: 38,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 600.ms)
                  .slideX(begin: -0.1),

              const Gap(16),

              const Gap(40),

              // ── Scan button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openScan(context),
                  icon: const Icon(Icons.document_scanner_rounded, size: 22),
                  label: const Text('Scan Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                    elevation: 8,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .scaleXY(begin: 0.95),
              ),

              const Gap(16),

              // ── Import from Gallery button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickFromGallery(context),
                  icon: const Icon(Icons.photo_library_rounded, size: 22),
                  label: const Text('Import from Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(56),
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 600.ms)
                    .scaleXY(begin: 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 100,
      );

      if (pickedFiles.isEmpty || !context.mounted) return;

      final originalFiles = <File>[];
      final croppedFiles = <File>[];

      for (int i = 0; i < pickedFiles.length; i++) {
        final original = File(pickedFiles[i].path);
        originalFiles.add(original);

        final pageTitle = pickedFiles.length > 1
            ? 'Crop Page ${i + 1} of ${pickedFiles.length}'
            : 'Crop Document';

        final cropped = await ImageCropper().cropImage(
          sourcePath: original.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: pageTitle,
              toolbarColor: AppTheme.surface,
              toolbarWidgetColor: Colors.white,
              backgroundColor: AppTheme.background,
              activeControlsWidgetColor: AppTheme.primary,
              hideBottomControls: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
          ],
        );

        // If user cancelled cropping on a page, use original image for that page
        croppedFiles.add(cropped != null ? File(cropped.path) : original);
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyScreen(
            originalImages: originalFiles,
            croppedImages: croppedFiles,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick images: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.document_scanner_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }
}
