import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/ai_draft_badge.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';

/// Tone + reading level + section toggle options sent to the API.
typedef ParentSummaryOptions = ({
  String tone,
  String readingLevel,
  bool whatWeDiscussed,
  bool planForFirstSession,
  bool homePractice,
  bool nextSteps,
  bool aiDisclosure,
});

const _defaultOptions = (
  tone: 'balanced',
  readingLevel: 'standard',
  whatWeDiscussed: true,
  planForFirstSession: true,
  homePractice: true,
  nextSteps: true,
  aiDisclosure: true,
);

/// Clinician parent-summary preview + controls + publish + PDF.
///
/// Per docs/mvp-brief.md → "Parent-friendly summary email/PDF with tone
/// slider (warm ↔ clinical), reading level, included-sections toggles".
///
/// The preview pane is server-rendered: every option change debounces a
/// POST to `/v1/cases/:id/parent-summary/preview` which returns the same
/// projection that publish + PDF will use. Once happy, the clinician
/// publishes — the bottom CTA hands the same options to the publish
/// endpoint, then offers a one-click PDF download.
class ClinicianParentSummaryScreen extends StatefulWidget {
  const ClinicianParentSummaryScreen({
    super.key,
    required this.caseId,
    required this.onPreview,
    required this.onPublish,
    required this.onDownloadPdf,
    required this.onBackPlan,
    this.busy = false,
    this.alreadyPublished = false,
  });

  /// The case the controls operate on. The shell uses this to drive the
  /// debounced preview API call.
  final String? caseId;
  final bool busy;
  final bool alreadyPublished;
  final Future<Map<String, dynamic>> Function(ParentSummaryOptions options)
      onPreview;
  final Future<void> Function(ParentSummaryOptions options) onPublish;

  /// Opens the PDF download (e.g. `window.open` on Flutter web). Sync to
  /// keep the call path the same on every platform; shell wires the actual
  /// `url_launcher` / `dart:html` call.
  final void Function() onDownloadPdf;
  final VoidCallback onBackPlan;

  @override
  State<ClinicianParentSummaryScreen> createState() =>
      _ClinicianParentSummaryScreenState();
}

