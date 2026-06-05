import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Top chrome shared by the onboarding screens (Auth·07–11): the Sona lockup on
/// the left and a context label on the right.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, this.trailingLabel = 'Group Practice Setup'});

  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: const BoxDecoration(
        color: SonaColors.surface,
        border: Border(bottom: BorderSide(color: SonaColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: SonaColors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sona',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SonaColors.textPrimary,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              trailingLabel,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SonaColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
