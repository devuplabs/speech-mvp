import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Decorative mobile status bar matching Figma frames.
class MobileStatusBar extends StatelessWidget {
  const MobileStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '9:41',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SonaColors.textPrimary,
            ),
          ),
          Row(
            children: [
              _bar(width: 16),
              const SizedBox(width: 6),
              _bar(width: 14),
              const SizedBox(width: 6),
              _bar(width: 24, radius: 2),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _bar({required double width, double radius = 1.5}) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: SonaColors.textPrimary,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
