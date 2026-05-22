import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_typography.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_page_title.dart';
import 'package:sona/design_system/widgets/sona_date_field.dart';
import 'package:sona/design_system/widgets/sona_step_progress.dart';
import 'package:sona/features/parent/intake/difficulty_checklist.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/design_system/widgets/sona_yes_no_field.dart';
import 'package:sona/models/intake_form_data.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/utils/intake_validation.dart';

class ParentIntakeStepScreen extends StatefulWidget {
  const ParentIntakeStepScreen({
    super.key,
    required this.state,
    required this.onBack,
    required this.onContinue,
    required this.onSaveExit,
    this.saving = false,
  });

  final SonaAppState state;
  final VoidCallback onBack;
  final Future<void> Function() onContinue;
  final Future<void> Function() onSaveExit;
  final bool saving;

  @override
  State<ParentIntakeStepScreen> createState() => _ParentIntakeStepScreenState();
}

class _ParentIntakeStepScreenState extends State<ParentIntakeStepScreen> {
  IntakeFormData get _d => widget.state.intake;
  final Map<String, GlobalKey> _fieldKeys = {};
  String? _lastHandledValidationKey;

  GlobalKey _keyFor(String fieldKey) =>
      _fieldKeys.putIfAbsent(fieldKey, GlobalKey.new);

