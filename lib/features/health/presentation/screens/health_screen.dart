import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';

import '../../domain/models/health_assessment.dart';
import '../providers/health_assessment_provider.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charger = ref.watch(selectedChargerProvider);
    final assessment = ref.watch(healthAssessmentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Charger Health Assessment')),
      body: SafeArea(
        child: charger == null
            ? _noCharger(context, theme)
            : assessment.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Assessing available inspection data…'),
                    ],
                  ),
                ),
                error: (error, stack) => _error(context, theme),
                data: (result) => _assessment(context, theme, result),
              ),
      ),
    );
  }

  Widget _noCharger(BuildContext context, ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ev_station_outlined, size: 56),
          const SizedBox(height: 12),
          Text('No charger selected', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Identify a charger before viewing its health assessment.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan charger'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/ai-recognition'),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Use AI recognition'),
          ),
        ],
      ),
    ),
  );

  Widget _error(BuildContext context, ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 12),
          Text('Health assessment error', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('The available health information could not be assessed.'),
        ],
      ),
    ),
  );

  Widget _assessment(
    BuildContext context,
    ThemeData theme,
    HealthAssessment assessment,
  ) {
    final color = switch (assessment.status) {
      ChargerHealthStatus.healthy => Colors.green,
      ChargerHealthStatus.warning => Colors.orange,
      ChargerHealthStatus.critical => theme.colorScheme.error,
      ChargerHealthStatus.unavailable => theme.colorScheme.onSurfaceVariant,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.ev_station_outlined),
            title: Text(assessment.chargerName),
            subtitle: Text(
              assessment.chargerIdentifier == null
                  ? 'Charger identifier unavailable'
                  : 'ID: ${assessment.chargerIdentifier}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current health', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _statusIcon(assessment.status),
                      color: color,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        assessment.statusLabel,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(assessment.reason),
                if (assessment.sourceTimestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Source timestamp: ${assessment.sourceTimestamp!.toLocal()}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (assessment.inspectedComponent != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_input_component),
              title: Text(assessment.inspectedComponent!.displayName),
              subtitle: Text(
                'Inspected component ${assessment.inspectedComponent!.componentId}',
              ),
            ),
          ),
        ],
        if (assessment.faults.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Detected faults', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...assessment.faults.map(
            (fault) => Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: color),
                title: Text(fault.faultType),
                subtitle: Text(
                  [
                    if (fault.componentDisplayName != null)
                      fault.componentDisplayName!,
                    'Component ${fault.componentId}',
                    if (fault.severity != null) 'Severity ${fault.severity}',
                    if (fault.locationDescription != null &&
                        fault.locationDescription!.isNotEmpty)
                      fault.locationDescription!,
                  ].join(' • '),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/digital-twin'),
            icon: const Icon(Icons.view_in_ar_outlined),
            label: const Text('Open Digital Twin'),
          ),
        ],
      ],
    );
  }

  IconData _statusIcon(ChargerHealthStatus status) => switch (status) {
    ChargerHealthStatus.healthy => Icons.check_circle_outline,
    ChargerHealthStatus.warning => Icons.warning_amber_rounded,
    ChargerHealthStatus.critical => Icons.error_outline,
    ChargerHealthStatus.unavailable => Icons.help_outline,
  };
}
