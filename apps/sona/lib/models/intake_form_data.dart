import 'package:sona/models/intake_constants.dart';
import 'package:sona/utils/intake_validation.dart';

/// Parent intake answers — in-memory only; persisted via encrypted channel / API draft.
class IntakeFormData {
  IntakeFormData();

  String email = '';
  String childName = '';
  String dateOfBirth = '';
  String ageAtReferral = '';
  String childAddress = '';
  String motherName = '';
  String motherAddress = '';
  String motherMobile = '';
  String motherEmail = '';
  String fatherName = '';
  String fatherAddress = '';
  String fatherMobile = '';
  String fatherEmail = '';
  String gpPractice = '';
  String gpAddress = '';
  String gpPhone = '';
  String referredBy = '';
  String heardAbout = '';
  String mainConcern = '';
  final Set<String> difficulties = {};
  String assessedByOthers = '';
  String assessedByOthersDetails = '';
  String receivingTherapy = '';
  String therapyDetails = '';
  String languagesExposed = '';
  String parentLanguages = '';
  String childLanguages = '';
  String familyHistory = '';
  String familyHistoryDetails = '';
  String pregnancyHealth = '';
  String prematureDetails = '';
  String birthWeight = '';
  String birthComplications = '';
  String afterBirthComplications = '';
  String earlyIllnesses = '';
  String generalHealth = '';
  String diagnosis = '';
  String medications = '';
  String hospitalised = '';
  String hearingTested = '';
  String earInfections = '';
  String entInvolvement = '';
  String visionTested = '';
  String respondsToName = '';
  String ageFirstWords = '';
  String ageTwoWordPhrases = '';
  String attentionListening = '';
  String sentenceExamples = '';
  String showsUnderstanding = '';
  String temperament = '';
  String socialSkills = '';
  String peerInteraction = '';
  String favouritePlay = '';
  String communicationAwareness = '';
  String schoolNameAddress = '';
  String nurseryDays = '';
  String senPlan = '';
  String anythingElse = '';
  String photoConsent = '';
  String completedBy = '';
  String completionDate = '';

  Map<String, dynamic> toJson() => {
        'version': 1,
        'email': email,
        'childName': childName,
        'dateOfBirth': dateOfBirth,
        'ageAtReferral': ageAtReferral,
        'childAddress': childAddress,
        'motherName': motherName,
        'motherAddress': motherAddress,
        'motherMobile': motherMobile,
        'motherEmail': motherEmail,
        'fatherName': fatherName,
        'fatherAddress': fatherAddress,
        'fatherMobile': fatherMobile,
        'fatherEmail': fatherEmail,
        'gpPractice': gpPractice,
        'gpAddress': gpAddress,
        'gpPhone': gpPhone,
        'referredBy': referredBy,
        'heardAbout': heardAbout,
        'mainConcern': mainConcern,
        'difficulties': difficulties.toList(),
        'assessedByOthers': assessedByOthers,
        'assessedByOthersDetails': assessedByOthersDetails,
        'receivingTherapy': receivingTherapy,
        'therapyDetails': therapyDetails,
        'languagesExposed': languagesExposed,
        'parentLanguages': parentLanguages,
        'childLanguages': childLanguages,
        'familyHistory': familyHistory,
        'familyHistoryDetails': familyHistoryDetails,
        'pregnancyHealth': pregnancyHealth,
        'prematureDetails': prematureDetails,
        'birthWeight': birthWeight,
        'birthComplications': birthComplications,
        'afterBirthComplications': afterBirthComplications,
        'earlyIllnesses': earlyIllnesses,
        'generalHealth': generalHealth,
        'diagnosis': diagnosis,
        'medications': medications,
        'hospitalised': hospitalised,
        'hearingTested': hearingTested,
        'earInfections': earInfections,
        'entInvolvement': entInvolvement,
        'visionTested': visionTested,
        'respondsToName': respondsToName,
        'ageFirstWords': ageFirstWords,
        'ageTwoWordPhrases': ageTwoWordPhrases,
        'attentionListening': attentionListening,
        'sentenceExamples': sentenceExamples,
        'showsUnderstanding': showsUnderstanding,
        'temperament': temperament,
        'socialSkills': socialSkills,
        'peerInteraction': peerInteraction,
        'favouritePlay': favouritePlay,
        'communicationAwareness': communicationAwareness,
        'schoolNameAddress': schoolNameAddress,
        'nurseryDays': nurseryDays,
        'senPlan': senPlan,
        'anythingElse': anythingElse,
        'photoConsent': photoConsent,
        'completedBy': completedBy,
        'completionDate': completionDate,
      };

