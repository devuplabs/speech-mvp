import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/trust_row.dart';
import 'package:sona/features/clinician/clinician_case_row.dart';
import 'package:sona/features/clinician/new_patient_sheet.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/utils/case_status.dart';

class ClinicianClientsScreen extends StatefulWidget {
  const ClinicianClientsScreen({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onOpenCase,
    required this.onRegisterPatient,
    this.fetchSlots,
  });

  final SonaAppState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenCase;
  final RegisterPatientSubmit onRegisterPatient;
  final Future<List<Map<String, dynamic>>> Function()? fetchSlots;

  @override
  State<ClinicianClientsScreen> createState() => _ClinicianClientsScreenState();
}

class _ClinicianClientsScreenState extends State<ClinicianClientsScreen> {
  String _search = '';
  String? _statusFilter;

  List<Map<String, dynamic>> get _filteredCases {
    var list = List<Map<String, dynamic>>.from(widget.state.clinicianCases);
    list.sort((a, b) {
      final au = DateTime.tryParse(a['updatedAt'] as String? ?? '') ?? DateTime(1970);
      final bu = DateTime.tryParse(b['updatedAt'] as String? ?? '') ?? DateTime(1970);
      return bu.compareTo(au);
    });
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((c) => ((c['childDisplayName'] as String?) ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_statusFilter != null) {
      list = list.where((c) => c['status'] == _statusFilter).toList();
    }
    return list;
  }

  Future<void> _openNewPatient() async {
    await NewPatientSheet.show(
      context,
      onSubmit: widget.onRegisterPatient,
      fetchSlots: widget.fetchSlots,
    );
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final cases = _filteredCases;
    final allEmpty = widget.state.clinicianCases.isEmpty;

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
                child: Text('Clients', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 160,
                child: SonaButton(label: '+ New patient', onPressed: _openNewPatient),
              ),
            ],
          ),
        ),
        if (!allEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by child name',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('All', null),
                    _filterChip('Intake pending', 'intake_pending'),
                    _filterChip('Submitted', 'intake_submitted'),
                    _filterChip('Triaged', 'triaged'),
                    _filterChip('Plan ready', 'plan_ready'),
                    _filterChip('Summary sent', 'summary_sent'),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: allEmpty ? _emptyState() : _clientList(cases),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? status) {
    final selected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Register your first patient',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Start a new relationship in under a minute — capture parent contact details and share the intake link.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SonaColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              const TrustRow(
                title: 'UK data residency',
                subtitle: 'Your family\'s information stays in the UK.',
              ),
              const SizedBox(height: 12),
              const TrustRow(
                title: 'HCPC-registered clinician',
                subtitle: 'Monal Gajjar reviews every submission before your consult.',
              ),
              const SizedBox(height: 12),
              const TrustRow(
                title: 'Parent completes at home',
                subtitle: 'No extra screen time for children — adults fill the form.',
              ),
              const SizedBox(height: 28),
              SonaButton(label: 'Register your first patient', onPressed: _openNewPatient),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientList(List<Map<String, dynamic>> cases) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: SonaColors.surface,
          border: Border.all(color: SonaColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${cases.length} client${cases.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(onPressed: () => widget.onRefresh(), child: const Text('Refresh')),
                ],
              ),
            ),
            const Divider(height: 1),
            if (cases.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No clients match your search.', style: TextStyle(color: SonaColors.textSecondary)),
              )
            else
              ...cases.map((c) {
                final id = c['id'] as String;
                final name = (c['childDisplayName'] as String?) ?? 'Child';
                final email = (c['parentEmail'] as String?) ?? '';
                final status = prepLabelFromCaseStatus(c['status'] as String?);
                final updated = _relativeTime(c['updatedAt'] as String?);
                return ClinicianCaseRow(
                  leading: '—',
                  name: name,
                  meta: email.isEmpty ? updated : '$email · $updated',
                  statusLabel: status,
                  onTap: () => widget.onOpenCase(id),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _relativeTime(String? iso) {
    if (iso == null) return 'Recently';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Shows registration success with copy-to-clipboard intake link.
Future<void> showIntakeLinkCopiedSnackBar(
  BuildContext context, {
  required String url,
}) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Intake link copied. Share with the parent: $url'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Copy again',
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      ),
    ),
  );
}
