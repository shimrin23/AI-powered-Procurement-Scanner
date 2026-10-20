import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../theme.dart';
import 'scan_screen.dart';

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

              Text(
                'Scan handwritten procurement documents in Sinhala, Tamil, and English. '
                'Extract financial data offline, verify calculations, and generate PDF reports.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecond,
                      height: 1.6,
                    ),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

              const Gap(40),

              // ── Feature chips ─────────────────────────────────────────────
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _FeatureChip(
                      icon: Icons.wifi_off_rounded, label: '100% Offline'),
                  _FeatureChip(
                      icon: Icons.language_rounded,
                      label: 'Sinhala • Tamil • English'),
                  _FeatureChip(
                      icon: Icons.calculate_rounded, label: 'Auto-Verify'),
                  _FeatureChip(
                      icon: Icons.picture_as_pdf_rounded, label: 'PDF Reports'),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

              const Gap(48),

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

              // ── Sub-caption ───────────────────────────────────────────────
              Center(
                child: Text(
                  'No login • No cloud • No internet required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ).animate().fadeIn(delay: 500.ms),
              ),

              const Gap(48),

              // ── Info cards ────────────────────────────────────────────────
              _HowItWorksSection().animate().fadeIn(delay: 600.ms),
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

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const Gap(6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecond,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecond,
              ),
        ),
        const Gap(16),
        const _Step(
          number: '1',
          title: 'Scan & Crop',
          description:
              'Capture the document with your camera and crop to the relevant area.',
          icon: Icons.crop_rounded,
        ),
        const _Step(
          number: '2',
          title: 'AI Recognition',
          description:
              'On-device AI reads the handwritten values — no internet needed.',
          icon: Icons.psychology_rounded,
        ),
        const _Step(
          number: '3',
          title: 'Verify & Review',
          description:
              'Calculations are checked automatically. You can correct any field.',
          icon: Icons.fact_check_rounded,
        ),
        const _Step(
          number: '4',
          title: 'Download PDF',
          description:
              'Export a full verification report with all extracted data.',
          icon: Icons.picture_as_pdf_rounded,
          isLast: true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step line.
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 24,
                  color: AppTheme.border,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          const Gap(14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecond,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