  static IntakeFormData fromJson(Map<String, dynamic> json) {
    final d = IntakeFormData();
    String s(String k) => (json[k] as String?)?.trim() ?? '';
    d.email = s('email');
    d.childName = s('childName');
    d.dateOfBirth = s('dateOfBirth');
    d.ageAtReferral = s('ageAtReferral');
    d.childAddress = s('childAddress');
    d.motherName = s('motherName');
    d.motherAddress = s('motherAddress');
    d.motherMobile = s('motherMobile');
    d.motherEmail = s('motherEmail');
    d.fatherName = s('fatherName');
    d.fatherAddress = s('fatherAddress');
    d.fatherMobile = s('fatherMobile');
    d.fatherEmail = s('fatherEmail');
    d.gpPractice = s('gpPractice');
    d.gpAddress = s('gpAddress');
    d.gpPhone = s('gpPhone');
    d.referredBy = s('referredBy');
    d.heardAbout = s('heardAbout');
    d.mainConcern = s('mainConcern');
    final diff = json['difficulties'];
    if (diff is List) {
      d.difficulties
        ..clear()
        ..addAll(diff.whereType<String>().where(IntakeConstants.allDifficulties.contains));
    }
    d.assessedByOthers = s('assessedByOthers');
    d.assessedByOthersDetails = s('assessedByOthersDetails');
    d.receivingTherapy = s('receivingTherapy');
    d.therapyDetails = s('therapyDetails');
    d.languagesExposed = s('languagesExposed');
    d.parentLanguages = s('parentLanguages');
    d.childLanguages = s('childLanguages');
    d.familyHistory = s('familyHistory');
    d.familyHistoryDetails = s('familyHistoryDetails');
    d.pregnancyHealth = s('pregnancyHealth');
    d.prematureDetails = s('prematureDetails');
    d.birthWeight = s('birthWeight');
    d.birthComplications = s('birthComplications');
    d.afterBirthComplications = s('afterBirthComplications');
    d.earlyIllnesses = s('earlyIllnesses');
    d.generalHealth = s('generalHealth');
    d.diagnosis = s('diagnosis');
    d.medications = s('medications');
    d.hospitalised = s('hospitalised');
    d.hearingTested = s('hearingTested');
    d.earInfections = s('earInfections');
    d.entInvolvement = s('entInvolvement');
    d.visionTested = s('visionTested');
    d.respondsToName = s('respondsToName');
    d.ageFirstWords = s('ageFirstWords');
    d.ageTwoWordPhrases = s('ageTwoWordPhrases');
    d.attentionListening = s('attentionListening');
    d.sentenceExamples = s('sentenceExamples');
    d.showsUnderstanding = s('showsUnderstanding');
    d.temperament = s('temperament');
    d.socialSkills = s('socialSkills');
    d.peerInteraction = s('peerInteraction');
    d.favouritePlay = s('favouritePlay');
    d.communicationAwareness = s('communicationAwareness');
    d.schoolNameAddress = s('schoolNameAddress');
    d.nurseryDays = s('nurseryDays');
    d.senPlan = s('senPlan');
    d.anythingElse = s('anythingElse');
    d.photoConsent = s('photoConsent');
    d.completedBy = s('completedBy');
    d.completionDate = s('completionDate');
    return d;
  }

  /// Field keys rendered on step 1 page 1 (1a): parent contact, child basics, mother contacts.
  static const Set<String> step1aFieldKeys = {
    'email',
    'childName',
    'dateOfBirth',
    'ageAtReferral',
    'childAddress',
    'motherName',
    'motherAddress',
    'motherMobile',
    'motherEmail',
  };

  /// Field keys rendered on step 1 page 2 (1b): father contacts, GP, referral.
  static const Set<String> step1bFieldKeys = {
    'fatherName',
    'fatherAddress',
    'fatherMobile',
    'fatherEmail',
    'gpPractice',
    'gpAddress',
    'gpPhone',
    'referredBy',
    'heardAbout',
  };

  /// Validate only the fields visible on step 1 page 1.
  ({String message, String fieldKey})? validateStep1a() {
    final err = validateStep(1);
    if (err == null) return null;
    return step1aFieldKeys.contains(err.fieldKey) ? err : null;
  }

