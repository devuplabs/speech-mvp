import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/utils/intake_validation.dart';

/// Stage 3 · Intake review — the one-screen client overview (clinician web).
///
/// Renders everything the clinician needs to know about a client at a glance
/// from the `{case, intake, drafts}` shape returned by `GET /v1/cases/:id`:
/// child profile (name + age band from DOB), presenting concerns, history
/// highlights, red flags, consent status + version, referral source, and the
/// full intake answers grouped by form section.
///
/// Gracefully handles every intake state:
/// - Pending (link sent, nothing back yet): shows the link status with
///   resend / revoke actions so the clinician can chase the parent.
/// - In progress (draft answers, not submitted): shows what has arrived so
///   far, clearly badged as a draft.
/// - Submitted / locked: the full grouped overview with consent + red flags.
class ClinicianIntakeReviewScreen extends StatelessWidget {
  const ClinicianIntakeReviewScreen({
    super.key,
    required this.caseDetail,
    required this.onBack,
    this.linkStatus,
    this.onOpenPrep,
    this.onRefresh,
    this.onResendLink,
    this.onRevokeLink,
  });

  /// Shape: `{case: {...}, intake: {...} | null, drafts: [{kind, content}]}`.
  final Map<String, dynamic>? caseDetail;
  final VoidCallback onBack;

  /// Magic-link status from the intake-submissions list (`sent`, `in_progress`,
  /// `submitted`, `expired`) when known — null when not yet loaded.
  final String? linkStatus;
  final VoidCallback? onOpenPrep;
  final Future<void> Function()? onRefresh;

  /// Re-issue the parent magic link; resolves to the new URL (or null on error).
  final Future<String?> Function()? onResendLink;
  final Future<void> Function()? onRevokeLink;

