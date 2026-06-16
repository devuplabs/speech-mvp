import 'package:flutter_test/flutter_test.dart';
import 'package:sona/utils/case_status.dart';

void main() {
  group('clinicianCaseLoadSummary (DEV-76)', () {
    test('footer reconciles active vs awaiting-intake cases', () {
      final statuses = <String?>[
        'intake_pending', 'intake_pending', // awaiting (hidden)
        'prep_ready', 'triaged', 'triaged', // active
        'summary_sent', 'carryover', // active
      ];
      // 5 active shown on the dashboard, 2 awaiting parent intake.
      expect(clinicianCaseLoadSummary(statuses), '5 active · 2 awaiting intake');
    });

    test('drops the breakdown when nothing is awaiting intake', () {
      expect(clinicianCaseLoadSummary(['prep_ready', 'triaged']), '2 case(s) loaded');
    });

    test('active count matches showCaseOnTodayDashboard', () {
      final statuses = <String?>['intake_pending', 'prep_ready', null];
      final active = statuses.where(showCaseOnTodayDashboard).length;
      expect(clinicianCaseLoadSummary(statuses), '$active active · 2 awaiting intake');
    });
  });

  group('prepLabelFromCaseStatus', () {
    test('labels the consult-booked stage (DEV-10)', () {
      expect(prepLabelFromCaseStatus('consult_booked'), 'Consult booked');
    });

    test('labels the carryover stage (DEV-10)', () {
      expect(prepLabelFromCaseStatus('carryover'), 'Carryover');
    });

    test('keeps existing labels intact', () {
      expect(prepLabelFromCaseStatus('prep_ready'), 'Ready');
      expect(prepLabelFromCaseStatus('triaged'), 'Triaged');
      expect(prepLabelFromCaseStatus('summary_sent'), 'Ready');
      expect(prepLabelFromCaseStatus('intake_pending'), 'Not started');
      expect(prepLabelFromCaseStatus(null), 'Not started');
    });
  });

  group('showCaseOnTodayDashboard', () {
    test('shows consult-booked and carryover cases', () {
      expect(showCaseOnTodayDashboard('consult_booked'), isTrue);
      expect(showCaseOnTodayDashboard('carryover'), isTrue);
    });

    test('still hides intake_pending and null', () {
      expect(showCaseOnTodayDashboard('intake_pending'), isFalse);
      expect(showCaseOnTodayDashboard(null), isFalse);
    });
  });

  group('isSummarySent', () {
    test('true for summary_sent and carryover (summary stays published)', () {
      expect(isSummarySent('summary_sent'), isTrue);
      expect(isSummarySent('carryover'), isTrue);
    });

    test('false before the summary is published', () {
      expect(isSummarySent('consult_booked'), isFalse);
      expect(isSummarySent('triaged'), isFalse);
      expect(isSummarySent(null), isFalse);
    });
  });

  group('kpiBucketFor', () {
    test('consult_booked counts as in progress', () {
      expect(kpiBucketFor('consult_booked'), KpiBucket.inProgress);
    });

    test('carryover counts as summary sent', () {
      expect(kpiBucketFor('carryover'), KpiBucket.summarySent);
    });

    test('existing buckets are unchanged', () {
      expect(kpiBucketFor('intake_submitted'), KpiBucket.newIntake);
      expect(kpiBucketFor('prep_ready'), KpiBucket.inProgress);
      expect(kpiBucketFor('triaged'), KpiBucket.inProgress);
      expect(kpiBucketFor('summary_sent'), KpiBucket.summarySent);
    });
  });
}
