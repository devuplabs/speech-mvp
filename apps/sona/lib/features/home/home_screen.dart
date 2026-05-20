import 'package:flutter/material.dart';
import 'package:sona/config/env.dart';
import 'package:sona/genui/sona_agent_connector.dart';
import 'package:sona/services/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = SonaApiClient();
  String? _statusMessage;
  bool _busy = false;

  Future<void> _checkHealth() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final body = await _api.health();
      setState(() {
        _statusMessage =
            'API OK — mode=${body['mode']}, database=${body['database']}';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Health check failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runIntakeSmoke() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final tenant = await _api.createTenant('MVP smoke tenant');
      final tenantId = tenant['id'] as String;
      final caseRow = await _api.createCase(
        tenantId: tenantId,
        childDisplayName: 'Smoke child',
        parentEmail: 'parent@example.com',
      );
      final caseId = caseRow['id'] as String;
      await _api.submitIntake(
        caseId,
        answers: {
          'concerns': ['speech_delay'],
          'age_months': 36,
        },
      );
      final detail = await _api.getCase(caseId);
      final caseStatus =
          (detail['case'] as Map<String, dynamic>?)?['status'] ?? 'unknown';
      setState(() {
        _statusMessage = 'Intake submitted — case status: $caseStatus';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Intake smoke failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const connector = SonaAgentConnectorConfig();

    return Scaffold(
      appBar: AppBar(title: const Text('Sona')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sona client (parent + clinician)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('API: ${connector.apiBaseUrl}'),
            const SizedBox(height: 8),
            Text(
              Env.apiBaseUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _checkHealth,
              child: const Text('Check API health'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _runIntakeSmoke,
              child: const Text('Run intake smoke test'),
            ),
          ],
        ),
      ),
    );
  }
}
