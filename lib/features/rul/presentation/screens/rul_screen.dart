import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';

import '../../domain/models/rul_assessment.dart';
import '../providers/rul_provider.dart';

class RULScreen extends ConsumerWidget {
  const RULScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charger = ref.watch(selectedChargerProvider);
    final result = ref.watch(rulAssessmentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Remaining Useful Life')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (charger == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.ev_station_outlined),
                  title: const Text('No charger selected'),
                  subtitle: const Text(
                    'Select a charger before checking RUL readiness.',
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.ev_station_outlined),
                  title: Text(
                    _chargerName(
                      charger.manufacturer,
                      charger.model,
                      charger.type,
                    ),
                  ),
                  subtitle: Text(
                    charger.serialNumber ??
                        charger.rawQrIdentifier ??
                        'Unique charger identifier unavailable',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            result.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Checking RUL data readiness...'),
                    ],
                  ),
                ),
              ),
              error: (error, stack) => _unavailableCard(
                theme,
                title: 'RUL assessment error',
                reason: 'The RUL readiness check could not be completed.',
              ),
              data: (assessment) => _assessmentCard(theme, assessment),
            ),
            if (charger == null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan charger'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/ai-recognition'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Use AI recognition'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assessmentCard(ThemeData theme, RulAssessment assessment) {
    if (assessment.status != RulAssessmentStatus.available ||
        !assessment.hasRulValue) {
      final title = assessment.status == RulAssessmentStatus.error
          ? 'RUL assessment error'
          : 'RUL unavailable - insufficient real operational data';
      return _unavailableCard(theme, title: title, reason: assessment.reason);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining useful life', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${assessment.remainingUsefulLife} ${assessment.unit}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(assessment.reason),
            if (assessment.componentId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Component: ${assessment.componentDisplayName ?? assessment.componentId} (${assessment.componentId})',
              ),
            ],
            if (assessment.assessedAt != null)
              Text('Assessed: ${assessment.assessedAt!.toLocal()}'),
            if (assessment.horizonStart != null)
              Text('Horizon starts: ${assessment.horizonStart!.toLocal()}'),
            if (assessment.horizonEnd != null)
              Text('Horizon ends: ${assessment.horizonEnd!.toLocal()}'),
            if (assessment.modelName != null)
              Text('Model: ${assessment.modelName}'),
            if (assessment.modelVersion != null)
              Text('Model version: ${assessment.modelVersion}'),
            if (assessment.confidence != null)
              Text('Backend confidence: ${assessment.confidence}'),
          ],
        ),
      ),
    );
  }

  Widget _unavailableCard(
    ThemeData theme, {
    required String title,
    required String reason,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(reason),
          const SizedBox(height: 16),
          Text(
            'A real assessment requires timestamped operational history, degradation measurements, charger/component association, and a validated prediction service.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  String _chargerName(String? manufacturer, String? model, String? type) {
    final values = [
      manufacturer,
      model,
      type,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return values.isEmpty ? 'Selected charger' : values.join(' ');
  }
}
