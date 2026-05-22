/// Synthetic intake personas — the single Dart source of truth, mirrored in
/// `e2e/fixtures/intake-personas.ts` and `scripts/personas/*.json`.
///
/// Use these in:
///   - Widget + integration tests (deterministic full-flow drivers).
///   - The dev-only "Fill with sample data" button on parent welcome.
///   - The seeding script (`scripts/seed-dev.ts`).
///
/// **Synthetic only.** Never replaced with real client data; sample names,
/// emails, addresses are fictional and may not match any real person. PHI
/// guardrails (see docs/mvp-brief.md + .cursor/rules/mvp-security-reminder.mdc)
/// still apply: nothing here ships in logs, emails, or third-party tooling.
library;

import 'package:sona/models/intake_form_data.dart';

/// One named persona, fully populated for all 8 intake steps.
class IntakePersona {
  const IntakePersona({
    required this.id,
    required this.label,
    required this.summary,
    required this.childDisplayName,
    required this.parentEmail,
    required this.answers,
  });

  /// Stable identifier (snake_case) — used as the persona key in JSON, TS, and
  /// the dev-only Fill-sample affordance.
  final String id;

  /// Short human-facing label (e.g. "4yo speech-sound delay").
  final String label;

  /// One-line clinical summary for the persona picker.
  final String summary;

  /// Display name written to `cases.child_display_name`.
  final String childDisplayName;

  /// Parent email written to `cases.parent_email`.
  final String parentEmail;

  /// Flat JSON answers, matching the keys of [IntakeFormData.toJson].
  /// Three consent flags + `formStep` are added at submit time by the caller.
  final Map<String, dynamic> answers;

  /// Hydrate an [IntakeFormData] from this persona — used by the dev-only
  /// "Fill sample" button on parent welcome and by widget / integration tests.
  IntakeFormData toFormData() => IntakeFormData.fromJson(answers);
}

/// Stable ordering: the persona picker renders these in this order.
const List<IntakePersona> intakePersonas = [
  IntakePersona(
    id: 'aria_speech_sounds_4yo',
    label: '4yo speech-sound delay (Aria)',
    summary:
        'Mild speech-sound disorder with mild attention concerns. Fits the "Speech sounds + Staying on task" core MVP demo.',
    childDisplayName: 'Aria M.',
    parentEmail: 'anna.m@example.com',
    answers: _ariaAnswers,
  ),
  IntakePersona(
    id: 'jaden_stutter_7yo',
    label: '7yo stutter with EHCP (Jaden)',
    summary:
        'Stutter onset around age 4. School flagged fluency at the EHCP review; family history of stuttering on paternal side.',
    childDisplayName: 'Jaden O.',
    parentEmail: 'lisa.o@example.com',
    answers: _jadenAnswers,
  ),
  IntakePersona(
    id: 'mia_social_comm_11yo',
    label: '11yo social communication (Mia)',
    summary:
        'Social-communication concerns at secondary transition. Awaiting ADOS; OT input in place.',
    childDisplayName: 'Mia R.',
    parentEmail: 'jordan.r@example.com',
    answers: _miaAnswers,
  ),
  IntakePersona(
    id: 'theo_feeding_3yo',
    label: '3yo fussy eater + sensory (Theo)',
    summary:
        'Feeding concerns + sensory aversions. Pediatrician saw, dentist seen, OT review pending.',
    childDisplayName: 'Theo K.',
    parentEmail: 'sam.k@example.com',
    answers: _theoAnswers,
  ),
];

IntakePersona personaById(String id) =>
    intakePersonas.firstWhere((p) => p.id == id);

/// ---- Persona answer maps --------------------------------------------------
///
/// Each map is a snapshot of `IntakeFormData.toJson()` for that persona.
/// Keys MUST stay aligned with the Dart model; the TS + JSON mirrors are
/// asserted in `e2e/tests/personas-parity.spec.ts`.

