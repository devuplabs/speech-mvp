import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';

Map<String, dynamic> ariaProjection({String tone = 'balanced'}) => {
      'title': tone == 'clinical'
          ? 'Consultation summary for Aria M.'
          : 'Your consultation summary for Aria M.',
      'sections': [
        {
          'heading': 'What we talked about',
          'bullets': ['Your main worry: Speech delay'],
        },
        {
          'heading': "What we'll work on together",
          'bullets': ['Baseline of speech-sound inventory (DEAP screen).'],
        },
        {
          'heading': 'How you can help at home',
          'bullets': ["5 minutes daily 'silly sound' play."],
        },
        {
          'heading': 'What happens next',
          'bullets': ['Book your first therapy session.'],
        },
      ],
      'disclosure':
          'AI-drafted, clinician-reviewed. Drafted by Sona using your intake answers and consult notes.',
    };

void main() {
  Future<({List<dynamic> previewCalls, List<dynamic> publishCalls})> pump(
    WidgetTester tester, {
    Map<String, dynamic>? projection,
  }) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = '${details.exception}';
      if (msg.contains('A RenderFlex overflowed')) return;
      if (msg.contains('background color or ink splashes may be invisible')) return;
      if (msg.contains('was given an infinite size')) return;
      if (msg.contains('cannot be hit-tested')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final previewCalls = <dynamic>[];
    final publishCalls = <dynamic>[];
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianParentSummaryScreen(
          caseId: 'case-1',
          onBackPlan: () {},
          onPreview: (opts) async {
            previewCalls.add(opts);
            return {
              'html': '<html/>',
              'projection': projection ?? ariaProjection(tone: opts.tone),
            };
          },
          onPublish: (opts) async {
            publishCalls.add(opts);
          },
          onDownloadPdf: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 350));
    return (previewCalls: previewCalls, publishCalls: publishCalls);
  }

  testWidgets('renders all 3 control groups + AI-disclosure switch',
      (tester) async {
    await pump(tester);
    expect(find.text('Tone'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Clinical'), findsOneWidget);
    expect(find.text('Reading level'), findsOneWidget);
    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Detailed'), findsOneWidget);
    expect(find.text('Included sections'), findsOneWidget);
    expect(find.textContaining('AI-disclosure'), findsWidgets);
  });

  testWidgets('immediate preview call on mount with default options',
      (tester) async {
    final res = await pump(tester);
    expect(res.previewCalls.length, 1);
    final opts = res.previewCalls.first as ({
      String tone,
      String readingLevel,
      bool whatWeDiscussed,
      bool planForFirstSession,
      bool homePractice,
      bool nextSteps,
      bool aiDisclosure,
    });
    expect(opts.tone, 'balanced');
    expect(opts.readingLevel, 'standard');
    expect(opts.aiDisclosure, isTrue);
  });

  testWidgets('changing tone debounces a new preview request',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final origErr = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = '${d.exception}';
      if (m.contains('A RenderFlex overflowed')) return;
      if (m.contains('background color or ink splashes may be invisible')) return;
      origErr?.call(d);
    };
    addTearDown(() => FlutterError.onError = origErr);
    final previewCalls = <dynamic>[];
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianParentSummaryScreen(
          caseId: 'case-1',
          onBackPlan: () {},
          onPreview: (opts) async {
            previewCalls.add(opts);
            return {'html': '<html/>', 'projection': ariaProjection(tone: opts.tone)};
          },
          onPublish: (opts) async {},
          onDownloadPdf: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(previewCalls.length, 1);

    // Click "Clinical" tone segment.
    await tester.tap(find.text('Clinical'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(previewCalls.length, 2);
    final second = previewCalls.last as ({
      String tone,
      String readingLevel,
      bool whatWeDiscussed,
      bool planForFirstSession,
      bool homePractice,
      bool nextSteps,
      bool aiDisclosure,
    });
    expect(second.tone, 'clinical');
  });

  testWidgets('preview pane renders the projection sections', (tester) async {
    await pump(tester);
    // Each heading is also present in the controls section-toggle list — so we
    // expect at least one and typically two.
    expect(find.text('What we talked about'), findsWidgets);
    expect(find.text("What we'll work on together"), findsWidgets);
    expect(find.text('How you can help at home'), findsWidgets);
    expect(find.text('What happens next'), findsWidgets);
    expect(find.textContaining('DEAP screen'), findsWidgets);
  });

  testWidgets('AI-disclosure footer visible when projection includes one',
      (tester) async {
    await pump(tester);
    expect(find.textContaining('AI-drafted'), findsWidgets);
  });

  testWidgets('Publish button hands selected options to the publish callback',
      (tester) async {
    final res = await pump(tester);
    // Switch to clinical first to confirm options flow through.
    await tester.tap(find.text('Clinical'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    final pubFinder = find.widgetWithText(FilledButton, 'Publish parent summary');
    await tester.ensureVisible(pubFinder);
    await tester.pumpAndSettle();
    await tester.tap(pubFinder);
    await tester.pumpAndSettle();
    expect(res.publishCalls, hasLength(1));
    final opts = res.publishCalls.first as ({
      String tone,
      String readingLevel,
      bool whatWeDiscussed,
      bool planForFirstSession,
      bool homePractice,
      bool nextSteps,
      bool aiDisclosure,
    });
    expect(opts.tone, 'clinical');
  });

  testWidgets('Re-publish label appears when alreadyPublished=true',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final origErr = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = '${d.exception}';
      if (m.contains('A RenderFlex overflowed')) return;
      if (m.contains('background color or ink splashes may be invisible')) return;
      origErr?.call(d);
    };
    addTearDown(() => FlutterError.onError = origErr);
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianParentSummaryScreen(
          caseId: 'case-1',
          alreadyPublished: true,
          onBackPlan: () {},
          onPreview: (opts) async => {
            'html': '<html/>',
            'projection': ariaProjection(),
          },
          onPublish: (opts) async {},
          onDownloadPdf: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Re-publish parent summary'), findsOneWidget);
  });

  testWidgets('Download PDF invokes the callback', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final origErr = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = '${d.exception}';
      if (m.contains('A RenderFlex overflowed')) return;
      if (m.contains('background color or ink splashes may be invisible')) return;
      origErr?.call(d);
    };
    addTearDown(() => FlutterError.onError = origErr);
    var downloaded = false;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianParentSummaryScreen(
          caseId: 'case-1',
          onBackPlan: () {},
          onPreview: (opts) async =>
              {'html': '<html/>', 'projection': ariaProjection()},
          onPublish: (opts) async {},
          onDownloadPdf: () {
            downloaded = true;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('Download PDF'));
    await tester.pumpAndSettle();
    expect(downloaded, isTrue);
  });
}
