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

  /// Returns first validation error for step, or null if valid.
  String? validateStep(int step) {
    bool req(String v) => v.trim().isNotEmpty;
    switch (step) {
      case 1:
        if (!req(email)) return 'Email is required';
        if (!IntakeValidation.isEmail(email)) return 'Enter a valid email address';
        if (!req(childName)) return "Child's name is required";
        if (!req(dateOfBirth)) return 'Date of birth is required';
        if (!IntakeValidation.isDdMmYyyy(dateOfBirth)) {
          return 'Date of birth must be DD/MM/YYYY (use the calendar)';
        }
        if (!req(ageAtReferral)) return 'Age at referral is required';
        if (!req(childAddress)) return 'Address is required';
        if (!req(motherName)) return "Mother's name is required";
        if (!req(motherMobile)) return "Mother's mobile is required";
        if (!req(motherEmail)) return "Mother's email is required";
        if (!req(fatherMobile)) return "Father's mobile is required";
        if (!req(fatherEmail)) return "Father's email is required";
        if (!req(gpPractice) || !req(gpAddress) || !req(gpPhone)) return 'GP details are required';
        if (!req(referredBy)) return 'Referral source is required';
        if (!req(heardAbout)) return 'How you heard about us is required';
        return null;
      case 2:
        if (!req(mainConcern)) return 'Main concern is required';
        if (difficulties.isEmpty) return 'Select at least one area of difficulty';
        return null;
      case 3:
        if (!req(assessedByOthers)) return 'Please answer about other professionals';
        if (assessedByOthers == 'yes' && !req(assessedByOthersDetails)) {
          return 'Please provide professional details';
        }
        if (!req(receivingTherapy)) return 'Please answer about therapy';
        if (receivingTherapy == 'yes' && !req(therapyDetails)) return 'Please provide therapy details';
        if (!req(languagesExposed)) return 'Languages exposed to is required';
        if (!req(parentLanguages)) return 'Parent languages are required';
        if (!req(childLanguages)) return 'Child languages are required';
        if (!req(familyHistory)) return 'Please answer about family history';
        if (familyHistory == 'yes' && !req(familyHistoryDetails)) {
          return 'Please explain family history';
        }
        return null;
      case 4:
        if (!req(pregnancyHealth)) return 'Pregnancy health is required';
        if (!req(prematureDetails)) return 'Premature birth details are required';
        if (!req(birthWeight)) return 'Birth weight is required';
        if (!req(birthComplications)) return 'Birth complications field is required';
        if (!req(afterBirthComplications)) return 'After-birth complications field is required';
        return null;
      case 5:
        for (final field in [
          earlyIllnesses,
          generalHealth,
          diagnosis,
          medications,
          hospitalised,
          hearingTested,
          earInfections,
          entInvolvement,
          visionTested,
        ]) {
          if (!req(field)) return 'Please complete all health fields';
        }
        return null;
      case 6:
        if (!req(respondsToName)) return 'Please answer if child responds to their name';
        if (!req(ageFirstWords)) return 'Age of first words is required';
        if (!req(ageTwoWordPhrases)) return 'Age of two-word phrases is required';
        if (!req(attentionListening)) return 'Attention and listening is required';
        if (!req(sentenceExamples)) return 'Sentence examples are required';
        if (!req(showsUnderstanding)) return 'How child shows understanding is required';
        return null;
      case 7:
        for (final field in [temperament, socialSkills, peerInteraction, favouritePlay, communicationAwareness]) {
          if (!req(field)) return 'Please complete all social/behaviour fields';
        }
        return null;
      case 8:
        if (!req(schoolNameAddress)) return 'School / nursery details are required';
        if (!req(senPlan)) return 'SEN / EHCP field is required';
        if (!req(photoConsent)) return 'Photo/film consent is required';
        if (!req(completedBy)) return 'Completed by is required';
        if (!req(completionDate)) return 'Date of completion is required';
        if (!IntakeValidation.isDdMmYyyy(completionDate)) {
          return 'Date of completion must be DD/MM/YYYY (use the calendar)';
        }
        return null;
      default:
        return null;
    }
  }
}
