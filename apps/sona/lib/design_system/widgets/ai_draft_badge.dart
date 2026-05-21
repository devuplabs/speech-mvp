import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

class AiDraftBadge extends StatelessWidget {
  const AiDraftBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: SonaColors.aiBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AI-drafted · clinician-reviewed',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: SonaColors.aiBadgeText,
        ),
      ),
    );
  }
}
