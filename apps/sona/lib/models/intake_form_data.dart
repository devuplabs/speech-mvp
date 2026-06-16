import 'package:sona/models/intake_constants.dart';
import 'package:sona/utils/intake_validation.dart';

/// Parent intake answers — in-memory only; persisted via encrypted channel / API draft.
class IntakeFormData {
  IntakeFormData();

  String email = '';
  String childName = '';
  String dateOfBirth = '';

  /// Optional manual override for [ageAtReferral].
  /// When non-empty, the parent has explicitly edited the computed value
  /// (e.g. referral happened months before today).
  String ageAtReferralOverride = '';

  /// Effective age at referral — uses the parent's manual edit when provided,
  /// otherwise auto-computed from [dateOfBirth].
  /// Kept in the JSON payload so the clinician dashboard is unchanged.
  String get ageAtReferral =>
      ageAtReferralOverride.trim().isNotEmpty
          ? ageAtReferralOverride
          : IntakeValidation.computeAgeAtReferral(dateOfBirth) ?? '';

  String childAddress = '';
  String motherName = '';
  String motherAddress = '';
  String motherMobile = '';
  String motherEmail = '';
  /// Whether the parent has indicated a second parent / guardian is involved.
  /// When false, second parent fields are not required.
  bool fatherDetailsApplicable = false;
  /// Relationship of the second parent to the child (e.g. Father, Mother, Guardian, Carer).
  /// Kept as free text to be inclusive of all family structures.
  String secondParentRelationship = '';
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
  // Step 5 binary fields — stored as 'yes'/'no'; detail text in _details companion
  String hospitalised = '';
  String hospitalisedDetails = '';
  String hearingTested = '';
  String hearingTestedDetails = '';
  String earInfections = '';
  String earInfectionsDetails = '';
  String entInvolvement = '';
  String entInvolvementDetails = '';
  String visionTested = '';
  String visionTestedDetails = '';
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

  /// completionDate is set server-side from submittedAt. Not collected from the parent.
  /// Omitted from the client payload; the API fills it on submission.

  /// Parses a combined "Yes — detail" or "No" string back into separate parts.
  /// Handles legacy free-text values by treating them as the detail with "yes".
  static void _parseBinary(String raw, void Function(String yn, String details) out) {
    final v = raw.trim();
    if (v.isEmpty) { out('', ''); return; }
    if (v.toLowerCase() == 'no') { out('no', ''); return; }
    if (v.startsWith('Yes — ')) { out('yes', v.substring(6)); return; }
    if (v.toLowerCase() == 'yes') { out('yes', ''); return; }
    // Legacy free-text (e.g. "Yes normal") — treat as a "yes" with the full text as detail
    out('yes', v);
  }

  /// Produces a rich text string for the clinician dashboard from a yes/no
  /// binary value and optional detail text, e.g. "Yes — Normal results".
  /// Falls back to [yesNo] alone when details are empty.
  static String _combine(String yesNo, String details) {
    final yn = yesNo.trim();
    final d = details.trim();
    if (yn == 'yes') return d.isNotEmpty ? 'Yes — $d' : 'Yes';
    if (yn == 'no') return 'No';
    // Legacy free-text value — return as-is
    return yn;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'email': email,
        'childName': childName,
        'dateOfBirth': dateOfBirth,
        'ageAtReferral': ageAtReferral, // effective value (override ?? computed) for clinician dashboard
        'childAddress': childAddress,
        'motherName': motherName,
        'motherAddress': motherAddress,
        'motherMobile': motherMobile,
        'motherEmail': motherEmail,
        'fatherDetailsApplicable': fatherDetailsApplicable,
        'secondParentRelationship': secondParentRelationship,
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
        'hospitalised': _combine(hospitalised, hospitalisedDetails),
        'hearingTested': _combine(hearingTested, hearingTestedDetails),
        'earInfections': _combine(earInfections, earInfectionsDetails),
        'entInvolvement': _combine(entInvolvement, entInvolvementDetails),
        'visionTested': _combine(visionTested, visionTestedDetails),
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
      };