  Map<String, dynamic>? get _case =>
      caseDetail?['case'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _intake =>
      caseDetail?['intake'] as Map<String, dynamic>?;
  Map<String, dynamic> get _answers =>
      (_intake?['answers'] as Map<String, dynamic>?) ?? const {};

  bool get _locked => _intake?['locked'] as bool? ?? false;
  bool get _submitted => _intake?['submittedAt'] != null;
  bool get _hasDraftAnswers => !_submitted && _answers.isNotEmpty;

  String get _intakeStatusLabel {
    if (_submitted) return 'Submitted';
    if (_hasDraftAnswers) return 'In progress';
    return 'Pending';
  }

  String _answer(String key) {
    final v = _answers[key];
    if (v is String) return v.trim();
    if (v is List) return v.whereType<String>().join(', ');
    if (v == null) return '';
    return '$v';
  }

  /// 'yes'/'no' answers read better with their detail folded in.
  String _yesNoWithDetails(String key, String detailsKey) {
    final v = _answer(key);
    final details = _answer(detailsKey);
    final base = switch (v) {
      'yes' => 'Yes',
      'no' => 'No',
      _ => v,
    };
    if (base.isEmpty) return '';
    return details.isEmpty ? base : '$base — $details';
  }

  String get _childName {
    final fromCase = (_case?['childDisplayName'] as String?)?.trim() ?? '';
    if (fromCase.isNotEmpty) return fromCase;
    final fromAnswers = _answer('childName');
    return fromAnswers.isNotEmpty ? fromAnswers : 'Client';
  }

  /// Coarse age band derived from the DOB answer, e.g. "Pre-school (3–5)".
  String? get _ageBand {
    final dob = IntakeValidation.parseDdMmYyyy(_answer('dateOfBirth'));
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    if (years < 0) return null;
    if (years < 3) return 'Early years (0–2)';
    if (years < 6) return 'Pre-school (3–5)';
    if (years < 12) return 'Primary (6–11)';
    return 'Secondary (12+)';
  }

  String? get _exactAge {
    final age = _answer('ageAtReferral');
    if (age.isNotEmpty) return age;
    return IntakeValidation.computeAgeAtReferral(_answer('dateOfBirth'));
  }

  String get _referralSource {
    final fromCase = (_case?['referralSource'] as String?)?.trim() ?? '';
    if (fromCase.isNotEmpty) return fromCase.replaceAll('_', ' ');
    final referredBy = _answer('referredBy');
    return referredBy.isNotEmpty ? referredBy : 'Not recorded';
  }

  List<String> get _difficulties {
    final raw = _answers['difficulties'];
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    return const [];
  }

  List<String> get _redFlags {
    final drafts =
        (caseDetail?['drafts'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    for (final d in drafts) {
      if (d['kind'] == 'prep_brief') {
        final content = d['content'] as Map<String, dynamic>?;
        return (content?['redFlags'] as List?)?.whereType<String>().toList() ??
            const [];
      }
    }
    return const [];
  }

  List<String> get _historyHighlights {
    final highlights = <String>[];
    void add(String prefix, String value) {
      if (value.isNotEmpty) highlights.add('$prefix: $value');
    }

    if (_answer('familyHistory') == 'yes') {
      add('Family history', _answer('familyHistoryDetails'));
    }
    if (_answer('assessedByOthers') == 'yes') {
      add('Other professionals', _answer('assessedByOthersDetails'));
    }
    if (_answer('receivingTherapy') == 'yes') {
      add('Current therapy', _answer('therapyDetails'));
    }
    if (_answer('hospitalised') == 'yes') {
      add('Hospitalised', _answer('hospitalisedDetails'));
    }
    if (_answer('entInvolvement') == 'yes') {
      add('ENT involvement', _answer('entInvolvementDetails'));
    }
    add('Early illnesses', _answer('earlyIllnesses'));
    add('Diagnosis', _answer('diagnosis'));
    return highlights
        .where((h) => !h.toLowerCase().endsWith(': none'))
        .toList(growable: false);
  }

  /// (Consent recorded?, human-readable line). Consent is captured at submit;
  /// version comes from the intake row, individual flags from the answers.
  (bool, String) get _consent {
    final version = (_intake?['consentVersion'] as String?)?.trim() ?? '';
    final flags = [
      _answers['consentGuardian'] == true,
      _answers['consentPrivacy'] == true,
      _answers['consentAccurate'] == true,
    ];
    final given = flags.where((f) => f).length;
    if (!_submitted && given == 0) {
      return (false, 'Consent not yet recorded — captured when the parent submits.');
    }
    final versionLabel = version.isEmpty ? 'unversioned' : 'version $version';
    return (true, 'Consent recorded ($given of 3 confirmations) · $versionLabel');
  }

  String get _linkStatusLabel => switch (linkStatus) {
        'in_progress' => 'Link opened — form in progress',
        'expired' => 'Link expired',
        'submitted' => 'Submitted',
        'sent' => 'Link sent — awaiting the parent',
        _ => 'Link status unavailable — refresh from Intake forms',
      };

  // ---- Grouped answers ------------------------------------------------------

  /// Section title → ordered (label, answer key) rows. Keys match
  /// `IntakeFormData.toJson` / the persona fixtures; missing or empty answers
  /// are skipped at render time.
  static const List<(String, List<(String, String)>)> _sections = [
    (
      'About the child',
      [
        ('Name', 'childName'),
        ('Date of birth', 'dateOfBirth'),
        ('Age at referral', 'ageAtReferral'),
        ('Home address', 'childAddress'),
        ('School / nursery', 'schoolNameAddress'),
        ('Attendance', 'nurseryDays'),
        ('EHCP / SEN plan', 'senPlan'),
      ]
    ),
    (
      'Family & background',
      [
        ('Mother', 'motherName'),
        ('Mother mobile', 'motherMobile'),
        ('Mother email', 'motherEmail'),
        ('Second parent', 'fatherName'),
        ('Second parent mobile', 'fatherMobile'),
        ('Second parent email', 'fatherEmail'),
        ('GP practice', 'gpPractice'),
        ('GP phone', 'gpPhone'),
        ('Languages at home', 'languagesExposed'),
        ('Parent languages', 'parentLanguages'),
        ('Child languages', 'childLanguages'),
        ('Form completed by', 'completedBy'),
      ]
    ),
    (
      'Concerns',
      [
        ('Main concern', 'mainConcern'),
        ('Difficulties', 'difficulties'),
        ('Referred by', 'referredBy'),
        ('How they heard about us', 'heardAbout'),
        ('Awareness of communication', 'communicationAwareness'),
      ]
    ),
    (
      'Development',
      [
        ('Responds to name', 'respondsToName'),
        ('First words', 'ageFirstWords'),
        ('Two-word phrases', 'ageTwoWordPhrases'),
        ('Attention & listening', 'attentionListening'),
        ('Sentence examples', 'sentenceExamples'),
        ('Understanding', 'showsUnderstanding'),
        ('Temperament', 'temperament'),
        ('Social skills', 'socialSkills'),
        ('Peer interaction', 'peerInteraction'),
        ('Favourite play', 'favouritePlay'),
      ]
    ),
    (
      'Health',
      [
        ('Pregnancy', 'pregnancyHealth'),
        ('Prematurity', 'prematureDetails'),
        ('Birth weight', 'birthWeight'),
        ('Birth complications', 'birthComplications'),
        ('After birth', 'afterBirthComplications'),
        ('Early illnesses', 'earlyIllnesses'),
        ('General health', 'generalHealth'),
        ('Diagnosis', 'diagnosis'),
        ('Medications', 'medications'),
      ]
    ),
    (
      'Anything else',
      [
        ('Notes from the parent', 'anythingElse'),
        ('Photo consent', 'photoConsent'),
      ]
    ),
  ];

  /// Yes/no answers whose free-text detail is folded into the same row.
  static const Map<String, String> _detailPairs = {
    'familyHistory': 'familyHistoryDetails',
    'assessedByOthers': 'assessedByOthersDetails',
    'receivingTherapy': 'therapyDetails',
    'hospitalised': 'hospitalisedDetails',
    'hearingTested': 'hearingTestedDetails',
    'earInfections': 'earInfectionsDetails',
    'entInvolvement': 'entInvolvementDetails',
    'visionTested': 'visionTestedDetails',
  };

  /// Extra yes/no rows appended to specific sections.
  static const Map<String, List<(String, String)>> _yesNoRowsBySection = {
    'Family & background': [
      ('Family history of SLCN', 'familyHistory'),
    ],
    'Concerns': [
      ('Seen by other professionals', 'assessedByOthers'),
      ('Currently receiving therapy', 'receivingTherapy'),
    ],
    'Health': [
      ('Hospitalised', 'hospitalised'),
      ('Hearing tested', 'hearingTested'),
      ('Ear infections', 'earInfections'),
      ('ENT involvement', 'entInvolvement'),
      ('Vision tested', 'visionTested'),
    ],
  };

  List<(String, String)> _rowsForSection(
    String title,
    List<(String, String)> fields,
  ) {
    final rows = <(String, String)>[];
    for (final (label, key) in fields) {
      var value = _answer(key);
      if (key == 'respondsToName' || key == 'photoConsent') {
        value = switch (value) {
          'yes' => 'Yes',
          'no' => 'No',
          _ => value,
        };
      }
      if (value.isNotEmpty) rows.add((label, value));
    }
    for (final (label, key) in _yesNoRowsBySection[title] ?? const <(String, String)>[]) {
      final value = _yesNoWithDetails(key, _detailPairs[key] ?? key);
      if (value.isNotEmpty) rows.add((label, value));
    }
    return rows;
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: caseDetail == null
              ? const Center(
                  child: Text(
                    'No case loaded — open a client from Today or Intake forms.',
                    style: TextStyle(color: SonaColors.textSecondary),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 900;
                      final main = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _childProfileCard(),
                          const SizedBox(height: 16),
                          _concernsCard(),
                          if (_submitted || _hasDraftAnswers) ...[
                            const SizedBox(height: 16),
                            _answersCard(),
                          ],
                        ],
                      );
                      final aside = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statusCard(context),
                          const SizedBox(height: 16),
                          _redFlagsPanel(),
                          const SizedBox(height: 16),
                          _historyPanel(),
                          if (onOpenPrep != null) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: onOpenPrep,
                              child: const Text('Open consult prep →'),
                            ),
                          ],
                        ],
                      );
                      if (stack) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [main, const SizedBox(height: 24), aside],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: main),
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

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: const BoxDecoration(
        color: SonaColors.surface,
        border: Border(bottom: BorderSide(color: SonaColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Intake review · $_childName',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'One-screen client overview before the first consultation',
                  style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
                ),
              ],
            ),
          ),
          _statusChip(),
          if (_locked) ...[
            const SizedBox(width: 8),
            _lockedBadge(),
          ],
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: () => onRefresh!(), child: const Text('Refresh')),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final label = _intakeStatusLabel;
    final (bg, fg) = switch (label) {
      'Submitted' => (SonaColors.successBg, SonaColors.successText),
      'In progress' => (SonaColors.warningBg, SonaColors.warningText),
      _ => (SonaColors.heroTint, SonaColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _lockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SonaColors.dangerBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: SonaColors.dangerText),
          SizedBox(width: 4),
          Text(
            'Locked',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SonaColors.dangerText,
            ),
          ),
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

  Widget _childProfileCard() {
    final band = _ageBand;
    final exact = _exactAge;
    final dob = _answer('dateOfBirth');
    final parent = _answer('motherName').isNotEmpty
        ? _answer('motherName')
        : _answer('completedBy');
    final email = (_case?['parentEmail'] as String?)?.trim() ?? '';

    return _card(children: [
      const Text('Child profile',
          style: TextStyle(fontSize: 12, color: SonaColors.textMuted)),
      const SizedBox(height: 6),
      Text(
        band == null ? _childName : '$_childName · $band',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      if (exact != null && exact.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          dob.isEmpty ? 'Age $exact' : 'Age $exact · born $dob',
          style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary),
        ),
      ],
      if (parent.isNotEmpty || email.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          [
            if (parent.isNotEmpty) 'Parent: $parent',
            if (email.isNotEmpty) email,
          ].join(' · '),
          style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        'Referral source: $_referralSource',
        style: const TextStyle(fontSize: 13, color: SonaColors.textSecondary),
      ),
    ]);
  }

  Widget _concernsCard() {
    final concern = _answer('mainConcern');
    final difficulties = _difficulties;
    return _card(children: [
      const Text('Presenting concerns',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      if (concern.isEmpty && difficulties.isEmpty)
        const Text(
          'No concerns recorded yet — they arrive with the parent\'s intake.',
          style: TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
        )
      else ...[
        if (concern.isNotEmpty)
          Text(concern, style: const TextStyle(fontSize: 14, height: 1.4)),
        if (difficulties.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: difficulties
                .map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SonaColors.heroTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 12, color: SonaColors.primaryDark)),
                    ))
                .toList(),
          ),
        ],
      ],
    ]);
  }

  Widget _answersCard() {
    return _card(children: [
      Row(
        children: [
          const Expanded(
            child: Text('Intake answers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (_hasDraftAnswers)
            const Text(
              'Draft — not yet submitted',
              style: TextStyle(fontSize: 12, color: SonaColors.warningText),
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final (title, fields) in _sections) ...[
        Builder(builder: (context) {
          final rows = _rowsForSection(title, fields);
          if (rows.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SonaColors.primaryDark)),
              const SizedBox(height: 6),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Text(r.$1,
                              style: const TextStyle(
                                  fontSize: 12, color: SonaColors.textMuted)),
                        ),
                        Expanded(
                          child: Text(r.$2,
                              style: const TextStyle(fontSize: 13, height: 1.35)),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        }),
      ],
    ]);
  }

  Widget _statusCard(BuildContext context) {
    final (consentGiven, consentLine) = _consent;
    final submittedAt = _intake?['submittedAt'] as String?;
    return _card(children: [
      const Text('Intake status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Row(children: [
        _statusChip(),
        if (_locked) ...[const SizedBox(width: 8), _lockedBadge()],
      ]),
      if (submittedAt != null) ...[
        const SizedBox(height: 8),
        Text(
          'Submitted ${_friendlyDate(submittedAt)}',
          style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
        ),
      ],
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            consentGiven ? Icons.verified_user_outlined : Icons.shield_outlined,
            size: 16,
            color: consentGiven ? SonaColors.successText : SonaColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              consentLine,
              style: const TextStyle(
                  fontSize: 12, color: SonaColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
      if (!_submitted) ...[
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text(
          _linkStatusLabel,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
        ),
        const SizedBox(height: 4),
        const Text(
          'The parent has not submitted this intake yet. You can resend the magic link or revoke it if it was shared in error.',
          style: TextStyle(
              fontSize: 12, color: SonaColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onResendLink != null)
              OutlinedButton(
                onPressed: () => onResendLink!(),
                child: const Text('Resend link'),
              ),
            if (onRevokeLink != null)
              OutlinedButton(
                onPressed: () => _confirmRevoke(context),
                child: const Text('Revoke link'),
              ),
          ],
        ),
      ],
    ]);
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke link?'),
        content: const Text(
            'The parent will not be able to use the current magic link.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revoke')),
        ],
      ),
    );
    if (ok == true) await onRevokeLink!();
  }

  Widget _redFlagsPanel() {
    final flags = _redFlags;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.dangerBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Red flags',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: SonaColors.dangerText)),
          const SizedBox(height: 8),
          if (flags.isEmpty)
            const Text(
              '· No red flags from intake — confirm in conversation',
              style: TextStyle(
                  fontSize: 13, color: SonaColors.dangerText, height: 1.4),
            )
          else
            ...flags.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $f',
                      style: const TextStyle(
                          fontSize: 13,
                          color: SonaColors.dangerText,
                          height: 1.4)),
                )),
        ],
      ),
    );
  }

  Widget _historyPanel() {
    final highlights = _historyHighlights;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.heroTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('History highlights',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: SonaColors.primaryDark)),
          const SizedBox(height: 8),
          if (highlights.isEmpty)
            const Text(
              '· No notable history flagged in the intake',
              style: TextStyle(
                  fontSize: 13, color: SonaColors.primaryDark, height: 1.4),
            )
          else
            ...highlights.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $h',
                      style: const TextStyle(
                          fontSize: 13,
                          color: SonaColors.primaryDark,
                          height: 1.4)),
                )),
        ],
      ),
    );
  }

  String _friendlyDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'recently';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
