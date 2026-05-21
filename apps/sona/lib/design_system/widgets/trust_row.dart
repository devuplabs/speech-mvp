import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

class TrustRow extends StatelessWidget {
  const TrustRow({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: SonaColors.successBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            '✓',
            style: TextStyle(
              color: SonaColors.successText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
