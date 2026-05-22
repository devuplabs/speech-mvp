import 'package:sona/models/intake_form_data.dart';

abstract final class IntakeReviewSummary {
  static String preview(String value, {int max = 80}) {
    final t = value.trim();
    if (t.isEmpty) return '—';
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _yesNo(String v) =>
      v == 'yes' ? 'Yes' : v == 'no' ? 'No' : preview(v, max: 40);

  // Step 1
  static List<(String, String)> contactRows(IntakeFormData d) => [
        ('Child', preview(d.childName, max: 40)),
        ('Age', preview(d.ageAtReferral, max: 40)),
        ('Email', preview(d.email, max: 40)),
        ('Address', preview(d.childAddress, max: 40)),
        ('Mother', preview(d.motherName, max: 40)),
      ];

  // Step 2
  static List<(String, String)> referralRows(IntakeFormData d) => [
        ('Main concern', preview(d.mainConcern, max: 60)),
        ('Difficulties', d.difficulties.isEmpty ? '—' : '${d.difficulties.length} area${d.difficulties.length == 1 ? '' : 's'} selected'),
        ('Referred by', preview(d.referredBy, max: 40)),
      ];

  // Step 3
  static List<(String, String)> backgroundRows(IntakeFormData d) => [
        ('Other professionals', _yesNo(d.assessedByOthers)),
        ('Current therapy', _yesNo(d.receivingTherapy)),
        ('Languages (child)', preview(d.childLanguages, max: 40)),
        ('Family history', _yesNo(d.familyHistory)),
      ];

  // Step 4
  static List<(String, String)> birthRows(IntakeFormData d) => [
        ('Pregnancy', preview(d.pregnancyHealth, max: 50)),
        ('Birth weight', preview(d.birthWeight, max: 30)),
        ('Complications', preview(d.birthComplications, max: 40)),
      ];

  // Step 5
  static List<(String, String)> healthRows(IntakeFormData d) => [
        ('General health', preview(d.generalHealth, max: 50)),
        ('Diagnosis', preview(d.diagnosis, max: 50)),
        ('Hearing', preview(d.hearingTested, max: 50)),
        ('Vision', preview(d.visionTested, max: 50)),
      ];

  // Step 6
  static List<(String, String)> milestoneRows(IntakeFormData d) => [
        ('Responds to name', _yesNo(d.respondsToName)),
        ('First words', preview(d.ageFirstWords, max: 30)),
        ('Two-word phrases', preview(d.ageTwoWordPhrases, max: 30)),
        ('Understanding', preview(d.showsUnderstanding, max: 50)),
      ];

  // Step 7
  static List<(String, String)> temperamentRows(IntakeFormData d) => [
        ('Temperament', preview(d.temperament, max: 50)),
        ('Social skills', preview(d.socialSkills, max: 50)),
        ('Favourite play', preview(d.favouritePlay, max: 50)),
      ];

  // Step 8
  static List<(String, String)> schoolRows(IntakeFormData d) => [
        ('School / nursery', preview(d.schoolNameAddress, max: 50)),
        ('EHCP / SEN', preview(d.senPlan, max: 50)),
        ('Photo consent', _yesNo(d.photoConsent)),
        ('Completed by', preview(d.completedBy, max: 40)),
      ];
}
