import 'package:sona/config/env.dart';

/// Placeholder for GenUI A2UI → Sona API wiring (ADR-002).
///
/// Next step: configure [A2uiAgentConnector] from `genui_a2a` with `onSend`
/// posting to `${Env.apiBaseUrl}/...` once A2UI routes exist on the API.
class SonaAgentConnectorConfig {
  const SonaAgentConnectorConfig();

  String get apiBaseUrl => Env.apiBaseUrl;
}
