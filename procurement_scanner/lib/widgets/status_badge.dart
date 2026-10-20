import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/verification_result.dart';
import '../theme.dart';

/// A prominent banner that shows the overall verification status.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.status});
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cfg.color.withOpacity(0.15), cfg.color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cfg.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 26),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    color: cfg.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(3),
                Text(
                  status.description,
                  style: const TextStyle(
                    color: AppTheme.textSecond,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig get _config {
    switch (status) {
      case VerificationStatus.calculationsMatch:
        return _StatusConfig(
          icon: Icons.check_circle_rounded,
          color: AppTheme.accent,
        );
      case VerificationStatus.discrepancyDetected:
        return _StatusConfig(
          icon: Icons.error_rounded,
          color: AppTheme.error,
        );
      case VerificationStatus.manualReviewRequired:
        return _StatusConfig(
          icon: Icons.pending_rounded,
          color: AppTheme.warning,
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  const _StatusConfig({required this.icon, required this.color});
}