const Map<String, dynamic> _ariaAnswers = {
  'version': 1,
  'email': 'anna.m@example.com',
  'childName': 'Aria M.',
  'dateOfBirth': '15 / 03 / 2022',
  'childAddress': '12 Linden Grove, London NW3 2EE',
  'motherName': 'Anna M.',
  'motherAddress': '12 Linden Grove, London NW3 2EE',
  'motherMobile': '07700900101',
  'motherEmail': 'anna.m@example.com',
    'fatherDetailsApplicable': true,
  'fatherName': 'David M.',
  'fatherAddress': '12 Linden Grove, London NW3 2EE',
  'fatherMobile': '07700900102',
  'fatherEmail': 'david.m@example.com',
  'gpPractice': 'Hampstead Health Centre',
  'gpAddress': '101 High Street, London NW3 1QA',
  'gpPhone': '02074321000',
  'referredBy': 'Nursery SENCO',
  'heardAbout': 'Google search',
  'mainConcern':
      'Hard to understand at nursery — drops final consonants and some sounds replaced. Some attention drift in 1:1 play.',
  'difficulties': ['Speech sounds', 'Staying on task'],
  'assessedByOthers': 'no',
  'assessedByOthersDetails': '',
  'receivingTherapy': 'no',
  'therapyDetails': '',
  'languagesExposed': 'English',
  'parentLanguages': 'English',
  'childLanguages': 'English',
  'familyHistory': 'no',
  'familyHistoryDetails': '',
  'pregnancyHealth': 'Healthy pregnancy, no complications',
  'prematureDetails': 'Born at 39+4, not premature',
  'birthWeight': '3.4 kg',
  'birthComplications': 'None',
  'afterBirthComplications': 'None',
  'earlyIllnesses': 'Two ear infections at 18 and 22 months — resolved',
  'generalHealth': 'Good',
  'diagnosis': 'None',
  'medications': 'None',
  'hospitalised': 'No',
  'hearingTested': 'Yes — newborn screen normal; recheck age 3 normal',
  'earInfections': 'Two; resolved with antibiotics',
  'entInvolvement': 'None',
  'visionTested': 'Yes — last optician visit normal',
  'respondsToName': 'yes',
  'ageFirstWords': '11 months',
  'ageTwoWordPhrases': '20 months',
  'attentionListening': 'Variable; better in 1:1 than group',
  'sentenceExamples': '"Daddy go work", "Aria want milk"',
  'showsUnderstanding': 'Follows 2-step instructions',
  'temperament': 'Bright, sociable, can get frustrated when not understood',
  'socialSkills': 'Good — initiates play, takes turns',
  'peerInteraction': 'Plays well with familiar peers',
  'favouritePlay': 'Pretend tea sets, picture books',
  'communicationAwareness': 'Aware she is hard to understand; repeats herself',
  'schoolNameAddress': 'Linden Nursery, 8 Linden Grove, London NW3',
  'nurseryDays': 'Mon-Fri 9-3',
  'senPlan': 'No EHCP; on SENCO monitor',
  'anythingElse': 'Parents would like home-practice ideas',
  'photoConsent': 'no',
  'completedBy': 'Anna M. (mother)',
};

