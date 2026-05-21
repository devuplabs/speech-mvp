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

  @override
  Widget build(BuildContext context) {
    final step = widget.state.formStep;
    final meta = _stepMeta(step);
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
        const SizedBox(height: 16),
        ..._fieldsForStep(step),
      ]),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Row(
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
      ),
    );
  }

  Widget _header(int step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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
                ),
              ),
              Expanded(
                child: Text(
                  'Step $step of 8',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              OutlinedButton(
                onPressed: widget.saving ? null : () => widget.onSaveExit(),
                child: Text(widget.saving ? 'Saving…' : 'Save & exit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SonaStepProgress(currentStep: step, totalSteps: 8),
          if (widget.state.lastLocalSavedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Saved on this device ${_formatSaved(widget.state.lastLocalSavedAt!)}',
              style: const TextStyle(fontSize: 11, color: SonaColors.textMuted),
            ),
          ] else if (widget.state.draftDirty) ...[
            const SizedBox(height: 6),
            const Text(
              'Unsaved changes',
              style: TextStyle(fontSize: 11, color: SonaColors.textMuted),
            ),
          ],
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

  List<Widget> _fieldsForStep(int step) {

    switch (step) {
      case 1:
        return [
          SonaTextField(
            label: 'Email',
            value: _d.email,
            onChanged: (v) => _touch(() => _d.email = v),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            required: true,
          ),
          _consentBlurb(),
          SonaTextField(label: "Child's name", value: _d.childName, onChanged: (v) => _touch(() => _d.childName = v), required: true),
          SonaDateField(
            label: 'Date of birth',
            value: _d.dateOfBirth,
            onChanged: (v) => _repaint(() => _d.dateOfBirth = v),
            required: true,
            lastDate: DateTime.now(),
          ),
          SonaTextField(label: 'Age at referral', value: _d.ageAtReferral, onChanged: (v) => _touch(() => _d.ageAtReferral = v), required: true),
          SonaTextField(label: "Child's address", value: _d.childAddress, onChanged: (v) => _touch(() => _d.childAddress = v), required: true),
          SonaTextField(label: "Mother's name", value: _d.motherName, onChanged: (v) => _touch(() => _d.motherName = v), required: true),
          SonaTextField(label: "Mother's address if different", value: _d.motherAddress, onChanged: (v) => _touch(() => _d.motherAddress = v)),
          SonaTextField(label: "Mother's mobile", value: _d.motherMobile, onChanged: (v) => _touch(() => _d.motherMobile = v), keyboardType: TextInputType.phone, required: true),
          SonaTextField(label: "Mother's email", value: _d.motherEmail, onChanged: (v) => _touch(() => _d.motherEmail = v), keyboardType: TextInputType.emailAddress, required: true),
          SonaTextField(label: "Father's name", value: _d.fatherName, onChanged: (v) => _touch(() => _d.fatherName = v)),
          SonaTextField(label: "Father's address if different", value: _d.fatherAddress, onChanged: (v) => _touch(() => _d.fatherAddress = v)),
          SonaTextField(label: "Father's mobile", value: _d.fatherMobile, onChanged: (v) => _touch(() => _d.fatherMobile = v), keyboardType: TextInputType.phone, required: true),
          SonaTextField(label: "Father's email", value: _d.fatherEmail, onChanged: (v) => _touch(() => _d.fatherEmail = v), keyboardType: TextInputType.emailAddress, required: true),
          SonaTextField(label: 'GP practice', value: _d.gpPractice, onChanged: (v) => _touch(() => _d.gpPractice = v), required: true),
          SonaTextField(label: 'GP address', value: _d.gpAddress, onChanged: (v) => _touch(() => _d.gpAddress = v), maxLines: 2, required: true),
          SonaTextField(label: 'GP phone', value: _d.gpPhone, onChanged: (v) => _touch(() => _d.gpPhone = v), keyboardType: TextInputType.phone, required: true),
          SonaTextField(label: 'Who referred your child?', value: _d.referredBy, onChanged: (v) => _touch(() => _d.referredBy = v), required: true),
          SonaTextField(label: 'How did you hear about Speech Sanctuary?', value: _d.heardAbout, onChanged: (v) => _touch(() => _d.heardAbout = v), required: true),
        ];
      case 2:
        return [
          SonaTextField(label: 'Main concern', value: _d.mainConcern, onChanged: (v) => _touch(() => _d.mainConcern = v), maxLines: 4, required: true),
          const SizedBox(height: 8),
          const Text(
            'Is your child having difficulty with (tick all that apply)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DifficultyChecklist(
            selected: _d.difficulties,
            onChanged: (next) {
              _d.difficulties
                ..clear()
                ..addAll(next);
              widget.state.markDraftDirty();
            },
          ),
        ];
      case 3:
        return [
          SonaYesNoField(
            label: 'Assessed by other professionals?',
            value: _d.assessedByOthers,
            onChanged: (v) => _repaint(() => _d.assessedByOthers = v),
            detailLabel: 'If yes — details',
            detailValue: _d.assessedByOthersDetails,
            onDetailChanged: (v) => _touch(() => _d.assessedByOthersDetails = v),
          ),
          SonaYesNoField(
            label: 'Receiving therapy now?',
            value: _d.receivingTherapy,
            onChanged: (v) => _repaint(() => _d.receivingTherapy = v),
            detailLabel: 'If yes — therapy details',
            detailValue: _d.therapyDetails,
            onDetailChanged: (v) => _touch(() => _d.therapyDetails = v),
          ),
          SonaTextField(label: 'Languages child exposed to', value: _d.languagesExposed, onChanged: (v) => _touch(() => _d.languagesExposed = v), maxLines: 2, required: true),
          SonaTextField(label: 'Languages spoken by parents', value: _d.parentLanguages, onChanged: (v) => _touch(() => _d.parentLanguages = v), maxLines: 2, required: true),
          SonaTextField(label: 'Languages spoken by child', value: _d.childLanguages, onChanged: (v) => _touch(() => _d.childLanguages = v), maxLines: 2, required: true),
          SonaYesNoField(
            label: 'Family history of SLT/learning/attention difficulties?',
            value: _d.familyHistory,
            onChanged: (v) => _repaint(() => _d.familyHistory = v),
            detailLabel: 'If yes — explain',
            detailValue: _d.familyHistoryDetails,
            onDetailChanged: (v) => _touch(() => _d.familyHistoryDetails = v),
          ),
        ];
      case 4:
        return [
          SonaTextField(label: "Mother's health during pregnancy", value: _d.pregnancyHealth, onChanged: (v) => _touch(() => _d.pregnancyHealth = v), maxLines: 3, required: true),
          SonaTextField(label: 'Premature? If yes, how many weeks', value: _d.prematureDetails, onChanged: (v) => _touch(() => _d.prematureDetails = v), required: true),
          SonaTextField(label: "Baby's weight at birth", value: _d.birthWeight, onChanged: (v) => _touch(() => _d.birthWeight = v), required: true),
          SonaTextField(label: 'Complications during birth', value: _d.birthComplications, onChanged: (v) => _touch(() => _d.birthComplications = v), maxLines: 3, required: true),
          SonaTextField(label: 'Complications after birth', value: _d.afterBirthComplications, onChanged: (v) => _touch(() => _d.afterBirthComplications = v), maxLines: 3, required: true),
        ];
      case 5:
        return [
          SonaTextField(label: 'Early childhood illnesses', value: _d.earlyIllnesses, onChanged: (v) => _touch(() => _d.earlyIllnesses = v), maxLines: 2, required: true),
          SonaTextField(label: 'General health', value: _d.generalHealth, onChanged: (v) => _touch(() => _d.generalHealth = v), maxLines: 2, required: true),
          SonaTextField(label: 'Known diagnosis / syndrome', value: _d.diagnosis, onChanged: (v) => _touch(() => _d.diagnosis = v), maxLines: 2, required: true),
          SonaTextField(label: 'Regular medications', value: _d.medications, onChanged: (v) => _touch(() => _d.medications = v), maxLines: 2, required: true),
          SonaTextField(label: 'Hospitalised? (details)', value: _d.hospitalised, onChanged: (v) => _touch(() => _d.hospitalised = v), maxLines: 2, required: true),
          SonaTextField(label: 'Hearing tested? (when & outcome)', value: _d.hearingTested, onChanged: (v) => _touch(() => _d.hearingTested = v), maxLines: 2, required: true),
          SonaTextField(label: 'History of ear infections', value: _d.earInfections, onChanged: (v) => _touch(() => _d.earInfections = v), maxLines: 2, required: true),
          SonaTextField(label: 'Ear surgery / ENT involvement', value: _d.entInvolvement, onChanged: (v) => _touch(() => _d.entInvolvement = v), maxLines: 2, required: true),
          SonaTextField(label: 'Eyes tested? (when & outcome)', value: _d.visionTested, onChanged: (v) => _touch(() => _d.visionTested = v), maxLines: 2, required: true),
        ];
      case 6:
        return [
          SonaYesNoField(label: 'Responds to own name?', value: _d.respondsToName, onChanged: (v) => _repaint(() => _d.respondsToName = v)),
          SonaTextField(label: 'Age of first words', value: _d.ageFirstWords, onChanged: (v) => _touch(() => _d.ageFirstWords = v), required: true),
          SonaTextField(label: 'Age of two-word phrases', value: _d.ageTwoWordPhrases, onChanged: (v) => _touch(() => _d.ageTwoWordPhrases = v), required: true),
          SonaTextField(label: 'Attention & listening skills', value: _d.attentionListening, onChanged: (v) => _touch(() => _d.attentionListening = v), maxLines: 3, required: true),
          SonaTextField(label: 'Sentence examples', value: _d.sentenceExamples, onChanged: (v) => _touch(() => _d.sentenceExamples = v), maxLines: 3, required: true),
          SonaTextField(label: 'Shows understanding by', value: _d.showsUnderstanding, onChanged: (v) => _touch(() => _d.showsUnderstanding = v), maxLines: 3, required: true),
        ];
      case 7:
        return [
          SonaTextField(label: 'Describe your child (temperament)', value: _d.temperament, onChanged: (v) => _touch(() => _d.temperament = v), maxLines: 3, required: true),
          SonaTextField(label: 'Social skills', value: _d.socialSkills, onChanged: (v) => _touch(() => _d.socialSkills = v), maxLines: 3, required: true),
          SonaTextField(label: 'Peer interaction', value: _d.peerInteraction, onChanged: (v) => _touch(() => _d.peerInteraction = v), maxLines: 3, required: true),
          SonaTextField(label: 'Favourite play / motivators', value: _d.favouritePlay, onChanged: (v) => _touch(() => _d.favouritePlay = v), maxLines: 3, required: true),
          SonaTextField(label: 'Communication self-awareness', value: _d.communicationAwareness, onChanged: (v) => _touch(() => _d.communicationAwareness = v), maxLines: 3, required: true),
        ];
      case 8:
        return [
          SonaTextField(label: 'School / nursery (name & address)', value: _d.schoolNameAddress, onChanged: (v) => _touch(() => _d.schoolNameAddress = v), maxLines: 3, required: true),
          SonaTextField(label: 'Nursery days/times', value: _d.nurseryDays, onChanged: (v) => _touch(() => _d.nurseryDays = v)),
          SonaTextField(label: 'SEN plan or EHCP', value: _d.senPlan, onChanged: (v) => _touch(() => _d.senPlan = v), maxLines: 2, required: true),
          SonaTextField(label: 'Anything else about your child', value: _d.anythingElse, onChanged: (v) => _touch(() => _d.anythingElse = v), maxLines: 3),
          SonaYesNoField(label: 'May child be photographed/filmed?', value: _d.photoConsent, onChanged: (v) => _repaint(() => _d.photoConsent = v)),
          SonaTextField(label: 'Form completed by', value: _d.completedBy, onChanged: (v) => _touch(() => _d.completedBy = v), required: true),
          SonaDateField(
            label: 'Date of completion',
            value: _d.completionDate,
            onChanged: (v) => _repaint(() => _d.completionDate = v),
            required: true,
            lastDate: DateTime.now(),
          ),
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
    return switch (step) {
      1 => (badge: 'CONTACT & CHILD', title: 'Your details & referral', subtitle: 'Required fields are marked *. Scroll for all questions.'),
      2 => (badge: 'REASON FOR REFERRAL', title: 'Reason for referral', subtitle: 'Tell us what you are most worried about, then tick every area that applies.'),
      3 => (badge: 'BACKGROUND', title: 'History & languages', subtitle: null),
      4 => (badge: 'PREGNANCY & BIRTH', title: 'Birth history', subtitle: null),
      5 => (badge: 'GENERAL HEALTH', title: 'Health & sensory', subtitle: null),
      6 => (badge: 'SPEECH & LANGUAGE', title: 'Communication milestones', subtitle: null),
      7 => (badge: 'SOCIAL / BEHAVIOUR', title: 'Temperament & play', subtitle: null),
      8 => (badge: 'EDUCATION', title: 'School & sign-off', subtitle: null),
      _ => (badge: 'INTAKE', title: 'Form', subtitle: null),
    };
  }
}
