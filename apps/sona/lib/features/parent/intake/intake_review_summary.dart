import 'package:sona/models/intake_form_data.dart';

abstract final class IntakeReviewSummary {
  static String preview(String value, {int max = 80}) {
    final t = value.trim();
    if (t.isEmpty) return '—';
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static List<(String, String)> contactRows(IntakeFormData d) => [
        ('Name', preview(d.childName, max: 40)),
        ('Age', preview(d.ageAtReferral, max: 40)),
        ('Email', preview(d.email, max: 40)),
        ('School', preview(d.schoolNameAddress, max: 40)),
      ];

  static List<(String, String)> referralRows(IntakeFormData d) => [
        ('Main concern', preview(d.mainConcern, max: 60)),
        ('Difficulties', d.difficulties.isEmpty ? '—' : '${d.difficulties.length} selected'),
        ('Therapy', preview(d.receivingTherapy == 'yes' ? d.therapyDetails : 'No current therapy', max: 50)),
        ('Languages', preview(d.childLanguages, max: 50)),
      ];

  static List<(String, String)> healthRows(IntakeFormData d) => [
        ('General health', preview(d.generalHealth, max: 50)),
        ('Diagnosis', preview(d.diagnosis, max: 50)),
        ('Hearing', preview(d.hearingTested, max: 50)),
        ('EHCP / SEN', preview(d.senPlan, max: 50)),
      ];
}
