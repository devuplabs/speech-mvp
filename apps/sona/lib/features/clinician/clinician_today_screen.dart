import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/state/sona_app_state.dart';

class ClinicianTodayScreen extends StatelessWidget {
  const ClinicianTodayScreen({
    super.key,
    required this.state,
    required this.onOpenPrep,
  });

  final SonaAppState state;
  final VoidCallback onOpenPrep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: const BoxDecoration(
            color: SonaColors.surface,
            border: Border(bottom: BorderSide(color: SonaColors.border)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning, Monal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Monday, 11 May 2026', style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
                  ],
                ),
              ),
              Container(
                width: 280,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: SonaColors.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '⌕  Search clients, notes, resources…',
                  style: TextStyle(fontSize: 13, color: SonaColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(backgroundColor: SonaColors.accent, radius: 19, child: Text('MG', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
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
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _kpi('3', 'Consults today', SonaColors.primary),
                          const SizedBox(width: 16),
                          _kpi('1', 'Intake pending review', SonaColors.accent),
                          const SizedBox(width: 16),
                          _kpi('2', 'Plans to review', SonaColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: SonaColors.surface,
                          border: Border.all(color: SonaColors.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text("Today's free consultations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                            const Divider(height: 1),
                            _consultRow('10:30', 'Aria M.', '4y · Speech + feeding', state.prepStatus, onOpenPrep, highlight: true),
                            _consultRow('14:00', 'Leo T.', '6y · Stutter', 'Drafting', () {}),
                            _consultRow('16:30', 'Maya K.', '3y · Language delay', 'Not started', () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _sideCard('Up next', 'Aria M. · 10:30', 'Prep brief ${state.prepStatus.toLowerCase()}', onOpenPrep),
                      const SizedBox(height: 16),
                      _sideCard('Recent activity', 'Intake submitted · Aria', '2 min ago', onOpenPrep),
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

  Widget _kpi(String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SonaColors.surface,
          border: Border.all(color: SonaColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _consultRow(
    String time,
    String name,
    String meta,
    String status,
    VoidCallback onTap, {
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlight ? SonaColors.heroTint.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(meta, style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Ready' ? SonaColors.successBg : SonaColors.warningBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'Ready' ? SonaColors.successText : SonaColors.warningText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: SonaColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _sideCard(String title, String subtitle, String meta, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SonaColors.surface,
          border: Border.all(color: SonaColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 14)),
            Text(meta, style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