const Map<String, dynamic> _jadenAnswers = {
  'version': 1,
  'email': 'lisa.o@example.com',
  'childName': 'Jaden O.',
  'dateOfBirth': '02 / 09 / 2018',
  'childAddress': '22 Park Crescent, Leeds LS8 1AB',
  'motherName': 'Lisa O.',
  'motherAddress': '22 Park Crescent, Leeds LS8 1AB',
  'motherMobile': '07700900201',
  'motherEmail': 'lisa.o@example.com',
    'fatherDetailsApplicable': true,
  'fatherName': 'Mike O.',
  'fatherAddress': '22 Park Crescent, Leeds LS8 1AB',
  'fatherMobile': '07700900202',
  'fatherEmail': 'mike.o@example.com',
  'gpPractice': 'Roundhay Park Medical',
  'gpAddress': '5 Park View, Leeds LS8 2BC',
  'gpPhone': '01134560000',
  'referredBy': 'School SENCO',
  'heardAbout': 'ASLTIP directory',
  'mainConcern':
      'Stuttering since age 4. Worse in class presentations. EHCP review flagged fluency. Confidence dropping.',
  'difficulties': [
    'Expressing ideas clearly',
    'Sitting or standing still',
    'Staying on topic of conversation',
  ],
  'assessedByOthers': 'yes',
  'assessedByOthersDetails':
      'School Ed Psych report 2025; mild attention concerns noted, no diagnosis.',
  'receivingTherapy': 'no',
  'therapyDetails': '',
  'languagesExposed': 'English, occasional Yoruba',
  'parentLanguages': 'English, Yoruba',
  'childLanguages': 'English (primary)',
  'familyHistory': 'yes',
  'familyHistoryDetails': 'Paternal uncle stutters; resolved in adulthood',
  'pregnancyHealth': 'Healthy, no complications',
  'prematureDetails': 'Born at 38 weeks',
  'birthWeight': '3.1 kg',
  'birthComplications': 'None',
  'afterBirthComplications': 'Mild jaundice, resolved',
  'earlyIllnesses': 'Standard childhood; no significant illnesses',
  'generalHealth': 'Good',
  'diagnosis': 'None formal',
  'medications': 'None',
  'hospitalised': 'No',
  'hearingTested': 'Yes — last test age 5, normal',
  'earInfections': 'One at age 3',
  'entInvolvement': 'None',
  'visionTested': 'Yes — wears glasses for short-sightedness',
  'respondsToName': 'yes',
  'ageFirstWords': '13 months',
  'ageTwoWordPhrases': '22 months',
  'attentionListening': 'Variable; can lose focus in group',
  'sentenceExamples':
      'Complex sentences with frequent repetitions on initial sounds',
  'showsUnderstanding': 'Strong receptive language',
  'temperament': 'Sensitive, articulate, becoming self-conscious',
  'socialSkills': 'Good with familiar peers; quieter in groups',
  'peerInteraction': 'Plays football; one close friend at school',
  'favouritePlay': 'Lego, football, drawing',
  'communicationAwareness':
      'Highly aware of stutter; sometimes avoids speaking up',
  'schoolNameAddress': 'Roundhay Primary, Leeds LS8',
  'nurseryDays': 'School Mon-Fri 8:50-3:15',
  'senPlan': 'EHCP under annual review — fluency added at last review',
  'anythingElse': 'Parents want strategies before secondary transition',
  'photoConsent': 'no',
  'completedBy': 'Lisa O. (mother)',
};

const Map<String, dynamic> _miaAnswers = {
  'version': 1,
  'email': 'jordan.r@example.com',
  'childName': 'Mia R.',
  'dateOfBirth': '11 / 11 / 2014',
  'childAddress': '7 Beechwood Avenue, Bristol BS7 9PL',
  'motherName': 'Jordan R.',
  'motherAddress': '7 Beechwood Avenue, Bristol BS7 9PL',
  'motherMobile': '07700900301',
  'motherEmail': 'jordan.r@example.com',
    'fatherDetailsApplicable': true,
  'fatherName': 'Sam R.',
  'fatherAddress': '7 Beechwood Avenue, Bristol BS7 9PL',
  'fatherMobile': '07700900302',
  'fatherEmail': 'sam.r@example.com',
  'gpPractice': 'Beechwood Surgery',
  'gpAddress': '14 Beechwood Road, Bristol BS7 9QQ',
  'gpPhone': '01179000000',
  'referredBy': 'Parent self-referral',
  'heardAbout': 'Instagram parent group',
  'mainConcern':
      'Worried about social communication ahead of secondary school transition. Difficulty with conversation flow and reading social cues.',
  'difficulties': [
    'Maintaining eye contact',
    'Turn taking',
    'Staying on topic of conversation',
    'Reading between the lines',
  ],
  'assessedByOthers': 'yes',
  'assessedByOthersDetails':
      'OT assessment 2025; awaiting ADOS-2 NHS appointment.',
  'receivingTherapy': 'yes',
  'therapyDetails': 'Weekly OT for sensory regulation',
  'languagesExposed': 'English',
  'parentLanguages': 'English',
  'childLanguages': 'English',
  'familyHistory': 'no',
  'familyHistoryDetails': '',
  'pregnancyHealth': 'Anxiety during pregnancy; managed without medication',
  'prematureDetails': 'Born at 40+1',
  'birthWeight': '3.6 kg',
  'birthComplications': 'None',
  'afterBirthComplications': 'None',
  'earlyIllnesses': 'Glue ear at age 4, grommets fitted',
  'generalHealth': 'Good',
  'diagnosis': 'Sensory processing differences (OT report)',
  'medications': 'None',
  'hospitalised': 'Day case for grommets, age 4',
  'hearingTested': 'Yes — post-grommets, normal range',
  'earInfections': 'Recurrent age 2-4; resolved after grommets',
  'entInvolvement': 'Grommets age 4, discharged',
  'visionTested': 'Yes — normal',
  'respondsToName': 'yes',
  'ageFirstWords': '14 months',
  'ageTwoWordPhrases': '24 months',
  'attentionListening': 'Strong on preferred topics; weaker on novel topics',
  'sentenceExamples': 'Complex narratives; sometimes off-topic',
  'showsUnderstanding': 'Literal interpretation; misses sarcasm/idiom',
  'temperament': 'Thoughtful, kind, can be anxious in new situations',
  'socialSkills': 'One-to-one strong; group dynamics challenging',
  'peerInteraction':
      'Small friend group; prefers shared-interest play (Pokemon)',
  'favouritePlay': 'Reading, Pokemon cards, drawing manga',
  'communicationAwareness':
      'Increasingly aware of differences with peers; some worry',
  'schoolNameAddress': 'Beechwood Primary, Bristol BS7',
  'nurseryDays': 'School Mon-Fri 8:45-3:15',
  'senPlan': 'No EHCP; SEN support plan in place',
  'anythingElse': 'Family preparing for secondary transition in September',
  'photoConsent': 'no',
  'completedBy': 'Jordan R. (parent)',
};

