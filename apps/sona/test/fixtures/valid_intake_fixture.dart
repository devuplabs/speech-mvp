import 'package:sona/models/intake_form_data.dart';

/// Canonical valid intake used by unit tests and mirrored in e2e/fixtures.
IntakeFormData buildValidIntakeFixture({String childName = 'E2E Test Child'}) {
  final d = IntakeFormData()
    ..email = 'e2e.parent@example.com'
    ..childName = childName
    ..dateOfBirth = '01 / 05 / 2019'
    // ageAtReferral is now a computed getter — not set here
    ..childAddress = '1 Test Lane, London'
    ..motherName = 'E2E Mother'
    ..motherMobile = '07700900001'
    ..motherEmail = 'mother@example.com'
    // fatherDetailsApplicable defaults to false so father fields are optional
    ..fatherDetailsApplicable = true
    ..fatherMobile = '07700900002'
    ..fatherEmail = 'father@example.com'
    ..gpPractice = 'Test GP'
    ..gpAddress = 'GP Street'
    ..gpPhone = '02070000000'
    ..referredBy = 'School'
    ..heardAbout = 'Website'
    ..mainConcern = 'Speech delay E2E automated test concern.'
    ..difficulties.addAll(['Speech sounds', 'Staying on task'])
    ..assessedByOthers = 'no'
    ..receivingTherapy = 'no'
    ..languagesExposed = 'English'
    ..parentLanguages = 'English'
    ..childLanguages = 'English'
    ..familyHistory = 'no'
    ..pregnancyHealth = 'Normal pregnancy'
    ..prematureDetails = 'No'
    ..birthWeight = '3.2kg'
    ..birthComplications = 'None'
    ..afterBirthComplications = 'None'
    ..earlyIllnesses = 'None'
    ..generalHealth = 'Good'
    ..diagnosis = 'None'
    ..medications = 'None'
    ..hospitalised = 'No'
    ..hearingTested = 'Yes normal'
    ..earInfections = 'None'
    ..entInvolvement = 'None'
    ..visionTested = 'Yes normal'
    ..respondsToName = 'yes'
    ..ageFirstWords = '12 months'
    ..ageTwoWordPhrases = '18 months'
    ..attentionListening = 'Variable attention'
    ..sentenceExamples = 'Want juice'
    ..showsUnderstanding = 'Follows directions'
    ..temperament = 'Friendly'
    ..socialSkills = 'Good'
    ..peerInteraction = 'Plays well'
    ..favouritePlay = 'Blocks'
    ..communicationAwareness = 'Some awareness'
    ..schoolNameAddress = 'Test Nursery, London'
    ..senPlan = 'None'
    ..photoConsent = 'no'
    ..completedBy = 'E2E Parent';
    // completionDate is set server-side — not set in client fixture
  return d;
}
