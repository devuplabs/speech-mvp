import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sona/config/env.dart';
import 'package:sona/services/api_client.dart';

/// End-to-end MVP demo: parent intake → clinician prep/triage/publish → parent view.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> with SingleTickerProviderStateMixin {
  final _api = SonaApiClient();
  late final TabController _tabs;

  String? _tenantId;
  String? _activeCaseId;
  Map<String, dynamic>? _caseDetail;
  String? _parentSummaryHtml;
  String? _message;
  bool _busy = false;

  final _childNameCtrl = TextEditingController(text: 'Demo child');
  final _parentEmailCtrl = TextEditingController(text: 'parent@example.com');
  final _caseIdCtrl = TextEditingController();
  final _concernCtrl = TextEditingController(text: 'speech_delay');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _childNameCtrl.dispose();
    _parentEmailCtrl.dispose();
    _caseIdCtrl.dispose();
    _concernCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _message = '$label…';
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _message = '$label failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _ensureTenant() async {
    _tenantId ??= await _api.bootstrapDemoTenant();
    setState(() => _message = 'Tenant: $_tenantId');
  }

  Future<void> _refreshCase() async {
    final id = _activeCaseId ?? _caseIdCtrl.text.trim();
    if (id.isEmpty) return;
    final detail = await _api.getCase(id);
    setState(() {
      _activeCaseId = id;
      _caseDetail = detail;
      _caseIdCtrl.text = id;
      final c = detail['case'] as Map<String, dynamic>?;
      _message = 'Case status: ${c?['status'] ?? '?'}';
    });
  }

  Future<void> _parentStartIntake() async {
    await _ensureTenant();
    final caseRow = await _api.createCase(
      tenantId: _tenantId!,
      childDisplayName: _childNameCtrl.text.trim(),
      parentEmail: _parentEmailCtrl.text.trim(),
    );
    final caseId = caseRow['id'] as String;
    await _api.submitIntake(
      caseId,
      answers: {
        'concerns': [_concernCtrl.text.trim()],
        'age_months': 36,
        'consent': true,
      },
      parentEmail: _parentEmailCtrl.text.trim(),
      childDisplayName: _childNameCtrl.text.trim(),
    );
    setState(() {
      _activeCaseId = caseId;
      _caseIdCtrl.text = caseId;
      _message = 'Intake submitted. Case ID copied to clinician tab.';
    });
    await _refreshCase();
    _tabs.animateTo(1);
  }

  Future<void> _clinicianTriage(String outcome) async {
    final id = _activeCaseId ?? _caseIdCtrl.text.trim();
    if (id.isEmpty) return;
    await _api.recordTriage(id, outcome: outcome, reason: 'Demo triage');
    await _refreshCase();
  }

  Future<void> _clinicianPublish() async {
    final id = _activeCaseId ?? _caseIdCtrl.text.trim();
    if (id.isEmpty) return;
    await _api.publishParentSummary(id);
    await _refreshCase();
    setState(() => _message = 'Summary published — parent can open Parent tab.');
    _tabs.animateTo(2);
  }

  Future<void> _parentViewSummary() async {
    final id = _caseIdCtrl.text.trim();
    if (id.isEmpty) return;
    final html = await _api.fetchParentSummaryHtml(id);
    setState(() {
      _parentSummaryHtml = html;
      _message = 'Loaded portal summary for case $id';
    });
  }

  @override
  Widget build(BuildContext context) {
    final drafts = (_caseDetail?['drafts'] as List<dynamic>?) ?? [];
    final caseMap = _caseDetail?['case'] as Map<String, dynamic>?;
    final intake = _caseDetail?['intake'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sona MVP demo'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Parent'),
            Tab(text: 'Clinician'),
            Tab(text: 'Parent view'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _panel(
            title: '1. Parent intake (synthetic)',
            children: [
              TextField(
                controller: _childNameCtrl,
                decoration: const InputDecoration(labelText: 'Child display name'),
              ),
              TextField(
                controller: _parentEmailCtrl,
                decoration: const InputDecoration(labelText: 'Parent email (demo)'),
              ),
              TextField(
                controller: _concernCtrl,
                decoration: const InputDecoration(labelText: 'Primary concern key'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run('Intake', _parentStartIntake),
                child: const Text('Submit intake'),
              ),
              if (_activeCaseId != null) ...[
                const SizedBox(height: 12),
                SelectableText('Case ID:\n$_activeCaseId'),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _activeCaseId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Case ID copied')),
                    );
                  },
                  child: const Text('Copy case ID'),
                ),
              ],
            ],
          ),
          _panel(
            title: '2. Clinician consult prep',
            children: [
              TextField(
                controller: _caseIdCtrl,
                decoration: const InputDecoration(labelText: 'Case ID'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run('Refresh', _refreshCase),
                child: const Text('Load / refresh case'),
              ),
              if (caseMap != null) ...[
                const SizedBox(height: 8),
                Text('Status: ${caseMap['status']}'),
                Text('Child: ${caseMap['childDisplayName'] ?? '—'}'),
              ],
              if (intake != null) ...[
                const SizedBox(height: 8),
                Text('Intake answers: ${intake['answers']}'),
              ],
              const SizedBox(height: 8),
              const Text('Prep brief / plans:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...drafts.map((d) {
                final m = d as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text('${m['kind']} (${m['modelId']})'),
                  subtitle: Text('${m['content']}'),
                );
              }),
              const Divider(),
              const Text('Triage'),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in [
                    'strategy_only',
                    'short_block',
                    'full_assessment',
                    'refer_out',
                  ])
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run('Triage', () => _clinicianTriage(o)),
                      child: Text(o),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _run('Publish', _clinicianPublish),
                child: const Text('Publish parent summary (portal)'),
              ),
            ],
          ),
          _panel(
            title: '3. Parent portal view',
            children: [
              TextField(
                controller: _caseIdCtrl,
                decoration: const InputDecoration(labelText: 'Case ID from clinician'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run('Load summary', _parentViewSummary),
                child: const Text('Open published summary'),
              ),
              if (_parentSummaryHtml != null) ...[
                const SizedBox(height: 12),
                Text(
                  _stripHtml(_parentSummaryHtml!),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('API: ${Env.apiBaseUrl}', style: Theme.of(context).textTheme.bodySmall),
              if (_message != null) Text(_message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel({required String title, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
