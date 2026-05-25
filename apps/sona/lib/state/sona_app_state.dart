import 'package:flutter/foundation.dart';
import 'package:sona/models/intake_form_data.dart';
import 'package:sona/models/intake_template.dart';

class SonaAppState extends ChangeNotifier {
  String? tenantId;
  String? caseId;
  final IntakeFormData intake = IntakeFormData();
  int formStep = 1;
  /// Step 1 is paginated 1a/1b to keep scrolling short on mobile.
  /// 0 = page 1 (parent + child basics + mother contacts).
  /// 1 = page 2 (father + GP + referral).
  int formSubstep = 0;
  bool returnToReviewAfterEdit = false;
  DateTime? lastSavedAt;
  DateTime? lastLocalSavedAt;
  bool draftDirty = false;

  /// Set by [IntakeLocalAutosave.attach]; fired on every edit.
  VoidCallback? onFormEdited;

  bool consentGuardian = false;
  bool consentPrivacy = false;
  bool consentAccurate = false;
  String triageOutcome = 'short_block';
  String prepStatus = 'Ready';
  List<Map<String, dynamic>> clinicianCases = [];
  IntakeTemplateId intakeTemplateId = IntakeTemplateId.full;
  bool intakeLocked = false;
  bool intakeLinkExpired = false;

  /// Field key of the most recent failed validation on the current step.
  /// Set by `_parentContinue` when validation blocks progress; consumed by
  /// `ParentIntakeStepScreen` to highlight + scroll to the failing field.
  String? pendingValidationFieldKey;
  String? pendingValidationMessage;

  String get childName => intake.childName.trim().isNotEmpty ? intake.childName.trim() : 'Child';
  int get templateTotalSteps => templateStepCount(intakeTemplateId);

  int templateProgressForStep(int step) => templateProgressIndex(intakeTemplateId, step);

  bool stepAllowed(int step) => isStepInTemplate(intakeTemplateId, step);

  int? advanceTemplateStep(int current) => nextTemplateStep(intakeTemplateId, current);

  String get parentEmail => intake.email.trim().isNotEmpty ? intake.email.trim() : 'parent@example.com';

  /// Marks draft dirty and schedules local autosave — does not rebuild the widget tree.
  void markDraftDirty() {
    draftDirty = true;
    onFormEdited?.call();
  }

  void applyDraftAnswers(Map<String, dynamic> answers, {int? step}) {
    final loaded = IntakeFormData.fromJson(answers);
    _copyIntake(loaded);
    if (step != null) formStep = step.clamp(1, 8);
    consentGuardian = answers['consentGuardian'] as bool? ?? consentGuardian;
    consentPrivacy = answers['consentPrivacy'] as bool? ?? consentPrivacy;
    consentAccurate = answers['consentAccurate'] as bool? ?? consentAccurate;
    draftDirty = false;
    notifyListeners();
  }

  void _copyIntake(IntakeFormData src) {
    intake.email = src.email;
    intake.childName = src.childName;
    intake.dateOfBirth = src.dateOfBirth;
    // ageAtReferral is a computed getter — no assignment needed
    intake.childAddress = src.childAddress;
    intake.motherName = src.motherName;
    intake.motherAddress = src.motherAddress;
    intake.motherMobile = src.motherMobile;
    intake.motherEmail = src.motherEmail;
    intake.fatherDetailsApplicable = src.fatherDetailsApplicable;
    intake.secondParentRelationship = src.secondParentRelationship;
    intake.ageAtReferralOverride = src.ageAtReferralOverride;
    intake.fatherName = src.fatherName;
    intake.fatherAddress = src.fatherAddress;
    intake.fatherMobile = src.fatherMobile;
    intake.fatherEmail = src.fatherEmail;
    intake.gpPractice = src.gpPractice;
    intake.gpAddress = src.gpAddress;
    intake.gpPhone = src.gpPhone;
    intake.referredBy = src.referredBy;
    intake.heardAbout = src.heardAbout;
    intake.mainConcern = src.mainConcern;
    intake.difficulties
      ..clear()
      ..addAll(src.difficulties);
    intake.assessedByOthers = src.assessedByOthers;
    intake.assessedByOthersDetails = src.assessedByOthersDetails;
    intake.receivingTherapy = src.receivingTherapy;
    intake.therapyDetails = src.therapyDetails;
    intake.languagesExposed = src.languagesExposed;
    intake.parentLanguages = src.parentLanguages;
    intake.childLanguages = src.childLanguages;
    intake.familyHistory = src.familyHistory;
    intake.familyHistoryDetails = src.familyHistoryDetails;
    intake.pregnancyHealth = src.pregnancyHealth;
    intake.prematureDetails = src.prematureDetails;
    intake.birthWeight = src.birthWeight;
    intake.birthComplications = src.birthComplications;
    intake.afterBirthComplications = src.afterBirthComplications;
    intake.earlyIllnesses = src.earlyIllnesses;
    intake.generalHealth = src.generalHealth;
    intake.diagnosis = src.diagnosis;
    intake.medications = src.medications;
    intake.hospitalised = src.hospitalised;
    intake.hospitalisedDetails = src.hospitalisedDetails;
    intake.hearingTested = src.hearingTested;
    intake.hearingTestedDetails = src.hearingTestedDetails;
    intake.earInfections = src.earInfections;
    intake.earInfectionsDetails = src.earInfectionsDetails;
    intake.entInvolvement = src.entInvolvement;
    intake.entInvolvementDetails = src.entInvolvementDetails;
    intake.visionTested = src.visionTested;
    intake.visionTestedDetails = src.visionTestedDetails;
    intake.respondsToName = src.respondsToName;
    intake.ageFirstWords = src.ageFirstWords;
    intake.ageTwoWordPhrases = src.ageTwoWordPhrases;
    intake.attentionListening = src.attentionListening;
    intake.sentenceExamples = src.sentenceExamples;
    intake.showsUnderstanding = src.showsUnderstanding;
    intake.temperament = src.temperament;
    intake.socialSkills = src.socialSkills;
    intake.peerInteraction = src.peerInteraction;
    intake.favouritePlay = src.favouritePlay;
    intake.communicationAwareness = src.communicationAwareness;
    intake.schoolNameAddress = src.schoolNameAddress;
    intake.nurseryDays = src.nurseryDays;
    intake.senPlan = src.senPlan;
    intake.anythingElse = src.anythingElse;
    intake.photoConsent = src.photoConsent;
    intake.completedBy = src.completedBy;
    // completionDate is set server-side — not copied
  }

  Map<String, dynamic> buildAnswersPayload() {
    final json = intake.toJson();
    json['formStep'] = formStep;
    json['consentGuardian'] = consentGuardian;
    json['consentPrivacy'] = consentPrivacy;
    json['consentAccurate'] = consentAccurate;
    return json;
  }

  void resetForDemo() {
    tenantId = null;
    caseId = null;
    formStep = 1;
    formSubstep = 0;
    returnToReviewAfterEdit = false;
    lastSavedAt = null;
    lastLocalSavedAt = null;
    draftDirty = false;
    onFormEdited = null;
    consentGuardian = false;
    consentPrivacy = false;
    consentAccurate = false;
    triageOutcome = 'short_block';
    prepStatus = 'Ready';
    clinicianCases = [];
    intake
      ..email = ''
      ..childName = ''
      ..difficulties.clear();
    notifyListeners();
  }
}
