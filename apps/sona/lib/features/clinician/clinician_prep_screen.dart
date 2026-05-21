import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';

class ClinicianPrepScreen extends StatelessWidget {
  const ClinicianPrepScreen({
    super.key,
    required this.onContinueTriage,
    required this.onBackToday,
  });

  final VoidCallback onContinueTriage;
  final VoidCallback onBackToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
          decoration: const BoxDecoration(
            color: SonaColors.surface,
            border: Border(bottom: BorderSide(color: SonaColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(onPressed: onBackToday, child: const Text('← Today')),
              const Text('Today / 10:30 · Free consultation', style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
              const Text('Consult prep · Aria M.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SonaColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text('⏱', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Consult starts in 18 minutes · Intake submitted 12 min ago',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SonaColors.warningText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _clientCard(),
                      const SizedBox(height: 16),
                      _prepBriefCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _panel('Red flags', const [
                        'Regression in language over 3 months',
                        'Limited variety of sounds in spontaneous speech',
                      ], SonaColors.dangerBg, SonaColors.dangerText),
                      const SizedBox(height: 16),
                      _panel('References', const [
                        'RCSLT — Speech sound disorder',
                        'NICE NG87 — Autism assessment',
                      ], SonaColors.heroTint, SonaColors.primaryDark),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onContinueTriage,
                        child: const Text('Mark consult complete → Triage'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _clientCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client', style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
          SizedBox(height: 6),
          Text('Aria M. · 4y 2m', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Parent: Anna M. · anna@example.com', style: TextStyle(fontSize: 13, color: SonaColors.textSecondary)),
          SizedBox(height: 4),
          Text('Concerns: Speech sounds, fussy eating', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _prepBriefCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Suggested probe areas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            'Confirm primary concern and onset from intake answers',
            'Check red flags (feeding, hearing, regression)',
            'EHCP status if indicated in intake',
          ].map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: SonaColors.primary, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(q, style: TextStyle(fontSize: 14, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, List<String> items, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(height: 8),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $i', style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
              )),
        ],
      ),
    );
  }
}
