import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/utils/api_errors.dart';

/// Stage 9 · Carryover — clinician curates home-practice resources, shares the
/// family portal link and reviews the progress log for one case.
///
/// Talks to the carryover endpoints directly (`/v1/cases/:id/carryover/*`,
/// `/v1/cases/:id/portal-links`) via the injected [SonaApiClient]; the shell
/// only supplies the case detail (for the child's name and the session-plan
/// draft used by "Import from session plan").
class ClinicianCarryoverScreen extends StatefulWidget {
  const ClinicianCarryoverScreen({
    super.key,
    required this.api,
    required this.caseId,
    required this.webBaseUrl,
    required this.onBack,
    this.caseDetail,
  });

  final SonaApiClient api;
  final String caseId;

  /// Web origin the family opens the portal on; the share action composes
  /// `<webBaseUrl>/?portal=<token>` — the format the family portal consumes.
  final String webBaseUrl;
  final VoidCallback onBack;

  /// Shape: `{case: {...}, intake: {...} | null, drafts: [{id, kind, content}]}`.
  final Map<String, dynamic>? caseDetail;

  @override
  State<ClinicianCarryoverScreen> createState() =>
      _ClinicianCarryoverScreenState();
}

const carryoverCategories = <(String value, String label)>[
  ('home_practice', 'Home practice'),
  ('reading', 'Reading'),
  ('activity', 'Activity'),
  ('other', 'Other'),
];

String carryoverCategoryLabel(String? value) {
  for (final (v, label) in carryoverCategories) {
    if (v == value) return label;
  }
  return 'Other';
}

class _ClinicianCarryoverScreenState extends State<ClinicianCarryoverScreen> {
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _childName {
    final caseMap = widget.caseDetail?['case'] as Map<String, dynamic>?;
    final name = (caseMap?['childDisplayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final answers =
        widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    final fromIntake = (answers?['childName'] as String?)?.trim();
    if (fromIntake != null && fromIntake.isNotEmpty) return fromIntake;
    return 'Client';
  }

  Map<String, dynamic>? get _sessionPlanDraft {
    final drafts =
        (widget.caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    for (final d in drafts) {
      if (d['kind'] == 'session_plan') return d;
    }
    return null;
  }

  List<String> get _homePracticeItems {
    final sections = (_sessionPlanDraft?['content']
        as Map<String, dynamic>?)?['sections'] as Map<String, dynamic>?;
    final raw = sections?['homePractice'];
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resources = await widget.api.listCarryoverResources(widget.caseId);
      final entries = await widget.api.listCarryoverProgress(widget.caseId);
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyApiError(e);
        _loading = false;
      });
    }
  }

