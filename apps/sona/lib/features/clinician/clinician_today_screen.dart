import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/utils/case_status.dart';

class ClinicianTodayScreen extends StatelessWidget {
  const ClinicianTodayScreen({
    super.key,
    required this.state,
    required this.onOpenPrep,
    required this.onRefresh,
  });

  final SonaAppState state;
  final ValueChanged<String> onOpenPrep;
  final Future<void> Function() onRefresh;

  List<Map<String, dynamic>> get _dashboardCases =>
      state.clinicianCases.where((c) => showCaseOnTodayDashboard(c['status'] as String?)).toList();

  // KPI counts — guaranteed to sum to _dashboardCases.length so the tiles
  // are always consistent (see KpiBucket in case_status.dart).
  int _kpiCount(KpiBucket bucket) => _dashboardCases
      .where((c) => kpiBucketFor(c['status'] as String?) == bucket)
      .length;

  @override
  Widget build(BuildContext context) {
    final cases = _dashboardCases;
    final activeId = state.caseId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: const BoxDecoration(
            color: SonaColors.surface,
            border: Border(bottom: BorderSide(color: SonaColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 720;
              final greeting = const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good morning, Monal', style: SonaTypography.clinicianGreeting),
                  Text('Monday, 11 May 2026', style: SonaTypography.label),
                ],
              );
              final search = Semantics(
                label: 'Search clients, notes, and resources',
                child: Container(
                  width: stackHeader ? double.infinity : 280,
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
              );
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    greeting,
                    const SizedBox(height: 12),
                    search,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: greeting),
                  search,
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: SonaColors.accent,
                    radius: 19,
                    child: const Text('MG', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 900;
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stack
                        ? Column(
                            children: [
                              _kpi('${cases.length}', 'Cases on dashboard', SonaColors.primary, expanded: false),
                              const SizedBox(height: 12),
                              _kpi('${_kpiCount(KpiBucket.newIntake)}', 'New intakes', SonaColors.accent, expanded: false),
                              const SizedBox(height: 12),
                              _kpi('${_kpiCount(KpiBucket.inProgress)}', 'In progress', SonaColors.textSecondary, expanded: false),
                              const SizedBox(height: 12),
                              _kpi('${_kpiCount(KpiBucket.summarySent)}', 'Summary sent', SonaColors.successText, expanded: false),
                            ],
                          )
                        : Row(
                            children: [
                              _kpi('${cases.length}', 'Cases on dashboard', SonaColors.primary),
                              const SizedBox(width: 16),
                              _kpi('${_kpiCount(KpiBucket.newIntake)}', 'New intakes', SonaColors.accent),
                              const SizedBox(width: 16),
                              _kpi('${_kpiCount(KpiBucket.inProgress)}', 'In progress', SonaColors.textSecondary),
                              const SizedBox(width: 16),
                              _kpi('${_kpiCount(KpiBucket.summarySent)}', 'Summary sent', SonaColors.successText),
                            ],
                          ),
                    const SizedBox(height: 24),
                    _consultList(cases, activeId),
                  ],
                );
                final aside = _buildAside(cases, activeId);
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [main, const SizedBox(height: 24), aside],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: main),
                    const SizedBox(width: 24),
                    Expanded(child: aside),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _consultList(List<Map<String, dynamic>> cases, String? activeId) {
    return Container(
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's cases (from API)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: () => onRefresh(), child: const Text('Refresh')),
              ],
            ),
          ),
          const Divider(height: 1),
          if (cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No submitted intakes yet. Complete the parent flow first — check all three consent boxes on review.',
                style: TextStyle(fontSize: 14, color: SonaColors.textSecondary, height: 1.4),
              ),
            )
          else
            ...cases.map((c) {
              final id = c['id'] as String;
              final name = (c['childDisplayName'] as String?) ?? 'Child';
              final status = prepLabelFromCaseStatus(c['status'] as String?);
              final apiStatus = c['status'] as String? ?? '';
              return _consultRow(
                'Intake',
                name,
                apiStatus.replaceAll('_', ' '),
                status,
                () => onOpenPrep(id),
                highlight: id == activeId,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAside(List<Map<String, dynamic>> cases, String? activeId) {
    if (cases.isEmpty) {
      return const SizedBox.shrink();
    }
    final primary = cases.firstWhere(
      (c) => c['id'] == activeId,
      orElse: () => cases.first,
    );
    final id = primary['id'] as String;
    final name = (primary['childDisplayName'] as String?) ?? 'Child';
    final label = prepLabelFromCaseStatus(primary['status'] as String?);
    return Column(
      children: [
        _sideCard('Up next', name, 'Prep brief · $label', () => onOpenPrep(id)),
        const SizedBox(height: 16),
        _sideCard('Recent activity', 'Intake submitted · $name', 'Just now', () => onOpenPrep(id)),
      ],
    );
  }

  Widget _kpi(String value, String label, Color accent, {bool expanded = true}) {
    final card = Container(
      width: expanded ? null : double.infinity,
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
    );
    if (!expanded) return card;
    return Expanded(child: card);
  }

  Widget _consultRow(
    String time,
    String name,
    String meta,
    String status,
    VoidCallback onTap, {
    bool highlight = false,
  }) {
    return Semantics(
      button: true,
      label: '$name consultation at $time, status $status',
      child: InkWell(
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
