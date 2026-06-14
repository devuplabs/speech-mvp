import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_select_chip.dart';
import 'package:sona/design_system/widgets/trust_row.dart';

/// Tone presets the clinician can apply to the drafted summary. These shape the
/// framing/intro phrasing of the auto-drafted copy; they are applied
/// client-side (no live inference yet — see Option A note in DEV-50) so the
/// clinician genuinely controls what the family receives.
enum SummaryTone { warm, clinical }

/// Reading-level presets. `simple` favours short, plain sentences; `standard`
/// keeps the fuller phrasing.
enum SummaryReadingLevel { simple, standard }

extension on SummaryTone {
  String get label => switch (this) {
        SummaryTone.warm => 'Warm',
        SummaryTone.clinical => 'Clinical',
      };
}

extension on SummaryReadingLevel {
  String get label => switch (this) {
        SummaryReadingLevel.simple => 'Plain language',
        SummaryReadingLevel.standard => 'Standard',
      };
}

/// Stage 8 · Parent-summary editor.
///
/// The clinician shapes the tone-adjusted family summary before publishing:
/// they pick a tone + reading level (which re-draft the auto-generated copy),
/// can edit the body verbatim, and watch a live phone preview update. Publish
/// sends the clinician's final `htmlBody` to the existing
/// `POST /v1/cases/:id/parent-summary/publish` contract so the family sees
/// exactly what was approved. The "AI-assisted · reviewed by your clinician"
/// disclosure travels with the published output.
class ClinicianParentSummaryScreen extends StatefulWidget {
  const ClinicianParentSummaryScreen({
    super.key,
    required this.summaryHtml,
    required this.onBackClinician,
    this.onPublish,
    this.onOpenCarryover,
    this.caseDetail,
    this.busy = false,
    this.published = false,
  });

  /// Portal HTML for a summary that has already been published (used to show a
  /// "published" affordance + let the clinician confirm what the family sees).
  final String? summaryHtml;
  final VoidCallback onBackClinician;

  /// Publish the clinician's final edited body. The screen passes the composed
  /// HTML document (sections + disclosure) so the shell can POST it.
  final Future<void> Function(String htmlBody)? onPublish;

  /// Stage 9: after publishing, the clinician moves on to curating carryover
  /// resources + sharing the family portal link.
  final VoidCallback? onOpenCarryover;

  /// `{case: {...}, intake: {...}, drafts: [...]}` — the case the clinician
  /// clicked through to publish. The editor seeds its draft from THAT child's
  /// name + intake-derived content rather than a hardcoded persona.
  final Map<String, dynamic>? caseDetail;

  /// True while a publish request is in flight.
  final bool busy;

  /// True once this summary has been published in the current session.
  final bool published;

  @override
  State<ClinicianParentSummaryScreen> createState() =>
      _ClinicianParentSummaryScreenState();
}