  @override
  void didUpdateWidget(ParentIntakeStepScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeScrollToPendingValidation();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeScrollToPendingValidation(),
    );
  }

  void _maybeScrollToPendingValidation() {
    final pending = widget.state.pendingValidationFieldKey;
    if (pending == null || pending == _lastHandledValidationKey) return;
    final key = _fieldKeys[pending];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    _lastHandledValidationKey = pending;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  String? _errorTextFor(String fieldKey) {
    if (widget.state.pendingValidationFieldKey != fieldKey) return null;
    return widget.state.pendingValidationMessage;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.state.formStep;
    final meta = _stepMeta(step);
    final pendingMessage = widget.state.pendingValidationMessage;
    return ParentMobileScaffold(
      header: _header(step),
      body: _scrollBody([
        _badge(meta.badge),
        const SizedBox(height: 12),
        SonaPageTitle(meta.title, style: SonaTypography.screenTitle),
        if (meta.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(meta.subtitle!, style: SonaTypography.body),
        ],
        if (pendingMessage != null) ...[
          const SizedBox(height: 16),
          _validationBanner(pendingMessage),
        ],
        const SizedBox(height: 16),
        ..._fieldsForStep(step),
      ]),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SonaButton(
                    label: 'Back',
                    variant: SonaButtonVariant.secondary,
                    expanded: true,
                    onPressed: widget.saving ? null : widget.onBack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SonaButton(
                    label: widget.state.returnToReviewAfterEdit ? 'Save changes' : 'Continue →',
                    expanded: true,
                    onPressed: widget.saving ? null : () => widget.onContinue(),
                  ),
                ),
              ],
            ),
            if (!widget.state.returnToReviewAfterEdit) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: widget.saving ? null : () => widget.onSaveExit(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  foregroundColor: SonaColors.textMuted,
                ),
                child: const Text(
                  'Save and finish later',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _milestones = [
    'About your family',       // step 1
    'What you\'re noticing',   // step 2
    'Background',              // step 3
    'Health & development',    // step 4
    'Health & senses',         // step 5
    'Speech & language',       // step 6
    'Personality & play',      // step 7
    'School & wrap-up',        // step 8
  ];

  // Rough estimated seconds per step (used for time-remaining indicator).
  static const _stepEstimates = [300, 180, 150, 120, 180, 150, 150, 90];

  String _timeRemaining(int fromStep) {
    final totalSeconds = _stepEstimates
        .sublist(fromStep - 1)
        .fold<int>(0, (a, b) => a + b);
    final minutes = (totalSeconds / 60).ceil();
    return '~$minutes min left';
  }

  Widget _header(int step) {
    final milestone = step >= 1 && step <= 8 ? _milestones[step - 1] : 'Intake';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.saving ? null : widget.onBack,
                icon: const Icon(Icons.chevron_left, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: SonaColors.surface,
                  side: const BorderSide(color: SonaColors.border),
                  minimumSize: const Size(44, 44),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      milestone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Step $step of 8',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
                        ),
                        if (step == 1) ...[
                          Text(
                            '  ·  Page ${widget.state.formSubstep + 1} of 2',
                            style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
                          ),
                        ] else if (step < 8) ...[
                          Text(
                            '  ·  ${_timeRemaining(step)}',
                            style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: widget.saving ? null : () => widget.onSaveExit(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  widget.saving ? 'Saving…' : 'Save & exit',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SonaStepProgress(currentStep: step, totalSteps: 8),
          const SizedBox(height: 6),
          if (widget.state.lastLocalSavedAt != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 13, color: SonaColors.successText),
                const SizedBox(width: 4),
                Text(
                  'Saved ${_formatSaved(widget.state.lastLocalSavedAt!)}',
                  style: const TextStyle(fontSize: 12, color: SonaColors.successText),
                ),
              ],
            )
          else if (widget.state.draftDirty)
            const Text(
              'Saving…',
              style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  String _formatSaved(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _validationBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SonaColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SonaColors.dangerText),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: SonaColors.dangerText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SonaColors.dangerText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SonaColors.heroTint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SonaColors.primaryDark,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _scrollBody(List<Widget> children) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          children: children,
        ),
      ),
    );
  }

  /// Text edits — controllers hold display state; avoid rebuilding the whole step.
  void _touch(VoidCallback fn) {
    fn();
    widget.state.markDraftDirty();
  }

  /// Yes/no, dates, or other UI that must repaint the step.
  void _repaint(VoidCallback fn) {
    setState(fn);
    widget.state.markDraftDirty();
  }

  Widget _txt(
    String fieldKey, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
    return SonaTextField(
      key: _keyFor(fieldKey),
      label: label,
      value: value,
      onChanged: (v) {
        if (widget.state.pendingValidationFieldKey == fieldKey) {
          setState(() {
            widget.state.pendingValidationFieldKey = null;
            widget.state.pendingValidationMessage = null;
          });
        }
        onChanged(v);
      },
      required: required,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      errorText: _errorTextFor(fieldKey),
    );
  }

  List<Widget> _fieldsForStep(int step) {
    switch (step) {
      case 1:
        if (widget.state.formSubstep == 0) {
          return [
            _txt('email',
                label: 'Email',
                value: _d.email,
                onChanged: (v) => _touch(() => _d.email = v),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                required: true),
            _consentBlurb(),
            _txt('childName', label: "Child's name", value: _d.childName, onChanged: (v) => _touch(() => _d.childName = v), required: true),
            SonaDateField(
              key: _keyFor('dateOfBirth'),
              label: 'Date of birth',
              value: _d.dateOfBirth,
              onChanged: (v) {
                if (widget.state.pendingValidationFieldKey == 'dateOfBirth') {
                  widget.state.pendingValidationFieldKey = null;
                  widget.state.pendingValidationMessage = null;
                }
                _repaint(() => _d.dateOfBirth = v);
              },
              required: true,
              errorText: _errorTextFor('dateOfBirth'),
              lastDate: DateTime.now(),
            ),
            _ageAtReferralDisplay(),
            _txt('childAddress', label: "Child's address", value: _d.childAddress, onChanged: (v) => _touch(() => _d.childAddress = v), required: true),
            _txt('motherName', label: "Mother's name", value: _d.motherName, onChanged: (v) => _touch(() => _d.motherName = v), required: true),
            _txt('motherAddress', label: "Mother's address if different", value: _d.motherAddress, onChanged: (v) => _touch(() => _d.motherAddress = v)),
            _txt('motherMobile', label: "Mother's mobile", value: _d.motherMobile, onChanged: (v) => _touch(() => _d.motherMobile = v), keyboardType: TextInputType.phone, required: true),
            _txt('motherEmail', label: "Mother's email", value: _d.motherEmail, onChanged: (v) => _touch(() => _d.motherEmail = v), keyboardType: TextInputType.emailAddress, required: true),
          ];
        }
        return [
          _fatherDetailsToggle(),
          if (_d.fatherDetailsApplicable) ...[
            _txt('fatherName', label: "Father's / second parent's name", value: _d.fatherName, onChanged: (v) => _touch(() => _d.fatherName = v)),
            _txt('fatherAddress', label: "Father's address if different", value: _d.fatherAddress, onChanged: (v) => _touch(() => _d.fatherAddress = v)),
            _txt('fatherMobile', label: "Father's / second parent's mobile", value: _d.fatherMobile, onChanged: (v) => _touch(() => _d.fatherMobile = v), keyboardType: TextInputType.phone, required: true),
            _txt('fatherEmail', label: "Father's / second parent's email", value: _d.fatherEmail, onChanged: (v) => _touch(() => _d.fatherEmail = v), keyboardType: TextInputType.emailAddress, required: true),
          ],
          _txt('gpPractice', label: 'GP practice', value: _d.gpPractice, onChanged: (v) => _touch(() => _d.gpPractice = v), required: true),
          _txt('gpAddress', label: 'GP address', value: _d.gpAddress, onChanged: (v) => _touch(() => _d.gpAddress = v), maxLines: 2, required: true),
          _txt('gpPhone', label: 'GP phone', value: _d.gpPhone, onChanged: (v) => _touch(() => _d.gpPhone = v), keyboardType: TextInputType.phone, required: true),
          _txt('referredBy', label: 'Who referred your child?', value: _d.referredBy, onChanged: (v) => _touch(() => _d.referredBy = v), required: true),
          _txt('heardAbout', label: 'How did you hear about Speech Sanctuary?', value: _d.heardAbout, onChanged: (v) => _touch(() => _d.heardAbout = v), required: true),
        ];
      case 2:
        return [
          _txt('mainConcern', label: 'Main concern', value: _d.mainConcern, onChanged: (v) => _touch(() => _d.mainConcern = v), maxLines: 4, required: true),
          const SizedBox(height: 8),
          Container(
            key: _keyFor('difficulties'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Is your child having difficulty with (tick all that apply)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _errorTextFor('difficulties') != null
                        ? SonaColors.dangerText
                        : null,
                  ),
                ),
                if (_errorTextFor('difficulties') != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorTextFor('difficulties')!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SonaColors.dangerText,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DifficultyChecklist(
                  selected: _d.difficulties,
                  onChanged: (next) {
                    if (widget.state.pendingValidationFieldKey == 'difficulties') {
                      setState(() {
                        widget.state.pendingValidationFieldKey = null;
                        widget.state.pendingValidationMessage = null;
                      });
                    }
                    _d.difficulties
                      ..clear()
                      ..addAll(next);
                    widget.state.markDraftDirty();
                  },
                ),
              ],
            ),
          ),
        ];
      case 3:
        return [
          KeyedSubtree(
            key: _keyFor('assessedByOthers'),
            child: SonaYesNoField(
              label: 'Assessed by other professionals?',
              value: _d.assessedByOthers,
              onChanged: (v) => _repaint(() => _d.assessedByOthers = v),
              detailLabel: 'If yes — details',
              detailValue: _d.assessedByOthersDetails,
              onDetailChanged: (v) => _touch(() => _d.assessedByOthersDetails = v),
            ),
          ),
          KeyedSubtree(
            key: _keyFor('receivingTherapy'),
            child: SonaYesNoField(
              label: 'Receiving therapy now?',
              value: _d.receivingTherapy,
              onChanged: (v) => _repaint(() => _d.receivingTherapy = v),
              detailLabel: 'If yes — therapy details',
              detailValue: _d.therapyDetails,
              onDetailChanged: (v) => _touch(() => _d.therapyDetails = v),
            ),
          ),
          _txt('languagesExposed', label: 'Languages child exposed to', value: _d.languagesExposed, onChanged: (v) => _touch(() => _d.languagesExposed = v), maxLines: 2, required: true),
          _txt('parentLanguages', label: 'Languages spoken by parents', value: _d.parentLanguages, onChanged: (v) => _touch(() => _d.parentLanguages = v), maxLines: 2, required: true),
          _txt('childLanguages', label: 'Languages spoken by child', value: _d.childLanguages, onChanged: (v) => _touch(() => _d.childLanguages = v), maxLines: 2, required: true),
          KeyedSubtree(
            key: _keyFor('familyHistory'),
            child: SonaYesNoField(
              label: 'Family history of SLT/learning/attention difficulties?',
              value: _d.familyHistory,
              onChanged: (v) => _repaint(() => _d.familyHistory = v),
              detailLabel: 'If yes — explain',
              detailValue: _d.familyHistoryDetails,
              onDetailChanged: (v) => _touch(() => _d.familyHistoryDetails = v),
            ),
          ),
        ];
      case 4:
        return [
          _txt('pregnancyHealth', label: "Mother's health during pregnancy", value: _d.pregnancyHealth, onChanged: (v) => _touch(() => _d.pregnancyHealth = v), maxLines: 3, required: true),
          _txt('prematureDetails', label: 'Premature? If yes, how many weeks', value: _d.prematureDetails, onChanged: (v) => _touch(() => _d.prematureDetails = v), required: true),
          _txt('birthWeight', label: "Baby's weight at birth", value: _d.birthWeight, onChanged: (v) => _touch(() => _d.birthWeight = v), required: true),
          _txt('birthComplications', label: 'Complications during birth', value: _d.birthComplications, onChanged: (v) => _touch(() => _d.birthComplications = v), maxLines: 3, required: true),
          _txt('afterBirthComplications', label: 'Complications after birth', value: _d.afterBirthComplications, onChanged: (v) => _touch(() => _d.afterBirthComplications = v), maxLines: 3, required: true),
        ];
      case 5:
        return [
          _txt('earlyIllnesses', label: 'Early childhood illnesses', value: _d.earlyIllnesses, onChanged: (v) => _touch(() => _d.earlyIllnesses = v), maxLines: 2, required: true),
          _txt('generalHealth', label: 'General health', value: _d.generalHealth, onChanged: (v) => _touch(() => _d.generalHealth = v), maxLines: 2, required: true),
          _txt('diagnosis', label: 'Known diagnosis / syndrome', value: _d.diagnosis, onChanged: (v) => _touch(() => _d.diagnosis = v), maxLines: 2, required: true),
          _txt('medications', label: 'Regular medications', value: _d.medications, onChanged: (v) => _touch(() => _d.medications = v), maxLines: 2, required: true),
          _txt('hospitalised', label: 'Hospitalised? (details)', value: _d.hospitalised, onChanged: (v) => _touch(() => _d.hospitalised = v), maxLines: 2, required: true),
          _txt('hearingTested', label: 'Hearing tested? (when & outcome)', value: _d.hearingTested, onChanged: (v) => _touch(() => _d.hearingTested = v), maxLines: 2, required: true),
          _txt('earInfections', label: 'History of ear infections', value: _d.earInfections, onChanged: (v) => _touch(() => _d.earInfections = v), maxLines: 2, required: true),
          _txt('entInvolvement', label: 'Ear surgery / ENT involvement', value: _d.entInvolvement, onChanged: (v) => _touch(() => _d.entInvolvement = v), maxLines: 2, required: true),
          _txt('visionTested', label: 'Eyes tested? (when & outcome)', value: _d.visionTested, onChanged: (v) => _touch(() => _d.visionTested = v), maxLines: 2, required: true),
        ];
      case 6:
        return [
          KeyedSubtree(
            key: _keyFor('respondsToName'),
            child: SonaYesNoField(label: 'Responds to own name?', value: _d.respondsToName, onChanged: (v) => _repaint(() => _d.respondsToName = v)),
          ),
          _txt('ageFirstWords', label: 'Age of first words', value: _d.ageFirstWords, onChanged: (v) => _touch(() => _d.ageFirstWords = v), required: true),
          _txt('ageTwoWordPhrases', label: 'Age of two-word phrases', value: _d.ageTwoWordPhrases, onChanged: (v) => _touch(() => _d.ageTwoWordPhrases = v), required: true),
          _txt('attentionListening', label: 'Attention & listening skills', value: _d.attentionListening, onChanged: (v) => _touch(() => _d.attentionListening = v), maxLines: 3, required: true),
          _txt('sentenceExamples', label: 'Sentence examples', value: _d.sentenceExamples, onChanged: (v) => _touch(() => _d.sentenceExamples = v), maxLines: 3, required: true),
          _txt('showsUnderstanding', label: 'Shows understanding by', value: _d.showsUnderstanding, onChanged: (v) => _touch(() => _d.showsUnderstanding = v), maxLines: 3, required: true),
        ];
      case 7:
        return [
          _txt('temperament', label: 'Describe your child (temperament)', value: _d.temperament, onChanged: (v) => _touch(() => _d.temperament = v), maxLines: 3, required: true),
          _txt('socialSkills', label: 'Social skills', value: _d.socialSkills, onChanged: (v) => _touch(() => _d.socialSkills = v), maxLines: 3, required: true),
          _txt('peerInteraction', label: 'Peer interaction', value: _d.peerInteraction, onChanged: (v) => _touch(() => _d.peerInteraction = v), maxLines: 3, required: true),
          _txt('favouritePlay', label: 'Favourite play / motivators', value: _d.favouritePlay, onChanged: (v) => _touch(() => _d.favouritePlay = v), maxLines: 3, required: true),
          _txt('communicationAwareness', label: 'Communication self-awareness', value: _d.communicationAwareness, onChanged: (v) => _touch(() => _d.communicationAwareness = v), maxLines: 3, required: true),
        ];
      case 8:
        return [
          _txt('schoolNameAddress', label: 'School / nursery (name & address)', value: _d.schoolNameAddress, onChanged: (v) => _touch(() => _d.schoolNameAddress = v), maxLines: 3, required: true),
          _txt('nurseryDays', label: 'Nursery days/times', value: _d.nurseryDays, onChanged: (v) => _touch(() => _d.nurseryDays = v)),
          _txt('senPlan', label: 'SEN plan or EHCP', value: _d.senPlan, onChanged: (v) => _touch(() => _d.senPlan = v), maxLines: 2, required: true),
          _txt('anythingElse', label: 'Anything else about your child', value: _d.anythingElse, onChanged: (v) => _touch(() => _d.anythingElse = v), maxLines: 3),
          KeyedSubtree(
            key: _keyFor('photoConsent'),
            child: SonaYesNoField(label: 'May child be photographed/filmed?', value: _d.photoConsent, onChanged: (v) => _repaint(() => _d.photoConsent = v)),
          ),
          _txt('completedBy', label: 'Form completed by', value: _d.completedBy, onChanged: (v) => _touch(() => _d.completedBy = v), required: true),
          // completionDate is set automatically when you submit — no need to enter it
        ];
      default:
        return [];
    }
  }

  Widget _consentBlurb() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SonaColors.trustCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SonaColors.border),
      ),
      child: const Text(
        'The information you provide will not be released outside this agency without your consent. '
        'By completing this form, you grant permission to assess your child\'s speech and language needs.',
        style: TextStyle(fontSize: 12, height: 1.45, color: SonaColors.textSecondary),
      ),
    );
  }

  ({String badge, String title, String? subtitle}) _stepMeta(int step) {
    if (step == 1) {
      return widget.state.formSubstep == 0
          ? (
              badge: 'ABOUT YOUR FAMILY',
              title: 'About you & your child',
              subtitle: 'Your child\'s details and your contact information. Required fields are marked *.',
            )
          : (
              badge: 'GP & REFERRAL',
              title: 'GP & referral details',
              subtitle: 'Your GP\'s contact and how you were referred. Skip the second-parent section if it doesn\'t apply.',
            );
    }
    return switch (step) {
      2 => (
          badge: 'WHAT YOU\'RE NOTICING',
          title: 'Reason for referral',
          subtitle: 'Tell us what you are most worried about, then tick every area that applies.',
        ),
      3 => (
          badge: 'BACKGROUND',
          title: 'History & languages',
          subtitle: 'This helps your therapist understand previous support and your child\'s language environment. Skip anything you\'re unsure about.',
        ),
      4 => (
          badge: 'HEALTH & DEVELOPMENT',
          title: 'Pregnancy & birth history',
          subtitle: 'Birth and pregnancy details can be clinically relevant to speech and language development. Write "none" or "no concerns" where not applicable.',
        ),
      5 => (
          badge: 'HEALTH & DEVELOPMENT',
          title: 'Health & sensory',
          subtitle: 'Your child\'s health history helps the therapist plan the assessment safely. Write "none" or "not yet" where not applicable.',
        ),
      6 => (
          badge: 'SPEECH & LANGUAGE',
          title: 'Communication milestones',
          subtitle: 'These milestones help the therapist compare your child\'s development to typical patterns. Your best estimate is fine.',
        ),
      7 => (
          badge: 'PERSONALITY & PLAY',
          title: 'Temperament & play',
          subtitle: 'Understanding your child\'s personality and play style shapes how the assessment is carried out.',
        ),
      8 => (
          badge: 'SCHOOL & WRAP-UP',
          title: 'School & sign-off',
          subtitle: 'School or nursery context gives the therapist a fuller picture of your child\'s communication environment.',
        ),
      _ => (badge: 'INTAKE', title: 'Form', subtitle: null),
    };
  }

  /// Read-only computed age display shown below the Date of birth field.
  Widget _ageAtReferralDisplay() {
    final age = IntakeValidation.computeAgeAtReferral(_d.dateOfBirth);
    if (age == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: SonaColors.heroTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SonaColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, size: 16, color: SonaColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Age at referral: $age',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: SonaColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle for second parent / father details on Step 1b.
  Widget _fatherDetailsToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _repaint(() {
          _d.fatherDetailsApplicable = !_d.fatherDetailsApplicable;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _d.fatherDetailsApplicable ? SonaColors.heroTint : SonaColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _d.fatherDetailsApplicable ? SonaColors.primary : SonaColors.border,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _d.fatherDetailsApplicable,
                onChanged: (v) => _repaint(() {
                  _d.fatherDetailsApplicable = v ?? false;
                }),
                activeColor: SonaColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Add second parent / father details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SonaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