  /// Wraps a mutation: busy flag, friendly error snackbar, refresh on success.
  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addResource() async {
    final result = await showDialog<CarryoverResourceFormResult>(
      context: context,
      builder: (_) => const CarryoverResourceDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await widget.api.createCarryoverResource(
        widget.caseId,
        title: result.title,
        category: result.category,
        description: result.description,
        url: result.url,
      );
      await _load();
    });
  }

  Future<void> _editResource(Map<String, dynamic> resource) async {
    final result = await showDialog<CarryoverResourceFormResult>(
      context: context,
      builder: (_) => CarryoverResourceDialog(existing: resource),
    );
    if (result == null) return;
    await _run(() async {
      await widget.api.updateCarryoverResource(
        widget.caseId,
        resource['id'] as String,
        title: result.title,
        category: result.category,
        description: result.description,
        url: result.url,
      );
      await _load();
    });
  }

  Future<void> _removeResource(Map<String, dynamic> resource) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove resource?'),
        content: Text(
          '"${resource['title']}" will no longer be visible to the family on the portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await widget.api
          .deleteCarryoverResource(widget.caseId, resource['id'] as String);
      await _load();
    });
  }

  /// One-tap import of the session-plan draft's `homePractice` bullets as
  /// `home_practice` resources. Items whose title is already shared (matched
  /// case-insensitively) are skipped so re-tapping never duplicates.
  Future<void> _importFromSessionPlan() async {
    final items = _homePracticeItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No session-plan home practice items to import yet.'),
        ),
      );
      return;
    }
    final existingTitles = _resources
        .map((r) => ((r['title'] as String?) ?? '').trim().toLowerCase())
        .toSet();
    final toImport = items
        .where((t) => !existingTitles.contains(t.trim().toLowerCase()))
        .toList();
    if (toImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All session-plan items are already shared.'),
        ),
      );
      return;
    }
    final draftId = _sessionPlanDraft?['id'] as String?;
    final skipped = items.length - toImport.length;
    await _run(() async {
      for (final title in toImport) {
        await widget.api.createCarryoverResource(
          widget.caseId,
          title: title,
          category: 'home_practice',
          sourceDraftId: draftId,
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skipped > 0
                  ? 'Imported ${toImport.length} item(s) from the session plan ($skipped already shared).'
                  : 'Imported ${toImport.length} item(s) from the session plan.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _shareWithFamily() async {
    await _run(() async {
      final link = await widget.api.createPortalLink(widget.caseId);
      final token = link['token'] as String;
      final url = '${widget.webBaseUrl}/?portal=$token';
      if (mounted) {
        await showPortalLinkCopiedSnackBar(context, url: url);
      }
    });
  }

  Future<void> _revokePortalLinks() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke portal access?'),
        content: const Text(
          'The family will no longer be able to open any previously shared portal link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await widget.api.revokePortalLinks(widget.caseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portal access revoked.')),
        );
      }
    });
  }

  Future<void> _submitNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;
    await _run(() async {
      await widget.api.addCarryoverProgressNote(widget.caseId, note: note);
      _noteController.clear();
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorBody()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _resourcesCard(),
                              const SizedBox(height: 16),
                              _shareCard(),
                              const SizedBox(height: 16),
                              _progressCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      decoration: const BoxDecoration(
        color: SonaColors.surface,
        border: Border(bottom: BorderSide(color: SonaColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton(onPressed: widget.onBack, child: const Text('← Back')),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Refresh'),
              ),
            ],
          ),
          Text(
            'Carryover & home practice · $_childName',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Curate what the family sees on their portal and keep an eye on practice between sessions.',
            style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'Something went wrong.',
              style: const TextStyle(color: SonaColors.dangerText)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _resourcesCard() {
    return _card(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Shared resources',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: _busy ? null : _importFromSessionPlan,
              child: const Text('Import from session plan'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _addResource,
              child: const Text('Add resource'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_resources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No resources shared yet. Add one or import the session-plan home practice.',
              style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
            ),
          )
        else
          ..._resources.map(_resourceRow),
      ],
    );
  }

  Widget _resourceRow(Map<String, dynamic> resource) {
    final title = (resource['title'] as String?) ?? '';
    final description = (resource['description'] as String?)?.trim();
    final url = (resource['url'] as String?)?.trim();
    final category = resource['category'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SonaColors.heroTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        carryoverCategoryLabel(category),
                        style: const TextStyle(
                            fontSize: 11, color: SonaColors.primaryDark),
                      ),
                    ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: SonaColors.textSecondary,
                          height: 1.35)),
                ],
                if (url != null && url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(url,
                      style: const TextStyle(
                          fontSize: 12, color: SonaColors.primary)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _editResource(resource),
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _removeResource(resource),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _shareCard() {
    return _card(
      children: [
        const Text('Family portal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Share a secure link so the family can see the summary, resources and log practice — no account needed. Links last 90 days.',
          style: TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : _shareWithFamily,
              child: const Text('Share with family'),
            ),
            TextButton(
              onPressed: _busy ? null : _revokePortalLinks,
              child: const Text('Revoke access'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progressCard() {
    return _card(
      children: [
        const Text('Progress log',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Add a note for this case',
                  hintText: 'e.g. Introduced the home practice pack in session',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _submitNote,
              child: const Text('Add note'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_entries.isEmpty)
          const Text(
            'No progress logged yet. Family entries from the portal will appear here.',
            style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
          )
        else
          ..._entries.map(_progressRow),
      ],
    );
  }

  Widget _progressRow(Map<String, dynamic> entry) {
    final isParent = entry['author'] == 'parent';
    final note = (entry['note'] as String?) ?? '';
    final rating = entry['rating'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isParent ? SonaColors.successBg : SonaColors.heroTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isParent ? 'Family' : 'Clinician',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isParent
                    ? SonaColors.successText
                    : SonaColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note, style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 2),
                Text(
                  rating == null
                      ? _relative(entry['createdAt'] as String?)
                      : '${_ratingLabel(rating)} · ${_relative(entry['createdAt'] as String?)}',
                  style: const TextStyle(
                      fontSize: 12, color: SonaColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(String rating) => switch (rating) {
        'tried_it' => 'Tried it',
        'going_well' => 'Going well',
        'finding_it_hard' => 'Finding it hard',
        _ => rating,
      };

  String _relative(String? iso) {
    if (iso == null) return 'Recently';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

/// Copies the portal URL and surfaces it — same copy-link pattern as
/// `showIntakeLinkCopiedSnackBar` for intake links.
Future<void> showPortalLinkCopiedSnackBar(
  BuildContext context, {
  required String url,
}) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Portal link copied. Share with the family: $url'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Copy again',
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      ),
    ),
  );
}

class CarryoverResourceFormResult {
  const CarryoverResourceFormResult({
    required this.title,
    required this.category,
    this.description,
    this.url,
  });

  final String title;
  final String category;
  final String? description;
  final String? url;
}

/// Add/edit dialog. Title is required; description/url optional; category via
/// a fixed picker matching the API enum.
class CarryoverResourceDialog extends StatefulWidget {
  const CarryoverResourceDialog({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<CarryoverResourceDialog> createState() =>
      _CarryoverResourceDialogState();
}

class _CarryoverResourceDialogState extends State<CarryoverResourceDialog> {
  late final _title =
      TextEditingController(text: (widget.existing?['title'] as String?) ?? '');
  late final _description = TextEditingController(
      text: (widget.existing?['description'] as String?) ?? '');
  late final _url =
      TextEditingController(text: (widget.existing?['url'] as String?) ?? '');
  late String _category =
      (widget.existing?['category'] as String?) ?? 'home_practice';
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    final description = _description.text.trim();
    final url = _url.text.trim();
    Navigator.pop(
      context,
      CarryoverResourceFormResult(
        title: title,
        category: _category,
        description: description.isEmpty ? null : description,
        url: url.isEmpty ? null : url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit resource' : 'Add resource'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  errorText: _titleError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Link (https://…)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Category',
                  style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in carryoverCategories)
                    ChoiceChip(
                      label: Text(label),
                      selected: _category == value,
                      onSelected: (_) => setState(() => _category = value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