class _ClinicianParentSummaryScreenState
    extends State<ClinicianParentSummaryScreen> {
  late final TextEditingController _bodyController;
  SummaryTone _tone = SummaryTone.warm;
  SummaryReadingLevel _readingLevel = SummaryReadingLevel.standard;

  /// True while the clinician has hand-edited the body. Once edited, changing a
  /// tone/reading-level preset would clobber their words, so we ask before
  /// re-drafting (cheap: a confirm dialog).
  bool _bodyEdited = false;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: _draftBody());
    _bodyController.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onBodyChanged);
    _bodyController.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    if (!_bodyEdited) setState(() => _bodyEdited = true);
    setState(() {}); // keep the live preview in sync with the body field
  }

  // ---- Case-derived content --------------------------------------------------

  String get _childName {
    final caseMap = widget.caseDetail?['case'] as Map<String, dynamic>?;
    final fromCase = (caseMap?['childDisplayName'] as String?)?.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    final answers =
        widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;
    final fromIntake = (answers?['childName'] as String?)?.trim();
    if (fromIntake != null && fromIntake.isNotEmpty) return fromIntake;
    return 'your child';
  }

  Map<String, dynamic>? get _answers =>
      widget.caseDetail?['intake']?['answers'] as Map<String, dynamic>?;

  String? get _mainConcern => (_answers?['mainConcern'] as String?)?.trim();

  List<String> get _difficulties {
    final raw = _answers?['difficulties'];
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    return const [];
  }

  /// Top items the clinician (or LLM) added to the session plan — surfaced to
  /// the parent verbatim. Falls back to a small fixed set when no plan draft is
  /// present yet.
  List<String> _planBullets(String key, List<String> fallback) {
    final drafts =
        (widget.caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    for (final d in drafts) {
      if (d['kind'] == 'session_plan') {
        final sections = (d['content'] as Map<String, dynamic>?)?['sections']
            as Map<String, dynamic>?;
        final list = (sections?[key] as List?)?.cast<String>();
        if (list != null && list.isNotEmpty) return list.take(4).toList();
      }
    }
    return fallback;
  }

  List<String> _whatWeDiscussedBullets() {
    final bullets = <String>[];
    final concern = _mainConcern;
    if (concern != null && concern.isNotEmpty) {
      bullets.add('Your main worry: $concern');
    }
    final diffs = _difficulties;
    if (diffs.isNotEmpty) {
      bullets.add('Areas we focused on: ${diffs.take(4).join(", ")}');
    }
    if (bullets.isEmpty) {
      bullets.add(
          'We reviewed the intake answers together and agreed where to start.');
    }
    return bullets;
  }

  // ---- Draft composition (tone + reading level) ------------------------------

  /// The opening line, shaped by the chosen tone + reading level. This is the
  /// part the presets actually rewrite; the section bullets come straight from
  /// the case so the clinician's plan is preserved.
  String _intro() {
    final name = _childName;
    return switch ((_tone, _readingLevel)) {
      (SummaryTone.warm, SummaryReadingLevel.simple) =>
        'Thank you for coming in. Here is a short summary of what we talked '
            'about for $name, and what happens next.',
      (SummaryTone.warm, SummaryReadingLevel.standard) =>
        "It was lovely to meet you and $name. Here's a summary of our "
            'consultation, the next steps we agreed, and a few things you can '
            'try together at home.',
      (SummaryTone.clinical, SummaryReadingLevel.simple) =>
        'Summary of consultation for $name. Key points and next steps are '
            'below.',
      (SummaryTone.clinical, SummaryReadingLevel.standard) =>
        'This summary records the outcome of $name’s consultation, the '
            'recommended next steps, and home-practice guidance.',
    };
  }

  /// Build the editable plain-text body from the case + presets. Re-runs when a
  /// preset changes (unless the clinician has hand-edited).
  String _draftBody() {
    final buf = StringBuffer()
      ..writeln(_intro())
      ..writeln()
      ..writeln('What we discussed');
    for (final b in _whatWeDiscussedBullets()) {
      buf.writeln('- $b');
    }
    buf
      ..writeln()
      ..writeln('What happens next');
    for (final b in _planBullets('goals', const [
      'A formal speech assessment is recommended',
      "We'll share home practice ideas after the assessment",
      'Your next appointment will be booked by the clinic',
    ])) {
      buf.writeln('- $b');
    }
    buf
      ..writeln()
      ..writeln('For you at home');
    for (final b in _planBullets('homePractice', const [
      "Repeat back what your child says — don't correct every sound",
      'Try one short play session per day',
    ])) {
      buf.writeln('- $b');
    }
    return buf.toString().trimRight();
  }

  /// Re-seed the body from the current presets. Confirms first if the clinician
  /// has hand-edited so we never silently discard their words.
  Future<void> _applyPreset(VoidCallback mutate) async {
    if (_bodyEdited) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Re-draft from preset?'),
              content: const Text(
                'Changing tone or reading level will rewrite the body and '
                'discard your edits. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Keep my edits'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Re-draft'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    setState(() {
      mutate();
      _bodyEdited = false;
      _bodyController.value = TextEditingValue(text: _draftBody());
    });
  }

  /// Disclosure shown on every published summary (AI-drafted, clinician-reviewed).
  static const _disclosure = 'AI-assisted · reviewed by your clinician';

  /// Compose the final HTML document sent on publish. Plain-text lines become
  /// paragraphs; lines under a section heading become list items; the
  /// disclosure is appended so it always travels with the published output.
  String composeHtml() {
    final lines = _bodyController.text.split('\n');
    final buf = StringBuffer('<!DOCTYPE html><html><body>');
    buf.write('<h1>${_escape(_childName)}’s consultation summary</h1>');
    var inList = false;
    void closeList() {
      if (inList) {
        buf.write('</ul>');
        inList = false;
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        closeList();
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('• ')) {
        if (!inList) {
          buf.write('<ul>');
          inList = true;
        }
        buf.write('<li>${_escape(line.substring(2).trim())}</li>');
      } else {
        closeList();
        // Short heading-like lines render as section headings.
        if (!line.endsWith('.') && line.length < 40) {
          buf.write('<h2>${_escape(line)}</h2>');
        } else {
          buf.write('<p>${_escape(line)}</p>');
        }
      }
    }
    closeList();
    buf.write('<p><strong>$_disclosure</strong></p>');
    buf.write('</body></html>');
    return buf.toString();
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<void> _publish() async {
    final onPublish = widget.onPublish;
    if (onPublish == null) return;
    await onPublish(composeHtml());
  }

  // ---- Preview parsing -------------------------------------------------------

  /// Parse the editable plain-text body into (heading, bullets) sections for the
  /// live phone preview. The first block (before any heading) is the intro.
  ({String intro, List<({String title, List<String> bullets})> sections})
      _parsePreview() {
    final lines = _bodyController.text.split('\n');
    final introBuf = StringBuffer();
    final sections = <({String title, List<String> bullets})>[];
    String? currentTitle;
    var currentBullets = <String>[];

    void flush() {
      final title = currentTitle;
      if (title != null) {
        sections.add((title: title, bullets: currentBullets));
      }
      currentBullets = <String>[];
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final isBullet = line.startsWith('- ') || line.startsWith('• ');
      if (isBullet) {
        currentBullets.add(line.substring(2).trim());
      } else if (!line.endsWith('.') && line.length < 40) {
        // Heading.
        flush();
        currentTitle = line;
      } else if (currentTitle == null) {
        if (introBuf.isNotEmpty) introBuf.write(' ');
        introBuf.write(line);
      } else {
        currentBullets.add(line);
      }
    }
    flush();
    return (intro: introBuf.toString(), sections: sections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final editor = _editorPanel();
          final phone = _phonePreview();
          if (constraints.maxWidth < 800) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [editor, const SizedBox(height: 24), phone],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(child: editor),
                    ),
                    const SizedBox(width: 24),
                    phone,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _editorPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: widget.busy ? null : widget.onBackClinician,
            child: const Text('← Back to triage'),
          ),
          const Text(
            'Parent summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shape the tone and wording, then publish. Families open this in the '
            'authenticated portal — not via email body.',
            style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('Tone',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in SummaryTone.values)
                SonaSelectChip(
                  pill: true,
                  label: t.label,
                  selected: _tone == t,
                  onChanged: (_) {
                    if (_tone == t) return;
                    _applyPreset(() => _tone = t);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Reading level',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in SummaryReadingLevel.values)
                SonaSelectChip(
                  pill: true,
                  label: r.label,
                  selected: _readingLevel == r,
                  onChanged: (_) {
                    if (_readingLevel == r) return;
                    _applyPreset(() => _readingLevel = r);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Summary body',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Edit freely. Lines starting with "- " become bullet points; short '
            'lines become section headings.',
            style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: 14,
            minLines: 10,
            decoration: InputDecoration(
              filled: true,
              fillColor: SonaColors.background,
              contentPadding: const EdgeInsets.all(12),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SonaColors.aiBadgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              _disclosure,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SonaColors.aiBadgeText,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.published) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SonaColors.successBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Published to the portal — the family has been notified.',
                style: TextStyle(
                    fontSize: 13,
                    color: SonaColors.successText,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SonaButton(
            label: widget.busy
                ? 'Publishing…'
                : widget.published
                    ? 'Re-publish summary'
                    : 'Publish to family',
            onPressed:
                (widget.busy || widget.onPublish == null) ? null : _publish,
          ),
          if (widget.published && widget.onOpenCarryover != null) ...[
            const SizedBox(height: 12),
            SonaButton(
              label: 'Next: carryover & home practice →',
              variant: SonaButtonVariant.secondary,
              onPressed: widget.busy ? null : widget.onOpenCarryover,
            ),
          ],
        ],
      ),
    );
  }

  Widget _phonePreview() {
    final parsed = _parsePreview();
    return SizedBox(
      width: 375,
      child: ParentMobileScaffold(
        showStatusBar: false,
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SonaColors.successBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Summary ready',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SonaColors.successText),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "$_childName's consultation summary",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'From Monal Gajjar SLT · Published today',
              style: TextStyle(fontSize: 13, color: SonaColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (parsed.intro.isNotEmpty) ...[
              Text(
                parsed.intro,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
            for (final s in parsed.sections) ...[
              _section(s.title, s.bullets),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SonaColors.aiBadgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                _disclosure,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SonaColors.aiBadgeText),
              ),
            ),
            if (widget.summaryHtml != null &&
                widget.summaryHtml!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SonaColors.surface,
                  border: Border.all(color: SonaColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Portal HTML loaded (${widget.summaryHtml!.length} chars)',
                  style: const TextStyle(
                      fontSize: 11, color: SonaColors.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const TrustRow(
              title: 'Secure portal',
              subtitle: 'Sign in with your clinic link — not in email',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(fontSize: 14, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