  /// Returns first validation error for [step] as `(message, fieldKey)`, or null if valid.
  /// [fieldKey] matches the keys used in [ParentIntakeStepScreen] to highlight
  /// and scroll to the failing field.
  ({String message, String fieldKey})? validateStep(int step) {
    ({String message, String fieldKey}) err(String message, String fieldKey) =>
        (message: message, fieldKey: fieldKey);
    bool req(String v) => v.trim().isNotEmpty;
    switch (step) {
      case 1:
        if (!req(email)) return err('Email is required', 'email');
        if (!IntakeValidation.isEmail(email)) return err('Enter a valid email address', 'email');
        if (!req(childName)) return err("Child's name is required", 'childName');
        if (!req(dateOfBirth)) return err('Date of birth is required', 'dateOfBirth');
        if (!IntakeValidation.isDdMmYyyy(dateOfBirth)) {
          return err('Date of birth must be DD/MM/YYYY (use the calendar)', 'dateOfBirth');
        }
        if (!req(ageAtReferral)) return err('Age at referral is required', 'ageAtReferral');
        if (!req(childAddress)) return err('Address is required', 'childAddress');
        if (!req(motherName)) return err("Mother's name is required", 'motherName');
        if (!req(motherMobile)) return err("Mother's mobile is required", 'motherMobile');
        if (!req(motherEmail)) return err("Mother's email is required", 'motherEmail');
        if (!req(fatherMobile)) return err("Father's mobile is required", 'fatherMobile');
        if (!req(fatherEmail)) return err("Father's email is required", 'fatherEmail');
        if (!req(gpPractice)) return err('GP practice is required', 'gpPractice');
        if (!req(gpAddress)) return err('GP address is required', 'gpAddress');
        if (!req(gpPhone)) return err('GP phone is required', 'gpPhone');
        if (!req(referredBy)) return err('Referral source is required', 'referredBy');
        if (!req(heardAbout)) return err('How you heard about us is required', 'heardAbout');
        return null;
      case 2:
        if (!req(mainConcern)) return err('Main concern is required', 'mainConcern');
        if (difficulties.isEmpty) {
          return err('Select at least one area of difficulty', 'difficulties');
        }
        return null;
      case 3:
        if (!req(assessedByOthers)) return err('Please answer about other professionals', 'assessedByOthers');
        if (assessedByOthers == 'yes' && !req(assessedByOthersDetails)) {
          return err('Please provide professional details', 'assessedByOthersDetails');
        }
        if (!req(receivingTherapy)) return err('Please answer about therapy', 'receivingTherapy');
        if (receivingTherapy == 'yes' && !req(therapyDetails)) {
          return err('Please provide therapy details', 'therapyDetails');
        }
        if (!req(languagesExposed)) return err('Languages exposed to is required', 'languagesExposed');
        if (!req(parentLanguages)) return err('Parent languages are required', 'parentLanguages');
        if (!req(childLanguages)) return err('Child languages are required', 'childLanguages');
        if (!req(familyHistory)) return err('Please answer about family history', 'familyHistory');
        if (familyHistory == 'yes' && !req(familyHistoryDetails)) {
          return err('Please explain family history', 'familyHistoryDetails');
        }
        return null;
      case 4:
        if (!req(pregnancyHealth)) return err('Pregnancy health is required', 'pregnancyHealth');
        if (!req(prematureDetails)) return err('Premature birth details are required', 'prematureDetails');
        if (!req(birthWeight)) return err('Birth weight is required', 'birthWeight');
        if (!req(birthComplications)) {
          return err('Birth complications field is required', 'birthComplications');
        }
        if (!req(afterBirthComplications)) {
          return err('After-birth complications field is required', 'afterBirthComplications');
        }
        return null;
      case 5:
        final step5 = <(String, String, String)>[
          (earlyIllnesses, 'earlyIllnesses', 'Early childhood illnesses'),
          (generalHealth, 'generalHealth', 'General health'),
          (diagnosis, 'diagnosis', 'Known diagnosis'),
          (medications, 'medications', 'Regular medications'),
          (hospitalised, 'hospitalised', 'Hospitalised'),
          (hearingTested, 'hearingTested', 'Hearing tested'),
          (earInfections, 'earInfections', 'History of ear infections'),
          (entInvolvement, 'entInvolvement', 'ENT involvement'),
          (visionTested, 'visionTested', 'Eyes tested'),
        ];
        for (final f in step5) {
          if (!req(f.$1)) return err('${f.$3} is required', f.$2);
        }
        return null;
      case 6:
        if (!req(respondsToName)) {
          return err('Please answer if child responds to their name', 'respondsToName');
        }
        if (!req(ageFirstWords)) return err('Age of first words is required', 'ageFirstWords');
        if (!req(ageTwoWordPhrases)) {
          return err('Age of two-word phrases is required', 'ageTwoWordPhrases');
        }
        if (!req(attentionListening)) {
          return err('Attention and listening is required', 'attentionListening');
        }
        if (!req(sentenceExamples)) return err('Sentence examples are required', 'sentenceExamples');
        if (!req(showsUnderstanding)) {
          return err('How child shows understanding is required', 'showsUnderstanding');
        }
        return null;
      case 7:
        final step7 = <(String, String, String)>[
          (temperament, 'temperament', 'Temperament'),
          (socialSkills, 'socialSkills', 'Social skills'),
          (peerInteraction, 'peerInteraction', 'Peer interaction'),
          (favouritePlay, 'favouritePlay', 'Favourite play'),
          (communicationAwareness, 'communicationAwareness', 'Communication self-awareness'),
        ];
        for (final f in step7) {
          if (!req(f.$1)) return err('${f.$3} is required', f.$2);
        }
        return null;
      case 8:
        if (!req(schoolNameAddress)) {
          return err('School / nursery details are required', 'schoolNameAddress');
        }
        if (!req(senPlan)) return err('SEN / EHCP field is required', 'senPlan');
        if (!req(photoConsent)) return err('Photo/film consent is required', 'photoConsent');
        if (!req(completedBy)) return err('Completed by is required', 'completedBy');
        if (!req(completionDate)) return err('Date of completion is required', 'completionDate');
        if (!IntakeValidation.isDdMmYyyy(completionDate)) {
          return err('Date of completion must be DD/MM/YYYY (use the calendar)', 'completionDate');
        }
        return null;
      default:
        return null;
    }
  }
}
