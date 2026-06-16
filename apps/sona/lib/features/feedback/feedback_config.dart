/// Build-time gating for the in-app tester feedback widget (DEV-55).
///
/// The widget is OFF by default so it is invisible to real end users. A UAT
/// build opts in explicitly:
///
///   flutter build web \
///     --dart-define=SONA_FEEDBACK=true \
///     --dart-define=SONA_ENV=dev \
///     --dart-define=SONA_BUILD_SHA=$(git rev-parse --short HEAD)
///
/// Fail-closed: even if SONA_FEEDBACK were somehow true, the widget stays hidden
/// when the build env is production — so a feedback affordance can never ship in
/// a prod web build (mirrors the API-side "absent in prod" guarantee, DEV-45).
library;

/// Master opt-in. False unless a build explicitly enables it.
const bool kFeedbackFlag = bool.fromEnvironment(
  'SONA_FEEDBACK',
  defaultValue: false,
);

/// Deployment label, attached to each submission (and used to fail closed).
const String kFeedbackEnv = String.fromEnvironment(
  'SONA_ENV',
  defaultValue: 'dev',
);

/// Short build SHA, attached so feedback can be tied back to an exact build.
const String kFeedbackBuildSha = String.fromEnvironment(
  'SONA_BUILD_SHA',
  defaultValue: 'unknown',
);

/// Whether the feedback widget should render. Enabled only when explicitly
/// opted in AND the build is not a production build.
bool get feedbackWidgetEnabled =>
    kFeedbackFlag && kFeedbackEnv != 'prod' && kFeedbackEnv != 'production';