  static IntakeFormData fromJson(Map<String, dynamic> json) {
    final d = IntakeFormData();
    String s(String k) => (json[k] as String?)?.trim() ?? '';
    d.email = s('email');
    d.childName = s('childName');
    d.dateOfBirth = s('dateOfBirth');
    // Restore override only if the saved value differs from the freshly computed value;
    // if it matches, leave override empty so re-computation keeps it up to date.
    final savedAge = s('ageAtReferral');
    final computed = IntakeValidation.computeAgeAtReferral(d.dateOfBirth) ?? '';
    d.ageAtReferralOverride = (savedAge.isNotEmpty && savedAge != computed) ? savedAge : '';
    d.childAddress = s('childAddress');
    d.motherName = s('motherName');
    d.motherAddress = s('motherAddress');
    d.motherMobile = s('motherMobile');
    d.motherEmail = s('motherEmail');
    // Restore father section visibility: true if any father field was previously saved
    final hasFatherData = (json['fatherMobile'] as String?)?.isNotEmpty == true ||
        (json['fatherEmail'] as String?)?.isNotEmpty == true ||
        (json['fatherName'] as String?)?.isNotEmpty == true;
    d.fatherDetailsApplicable = json['fatherDetailsApplicable'] as bool? ?? hasFatherData;
    d.secondParentRelationship = s('secondParentRelationship');
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
    // When loading from a draft that already stores separate _details keys (new format),
    // use those directly. Fall back to _parseBinary for combined legacy strings.
    _parseBinary(s('hospitalised'), (yn, det) {
      d.hospitalised = yn;
      d.hospitalisedDetails = s('hospitalisedDetails').isNotEmpty ? s('hospitalisedDetails') : det;
    });
    _parseBinary(s('hearingTested'), (yn, det) {
      d.hearingTested = yn;
      d.hearingTestedDetails = s('hearingTestedDetails').isNotEmpty ? s('hearingTestedDetails') : det;
    });
    _parseBinary(s('earInfections'), (yn, det) {
      d.earInfections = yn;
      d.earInfectionsDetails = s('earInfectionsDetails').isNotEmpty ? s('earInfectionsDetails') : det;
    });
    _parseBinary(s('entInvolvement'), (yn, det) {
      d.entInvolvement = yn;
      d.entInvolvementDetails = s('entInvolvementDetails').isNotEmpty ? s('entInvolvementDetails') : det;
    });
    _parseBinary(s('visionTested'), (yn, det) {
      d.visionTested = yn;
      d.visionTestedDetails = s('visionTestedDetails').isNotEmpty ? s('visionTestedDetails') : det;
    });
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
    // completionDate set server-side — not restored from JSON
    return d;
  }

  /// Field keys rendered on step 1 page 1 (1a): parent contact, child basics, mother contacts.
  static const Set<String> step1aFieldKeys = {
    'email',
    'childName',
    'dateOfBirth',
    'childAddress',
    'motherName',
    'motherAddress',
    'motherMobile',
    'motherEmail',
  };

  /// Maps intake field keys to the step where they are edited (for API errors).
  static int stepForFieldKey(String fieldKey) {
    if (step1aFieldKeys.contains(fieldKey)) return 1;
    if (step1bFieldKeys.contains(fieldKey)) return 1;
    const stepFields = <int, Set<String>>{
      2: {'mainConcern', 'difficulties'},
      3: {
        'assessedByOthers',
        'assessedByOthersDetails',
        'receivingTherapy',
        'therapyDetails',
        'languagesExposed',
        'parentLanguages',
        'childLanguages',
        'familyHistory',
        'familyHistoryDetails',
      },
      4: {
        'pregnancyHealth',
        'prematureDetails',
        'birthWeight',
        'birthComplications',
        'afterBirthComplications',
      },
      5: {
        'earlyIllnesses',
        'generalHealth',
        'diagnosis',
        'medications',
        'hospitalised',
        'hospitalisedDetails',
        'hearingTested',
        'hearingTestedDetails',
        'earInfections',
        'earInfectionsDetails',
        'entInvolvement',
        'entInvolvementDetails',
        'visionTested',
        'visionTestedDetails',
      },
      6: {
        'respondsToName',
        'ageFirstWords',
        'ageTwoWordPhrases',
        'attentionListening',
        'sentenceExamples',
        'showsUnderstanding',
      },
      7: {
        'temperament',
        'socialSkills',
        'peerInteraction',
        'favouritePlay',
        'communicationAwareness',
      },
      8: {
        'schoolNameAddress',
        'nurseryDays',
        'senPlan',
        'anythingElse',
        'photoConsent',
        'completedBy',
      },
    };
    for (final entry in stepFields.entries) {
      if (entry.value.contains(fieldKey)) return entry.key;
    }
    return 1;
  }

