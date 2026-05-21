import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';

class ClinicianTriageScreen extends StatelessWidget {
  const ClinicianTriageScreen({
    super.key,
    required this.onPublishSummary,
    required this.onBackPrep,
    this.busy = false,
  });

  final VoidCallback onPublishSummary;
  final VoidCallback onBackPrep;
  final bool busy;

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
              TextButton(onPressed: onBackPrep, child: const Text('← Consult prep')),
              const Text('Aria M. · Free consultation complete', style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
              const Text('Triage & session plan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                    children: [
                      _triageCard(),
                      const SizedBox(height: 16),
                      _planCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: SonaColors.surface,
                          border: Border.all(color: SonaColors.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Next step', style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text(
                              'Publish a parent-friendly summary to the secure portal. No clinical detail in email.',
                              style: TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : onPublishSummary,
                        child: Text(busy ? 'Publishing…' : 'Publish parent summary'),
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

  Widget _triageCard() {
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
              Text('Triage outcome', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Speech sound disorder', selected: true),
              _chip('Feeding concern', selected: true),
              _chip('Language delay', selected: false),
              _chip('Refer onward', selected: false),
            ],
          ),
          const SizedBox(height: 14),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Clinician notes (internal)',
              hintText: 'Articulation assessment recommended; monitor feeding…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard() {
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
              Text('Session plan (draft)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Spacer(),
              AiDraftBadge(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            'Formal assessment — speech sounds (DEAP)',
            'Parent strategies — carry-over at home',
            'Review in 4 weeks',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(value: true, onChanged: (_) {}, activeColor: SonaColors.primary),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? SonaColors.navActiveBg : SonaColors.background,
        border: Border.all(color: selected ? SonaColors.primary : SonaColors.chipBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? SonaColors.primaryDark : SonaColors.textSecondary,
        ),
      ),
    );
  }
}
