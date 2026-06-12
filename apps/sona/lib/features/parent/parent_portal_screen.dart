import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';
import 'package:sona/design_system/widgets/trust_row.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/utils/open_url.dart';

/// Friendly relative label for portal timeline dates ("Today", "Yesterday",
/// "3 days ago", then an absolute British date). Kept top-level so tests can
/// pin the boundaries without pumping the whole screen.
String portalRelativeDate(DateTime then, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final thatDay = DateTime(then.year, then.month, then.day);
  final days = today.difference(thatDay).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 28) {
    final weeks = days ~/ 7;
    return weeks == 1 ? 'Last week' : '$weeks weeks ago';
  }
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${then.day} ${months[then.month - 1]} ${then.year}';
}

/// Stage 9 family progress portal — the parent/carer surface behind a
/// `?portal=<token>` magic link. Token-only (no account): shows the published
/// family summary, carryover resources shared by the clinician, and a
/// lightweight home-practice check-in log. No child-facing UI here.
class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final SonaApiClient api;
  final String token;

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  Map<String, dynamic>? _payload;
  bool _loading = true;

  /// 'expired' | 'revoked' | 'not_found' when the link was rejected.
  String? _inactiveReason;
  String? _loadError;

  final _noteController = TextEditingController();
  String? _rating;
  bool _submitting = false;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final payload = await widget.api.fetchPortalPayload(widget.token);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } on SonaApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode == 404 || e.statusCode == 410) {
          _inactiveReason = e.body.contains('expired')
              ? 'expired'
              : e.body.contains('revoked')
                  ? 'revoked'
                  : 'not_found';
        } else {
          _loadError = 'Something went wrong loading the portal. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Something went wrong loading the portal. Please try again.';
      });
    }
  }

  Future<void> _submitCheckIn() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short note first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.submitPortalProgress(
        widget.token,
        note: note,
        rating: _rating,
      );
      if (!mounted) return;
      _noteController.clear();
      setState(() => _rating = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you — your check-in has been shared with your clinician.'),
        ),
      );
      await _load();
    } on SonaApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404 || e.statusCode == 410) {
        setState(() {
          _payload = null;
          _inactiveReason = e.body.contains('expired') ? 'expired' : 'revoked';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We couldn't save your check-in. Please try again."),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("We couldn't save your check-in. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ParentMobileScaffold(
      body: _loading
          ? _loadingView()
          : _inactiveReason != null
              ? _inactiveView()
              : _loadError != null
                  ? _errorView()
                  : _portalView(),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Opening your family portal…', style: SonaTypography.body),
        ],
      ),
    );
  }

  Widget _inactiveView() {
    final detail = _inactiveReason == 'expired'
        ? 'Portal links expire after a while to keep your family’s information safe.'
        : 'Your clinician may have refreshed this link to keep your family’s information safe.';
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SonaColors.warningBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SonaColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.link_off, color: SonaColors.warningText, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'This link is no longer active — ask your clinician for a new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SonaColors.warningText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center, style: SonaTypography.body),
            const SizedBox(height: 16),
            SonaButton(
              label: 'Try again',
              expanded: false,
              onPressed: () => unawaited(_load()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portalView() {
    final payload = _payload!;
    final caseMap = payload['case'] as Map<String, dynamic>? ?? {};
    final childName = caseMap['childDisplayName'] as String?;
    final practiceName = payload['practiceName'] as String?;
    final summary = payload['summary'] as Map<String, dynamic>?;
    final resources = (payload['resources'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final progress = (payload['progress'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final expiresAt = DateTime.tryParse(payload['expiresAt'] as String? ?? '');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        _practiceHeader(practiceName),
        const SizedBox(height: 20),
        SonaPageTitle(
          childName != null && childName.trim().isNotEmpty
              ? 'Supporting $childName at home'
              : 'Supporting your child at home',
          style: SonaTypography.pageTitle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Everything your clinician has shared with your family, plus a place to tell them how practice is going.',
          style: SonaTypography.body,
        ),
        const SizedBox(height: 24),
        _summarySection(summary),
        const SizedBox(height: 24),
        _resourcesSection(resources),
        const SizedBox(height: 24),
        _checkInSection(),
        const SizedBox(height: 24),
        _timelineSection(progress),
        const SizedBox(height: 24),
        const TrustRow(
          title: 'Private family link',
          subtitle: 'Only people with this link can see this page',
        ),
        if (expiresAt != null) ...[
          const SizedBox(height: 10),
          Text(
            'This link works until ${_absoluteDate(expiresAt.toLocal())}.',
            style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _practiceHeader(String? practiceName) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SonaColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                practiceName ?? 'Your speech & language practice',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Text(
                'Family progress portal',
                style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────────

  Widget _summarySection(Map<String, dynamic>? summary) {
    final html = summary?['html'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your family summary', style: SonaTypography.screenTitle),
        const SizedBox(height: 10),
        if (html == null || html.trim().isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SonaColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SonaColors.border),
            ),
            child: const Text(
              'Your clinician will share your summary here once it’s ready.',
              style: SonaTypography.body,
            ),
          )
        else ...[
          const Align(alignment: Alignment.centerLeft, child: AiDraftBadge(compact: true)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SonaColors.heroTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SonaColors.border),
            ),
            child: Text(
              _stripHtml(html),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reviewed by your clinician before it was shared with you.',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
        ],
      ],
    );
  }

  // ── Resources ───────────────────────────────────────────────────────────

  static const _categoryOrder = ['home_practice', 'activity', 'reading', 'other'];

  static String _categoryLabel(String? category) => switch (category) {
        'home_practice' => 'Home practice',
        'reading' => 'Reading',
        'activity' => 'Activity',
        _ => 'Other',
      };

  Widget _resourcesSection(List<Map<String, dynamic>> resources) {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final r in resources) {
      final raw = r['category'] as String?;
      final key = _categoryOrder.contains(raw) ? raw! : 'other';
      byCategory.putIfAbsent(key, () => []).add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Things to try at home', style: SonaTypography.screenTitle),
        const SizedBox(height: 10),
        if (resources.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SonaColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SonaColors.border),
            ),
            child: const Text(
              'No resources shared yet. Anything your clinician shares will appear here.',
              style: SonaTypography.body,
            ),
          )
        else
          for (final category in _categoryOrder)
            if (byCategory.containsKey(category)) ...[
              _categoryBadge(_categoryLabel(category)),
              const SizedBox(height: 8),
              for (final resource in byCategory[category]!) ...[
                _resourceCard(resource),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
            ],
      ],
    );
  }

  Widget _categoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SonaColors.heroTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SonaColors.primaryDark,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _resourceCard(Map<String, dynamic> resource) {
    final title = resource['title'] as String? ?? '';
    final description = resource['description'] as String?;
    final url = resource['url'] as String?;
    final hasUrl = url != null && url.trim().isNotEmpty;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SonaColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (description != null && description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: SonaColors.textSecondary),
                  ),
                ],
                if (hasUrl) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Open link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SonaColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasUrl) const Icon(Icons.open_in_new, size: 18, color: SonaColors.primary),
        ],
      ),
    );

    if (!hasUrl) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openUrlInNewTab(url),
        child: card,
      ),
    );
  }

  // ── Check-in ────────────────────────────────────────────────────────────

  static const _ratingOptions = [
    (value: 'tried_it', label: 'We tried it'),
    (value: 'going_well', label: 'Going well'),
    (value: 'finding_it_hard', label: 'Finding it hard'),
  ];

  Widget _checkInSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.trustCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SonaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How is practice going?', style: SonaTypography.screenTitle),
          const SizedBox(height: 6),
          const Text(
            'Share a quick note with your clinician — little and often is perfect.',
            style: SonaTypography.body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. We practised the sound games after school twice this week…',
              filled: true,
              fillColor: SonaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _ratingOptions)
                _ratingPill(option.label, option.value),
            ],
          ),
          const SizedBox(height: 14),
          SonaButton(
            label: _submitting ? 'Sharing…' : 'Share with your clinician',
            onPressed: _submitting ? null : () => unawaited(_submitCheckIn()),
          ),
        ],
      ),
    );
  }

  Widget _ratingPill(String label, String value) {
    final selected = _rating == value;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _rating = selected ? null : value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? SonaColors.primary : SonaColors.surface,
              border: Border.all(
                color: selected ? SonaColors.primary : SonaColors.chipBorder,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : SonaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Timeline ────────────────────────────────────────────────────────────

  Widget _timelineSection(List<Map<String, dynamic>> progress) {
    final entries = [...progress];
    entries.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['createdAt'] as String? ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate); // newest first
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Past check-ins', style: SonaTypography.screenTitle),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const Text(
            'No check-ins yet — your first one will appear here.',
            style: SonaTypography.body,
          )
        else
          for (final entry in entries) ...[
            _timelineCard(entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _timelineCard(Map<String, dynamic> entry) {
    final author = entry['author'] as String?;
    final isParent = author == 'parent';
    final note = entry['note'] as String? ?? '';
    final rating = entry['rating'] as String?;
    final createdAt = DateTime.tryParse(entry['createdAt'] as String? ?? '');
    final ratingLabel = _ratingOptions
        .where((o) => o.value == rating)
        .map((o) => o.label)
        .firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isParent ? SonaColors.surface : SonaColors.heroTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SonaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isParent ? 'You' : 'Your clinician',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.primaryDark,
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  portalRelativeDate(createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (ratingLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SonaColors.successBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                ratingLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SonaColors.successText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _absoluteDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