  /// Field keys rendered on step 1 page 2 (1b): second parent, GP, referral.
  static const Set<String> step1bFieldKeys = {
    'secondParentRelationship',
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
        if (!req(email)) return err('We need your email so your therapist can send you a link to continue', 'email');
        if (!IntakeValidation.isEmail(email)) return err('Please enter a valid email address', 'email');
        if (!req(childName)) return err("We need your child's name to personalise the form", 'childName');
        if (!req(dateOfBirth)) return err("We need your child's date of birth to prepare the assessment", 'dateOfBirth');
        if (!IntakeValidation.isDdMmYyyy(dateOfBirth)) {
          return err('Please use the calendar to pick the date of birth', 'dateOfBirth');
        }
        // ageAtReferral is computed from dateOfBirth — no longer validated here
        if (!req(childAddress)) return err("Your child's address helps us confirm the right service area", 'childAddress');
        if (!req(motherName)) return err("We need a name for the primary contact", 'motherName');
        if (!req(motherMobile)) return err("We need a mobile number so your therapist can reach you", 'motherMobile');
        if (!req(motherEmail)) return err("We need an email address so your therapist can send you updates", 'motherEmail');
        // Second parent fields only required when the section is enabled
        if (fatherDetailsApplicable) {
          if (!req(secondParentRelationship)) {
            return err("Please enter the relationship to the child (e.g. Father, Guardian, Carer)", 'secondParentRelationship');
          }
          if (!req(fatherMobile)) return err("Please add a mobile number for the second parent / guardian", 'fatherMobile');
          if (!req(fatherEmail)) return err("Please add an email address for the second parent / guardian", 'fatherEmail');
        }
        if (!req(gpPractice)) return err("Your GP's details help us coordinate care if needed", 'gpPractice');
        if (!req(gpAddress)) return err("Your GP's address is needed for the referral file", 'gpAddress');
        if (!req(gpPhone)) return err("Your GP's phone number is needed for the referral file", 'gpPhone');
        if (!req(referredBy)) return err('This helps us understand how you found us', 'referredBy');
        if (!req(heardAbout)) return err('This helps us understand how you found us', 'heardAbout');
        return null;
      case 2:
        if (!req(mainConcern)) return err("Please describe your main concern \u2014 this guides the whole assessment", 'mainConcern');
        if (difficulties.isEmpty) {
          return err('Please select at least one area \u2014 this helps the therapist prepare', 'difficulties');
        }
        return null;
      case 3:
        if (!req(assessedByOthers)) return err('Please answer whether your child has been assessed by other professionals', 'assessedByOthers');
        if (assessedByOthers == 'yes' && !req(assessedByOthersDetails)) {
          return err('Please briefly describe the previous professional involvement', 'assessedByOthersDetails');
        }
        if (!req(receivingTherapy)) return err('Please answer whether your child is currently receiving therapy', 'receivingTherapy');
        if (receivingTherapy == 'yes' && !req(therapyDetails)) {
          return err('Please briefly describe the current therapy', 'therapyDetails');
        }
        if (!req(languagesExposed)) return err('Please list the languages your child hears at home or school', 'languagesExposed');
        if (!req(parentLanguages)) return err('Please list the languages spoken by parents or carers', 'parentLanguages');
        if (!req(childLanguages)) return err('Please describe the languages your child uses to communicate', 'childLanguages');
        if (!req(familyHistory)) return err('Please answer the family history question \u2014 this helps the therapist', 'familyHistory');
        if (familyHistory == 'yes' && !req(familyHistoryDetails)) {
          return err('Please briefly describe the family history of speech or language difficulties', 'familyHistoryDetails');
        }
        return null;
      case 4:
        if (!req(pregnancyHealth)) return err("Please describe the mother\u2019s health during pregnancy, or write \u201cno concerns\u201d", 'pregnancyHealth');
        if (!req(prematureDetails)) return err('Please answer the premature birth question, or write \u201cno\u201d if full term', 'prematureDetails');
        if (!req(birthWeight)) return err('Please enter the birth weight, or your best estimate', 'birthWeight');
        if (!req(birthComplications)) {
          return err('Please describe any birth complications, or write \u201cnone\u201d', 'birthComplications');
        }
        if (!req(afterBirthComplications)) {
          return err('Please describe any complications after birth, or write \u201cnone\u201d', 'afterBirthComplications');
        }
        return null;
      case 5:
        if (!req(earlyIllnesses)) return err('Early childhood illnesses (write \u201cnone\u201d if not applicable)', 'earlyIllnesses');
        if (!req(generalHealth)) return err('General health', 'generalHealth');
        if (!req(diagnosis)) return err('Known diagnosis or syndrome (write \u201cnone\u201d if not applicable)', 'diagnosis');
        if (!req(medications)) return err('Regular medications (write \u201cnone\u201d if not applicable)', 'medications');
        if (!req(hospitalised)) return err('Please answer whether your child has been hospitalised', 'hospitalised');
        if (hospitalised == 'yes' && !req(hospitalisedDetails)) {
          return err('Please briefly describe when and why your child was hospitalised', 'hospitalisedDetails');
        }
        if (!req(hearingTested)) return err('Please answer whether your child\u2019s hearing has been tested', 'hearingTested');
        if (hearingTested == 'yes' && !req(hearingTestedDetails)) {
          return err('Please describe when the hearing test was done and the outcome', 'hearingTestedDetails');
        }
        if (!req(earInfections)) return err('Please answer whether your child has had ear infections', 'earInfections');
        if (earInfections == 'yes' && !req(earInfectionsDetails)) {
          return err('Please briefly describe the ear infections', 'earInfectionsDetails');
        }
        if (!req(entInvolvement)) return err('Please answer whether your child has had ENT involvement', 'entInvolvement');
        if (entInvolvement == 'yes' && !req(entInvolvementDetails)) {
          return err('Please briefly describe the ENT involvement', 'entInvolvementDetails');
        }
        if (!req(visionTested)) return err('Please answer whether your child\u2019s eyes have been tested', 'visionTested');
        if (visionTested == 'yes' && !req(visionTestedDetails)) {
          return err('Please add the date and outcome of the vision test', 'visionTestedDetails');
        }
        return null;
      case 6:
        if (!req(respondsToName)) {
          return err('Please answer whether your child responds to their own name', 'respondsToName');
        }
        if (!req(ageFirstWords)) return err('Please enter the age your child said their first words, or your best estimate', 'ageFirstWords');
        if (!req(ageTwoWordPhrases)) {
          return err('Please enter the age your child started joining two words together', 'ageTwoWordPhrases');
        }
        if (!req(attentionListening)) {
          return err('Please describe your child\u2019s attention and listening skills', 'attentionListening');
        }
        if (!req(sentenceExamples)) return err('Please give some examples of sentences your child uses', 'sentenceExamples');
        if (!req(showsUnderstanding)) {
          return err('Please describe how your child shows they understand what is said', 'showsUnderstanding');
        }
        return null;
      case 7:
        final step7 = <(String, String, String)>[
          (temperament, 'temperament', 'Please describe your child\u2019s temperament and personality'),
          (socialSkills, 'socialSkills', 'Please describe your child\u2019s social skills'),
          (peerInteraction, 'peerInteraction', 'Please describe how your child interacts with other children'),
          (favouritePlay, 'favouritePlay', 'Please describe your child\u2019s favourite activities and motivators'),
          (communicationAwareness, 'communicationAwareness', 'Please describe whether your child is aware of their communication difficulties'),
        ];
        for (final f in step7) {
          if (!req(f.$1)) return err(f.$3, f.$2);
        }
        return null;
      case 8:
        if (!req(schoolNameAddress)) {
          return err("Please add your child's school or nursery name and address", 'schoolNameAddress');
        }
        if (!req(senPlan)) return err('Please describe any SEN plan, EHCP, or write "none"', 'senPlan');
        if (!req(photoConsent)) return err('Please answer the photo/film consent question', 'photoConsent');
        if (!req(completedBy)) return err('Please tell us who completed this form', 'completedBy');
        // completionDate is set server-side from submittedAt — no longer validated here
        return null;
      default:
        return null;
    }
  }
}
