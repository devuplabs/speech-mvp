import 'package:flutter/material.dart';
import 'package:sona/genui/sona_agent_connector.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            const Text(
              'GenUI A2UI connector will attach here once API streaming routes are ready.',
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('Start intake (coming soon)'),
            ),
          ],
        ),
      ),
    );
  }
}
