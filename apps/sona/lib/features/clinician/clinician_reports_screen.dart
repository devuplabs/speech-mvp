import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';

class ClinicianReportsScreen extends StatelessWidget {
  const ClinicianReportsScreen({
    super.key,
    required this.items,
    required this.onRefresh,
    required this.onDownloadPdf,
    required this.onViewReport,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onDownloadPdf;
  final ValueChanged<String> onViewReport;
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
                child: Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              TextButton(onPressed: () => onRefresh(), child: const Text('Refresh')),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No clinical reports yet. Reports are created when you publish a parent summary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SonaColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(32),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _row(context, items[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> item) {
    final caseId = item['caseId'] as String;
    final name = (item['childDisplayName'] as String?) ?? 'Child';
    final title = (item['title'] as String?) ?? 'Clinical report';
    final created = _relative(item['createdAt'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SonaColors.aiBadgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI draft',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SonaColors.aiBadgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Updated $created', style: const TextStyle(fontSize: 11, color: SonaColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SonaButton(
                label: 'View',
                variant: SonaButtonVariant.secondary,
                onPressed: () => onViewReport(caseId),
              ),
              SonaButton(
                label: 'Download PDF',
                variant: SonaButtonVariant.secondary,
                onPressed: () => onDownloadPdf(caseId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relative(String? iso) {
    if (iso == null) return 'recently';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'just now';
  }
}