class _ClinicianParentSummaryScreenState
    extends State<ClinicianParentSummaryScreen> {
  ParentSummaryOptions _options = _defaultOptions;
  Map<String, dynamic>? _projection;
  Timer? _debounce;
  bool _loadingPreview = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    if (widget.caseId == null) return;
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 250);
    _debounce = Timer(delay, () async {
      setState(() {
        _loadingPreview = true;
        _previewError = null;
      });
      try {
        final body = await widget.onPreview(_options);
        if (!mounted) return;
        setState(() {
          _projection = body['projection'] as Map<String, dynamic>?;
          _loadingPreview = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _previewError = e.toString();
          _loadingPreview = false;
        });
      }
    });
  }

  void _updateOptions(ParentSummaryOptions next) {
    setState(() => _options = next);
    _schedulePreview();
  }

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
              TextButton(
                onPressed: widget.onBackPlan,
                child: const Text('← Session plan'),
              ),
              const Text('Parent-facing summary',
                  style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
              const SonaPageTitle('Parent summary',
                  style: SonaTypography.clinicianTitle),
              const SizedBox(height: 6),
              const Row(
                children: [
                  AiDraftBadge(compact: true),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tweak tone + reading level. The preview is what the '
                      'parent sees in the portal + PDF.',
                      style: TextStyle(
                          fontSize: 12, color: SonaColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _controlsCard(),
                      const SizedBox(height: 16),
                      _previewCard(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: _controlsCard()),
                    const SizedBox(width: 24),
                    Expanded(child: _previewCard()),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tone', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Warm = informal + encouraging.  Clinical = neutral + factual.',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'warm', label: Text('Warm')),
              ButtonSegment(value: 'balanced', label: Text('Balanced')),
              ButtonSegment(value: 'clinical', label: Text('Clinical')),
            ],
            selected: {_options.tone},
            onSelectionChanged: widget.busy
                ? null
                : (s) {
                    _updateOptions((
                      tone: s.first,
                      readingLevel: _options.readingLevel,
                      whatWeDiscussed: _options.whatWeDiscussed,
                      planForFirstSession: _options.planForFirstSession,
                      homePractice: _options.homePractice,
                      nextSteps: _options.nextSteps,
                      aiDisclosure: _options.aiDisclosure,
                    ));
                  },
          ),
          const SizedBox(height: 20),
          const Text('Reading level',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'simple', label: Text('Simple')),
              ButtonSegment(value: 'standard', label: Text('Standard')),
              ButtonSegment(value: 'detailed', label: Text('Detailed')),
            ],
            selected: {_options.readingLevel},
            onSelectionChanged: widget.busy
                ? null
                : (s) {
                    _updateOptions((
                      tone: _options.tone,
                      readingLevel: s.first,
                      whatWeDiscussed: _options.whatWeDiscussed,
                      planForFirstSession: _options.planForFirstSession,
                      homePractice: _options.homePractice,
                      nextSteps: _options.nextSteps,
                      aiDisclosure: _options.aiDisclosure,
                    ));
                  },
          ),
          const SizedBox(height: 20),
          const Text('Included sections',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _sectionToggle(
            'What we talked about',
            _options.whatWeDiscussed,
            (v) => _updateOptions(_copy(whatWeDiscussed: v)),
          ),
          _sectionToggle(
            "What we'll work on",
            _options.planForFirstSession,
            (v) => _updateOptions(_copy(planForFirstSession: v)),
          ),
          _sectionToggle(
            'How you can help at home',
            _options.homePractice,
            (v) => _updateOptions(_copy(homePractice: v)),
          ),
          _sectionToggle(
            'What happens next',
            _options.nextSteps,
            (v) => _updateOptions(_copy(nextSteps: v)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Switch(
                value: _options.aiDisclosure,
                onChanged: widget.busy
                    ? null
                    : (v) => _updateOptions(_copy(aiDisclosure: v)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('AI-disclosure footer',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Show "AI-drafted · clinician-reviewed" at the bottom for transparency.',
                      style: TextStyle(
                          fontSize: 12, color: SonaColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          FilledButton(
            onPressed: widget.busy || widget.caseId == null
                ? null
                : () async {
                    await widget.onPublish(_options);
                  },
            child: Text(
              widget.busy
                  ? 'Publishing…'
                  : widget.alreadyPublished
                      ? 'Re-publish parent summary'
                      : 'Publish parent summary',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.busy ? null : widget.onDownloadPdf,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  ParentSummaryOptions _copy({
    bool? whatWeDiscussed,
    bool? planForFirstSession,
    bool? homePractice,
    bool? nextSteps,
    bool? aiDisclosure,
  }) {
    return (
      tone: _options.tone,
      readingLevel: _options.readingLevel,
      whatWeDiscussed: whatWeDiscussed ?? _options.whatWeDiscussed,
      planForFirstSession: planForFirstSession ?? _options.planForFirstSession,
      homePractice: homePractice ?? _options.homePractice,
      nextSteps: nextSteps ?? _options.nextSteps,
      aiDisclosure: aiDisclosure ?? _options.aiDisclosure,
    );
  }

  Widget _sectionToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: widget.busy ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged:
                  widget.busy ? null : (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    final projection = _projection;
    final title = projection?['title'] as String? ?? 'Parent summary';
    final sections =
        (projection?['sections'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    final disclosure = projection?['disclosure'] as String?;

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SonaColors.background,
          border: Border.all(color: SonaColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              if (_loadingPreview && _projection == null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              if (_previewError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SonaColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Preview error: $_previewError',
                      style: const TextStyle(
                          fontSize: 12, color: SonaColors.dangerText)),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SonaColors.successBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Live preview',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SonaColors.successText,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: SonaColors.primary)),
              const SizedBox(height: 16),
              ...sections.map((s) => _section(
                    s['heading'] as String,
                    (s['bullets'] as List?)?.cast<String>() ?? const [],
                  )),
              if (disclosure != null && disclosure.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SonaColors.heroTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI-drafted · clinician-reviewed',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SonaColors.primaryDark)),
                      const SizedBox(height: 4),
                      Text(disclosure,
                          style: const TextStyle(
                              fontSize: 11,
                              color: SonaColors.textSecondary,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ],
        ),
      ),
    );
  }

  Widget _section(String heading, List<String> bullets) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: SonaColors.primary)),
                  Expanded(
                      child: Text(b,
                          style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