const Map<String, dynamic> _theoAnswers = {
  'version': 1,
  'email': 'sam.k@example.com',
  'childName': 'Theo K.',
  'dateOfBirth': '08 / 06 / 2023',
  'childAddress': '3 Maple Close, Manchester M21 9LH',
  'motherName': 'Sam K.',
  'motherAddress': '3 Maple Close, Manchester M21 9LH',
  'motherMobile': '07700900401',
  'motherEmail': 'sam.k@example.com',
    'fatherDetailsApplicable': true,
  'fatherName': 'Alex K.',
  'fatherAddress': '3 Maple Close, Manchester M21 9LH',
  'fatherMobile': '07700900402',
  'fatherEmail': 'alex.k@example.com',
  'gpPractice': 'Maple Family Practice',
  'gpAddress': '40 Maple Way, Manchester M21 9LJ',
  'gpPhone': '01612340000',
  'referredBy': 'Health visitor',
  'heardAbout': 'NHS health visitor referral',
  'mainConcern':
      'Very limited food range (around 8 accepted items). Refuses mixed textures. Mealtimes stressful for the whole family.',
  'difficulties': [
    'Overly sensitive to sounds/noises',
    'Following directions/instructions',
  ],
  'assessedByOthers': 'yes',
  'assessedByOthersDetails':
      'Pediatrician saw March 2026 — no medical cause for food refusal. OT review pending.',
  'receivingTherapy': 'no',
  'therapyDetails': '',
  'languagesExposed': 'English',
  'parentLanguages': 'English',
  'childLanguages': 'English',
  'familyHistory': 'no',
  'familyHistoryDetails': '',
  'pregnancyHealth': 'Healthy',
  'prematureDetails': 'Born at 37+2',
  'birthWeight': '2.9 kg',
  'birthComplications': 'None',
  'afterBirthComplications': 'Slow weight gain in first 8 weeks',
  'earlyIllnesses': 'Reflux first 6 months, resolved',
  'generalHealth': 'Good; growth on 25th centile',
  'diagnosis': 'None',
  'medications': 'None',
  'hospitalised': 'No',
  'hearingTested': 'Yes — newborn screen normal',
  'earInfections': 'One',
  'entInvolvement': 'None',
  'visionTested': 'No',
  'respondsToName': 'yes',
  'ageFirstWords': '13 months',
  'ageTwoWordPhrases': '24 months',
  'attentionListening': 'Short; easily over-stimulated',
  'sentenceExamples': '"Theo no like", "Want chips"',
  'showsUnderstanding': 'Follows simple 1-step instructions',
  'temperament': 'Sensitive, cautious with new experiences',
  'socialSkills': 'Parallel play; warming up to nursery peers',
  'peerInteraction': 'Tentative; prefers solo play',
  'favouritePlay': 'Water play, soft brushes, sand',
  'communicationAwareness': 'Limited; communicates needs but rarely repeats',
  'schoolNameAddress': 'Maple Tots Nursery, Manchester M21',
  'nurseryDays': 'Tue + Thu 9-1',
  'senPlan': 'None',
  'anythingElse':
      'Parents would like joined-up plan with OT and feeding strategies for home',
  'photoConsent': 'no',
  'completedBy': 'Sam K. (parent)',
};
