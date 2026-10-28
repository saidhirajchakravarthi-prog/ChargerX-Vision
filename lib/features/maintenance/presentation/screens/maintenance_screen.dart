import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';

import '../../domain/models/maintenance_readiness.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charger = ref.watch(selectedChargerProvider);
    final readiness = ref.watch(maintenanceReadinessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.ev_station_outlined),
                title: Text(
                  _chargerName(
                    charger?.manufacturer,
                    charger?.model,
                    charger?.type,
                  ),
                ),
                subtitle: Text(
                  charger?.serialNumber ??
                      charger?.rawQrIdentifier ??
                      'Unique charger identifier unavailable',
                ),
              ),
            ),
            const SizedBox(height: 12),
            readiness.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading maintenance readiness...'),
                    ],
                  ),
                ),
              ),
              error: (error, stack) => _statusCard(
                'Maintenance data unavailable',
                'The maintenance request could not be completed.',
              ),
              data: (data) => _readinessContent(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readinessContent(MaintenanceReadiness data) {
    final Widget stateCard;
    switch (data.status) {
      case MaintenanceReadinessStatus.missingChargerIdentity:
        stateCard = _statusCard(
          'Charger identity required',
          'Maintenance data unavailable because charger identity is missing.',
        );
      case MaintenanceReadinessStatus.notConfigured:
        stateCard = _statusCard(
          'Maintenance service not configured',
          'Maintenance service is unavailable because no backend is configured.',
        );
      case MaintenanceReadinessStatus.unavailable:
        stateCard = _statusCard(
          'Maintenance service unavailable',
          data.message ?? 'Maintenance service is currently unavailable.',
        );
      case MaintenanceReadinessStatus.error:
        stateCard = _statusCard(
          'Maintenance data error',
          data.message ?? 'Maintenance service returned invalid data.',
        );
      case MaintenanceReadinessStatus.noRecords:
        stateCard = _statusCard(
          'No maintenance records',
          'No maintenance records were returned for this charger.',
        );
      case MaintenanceReadinessStatus.recordsAvailable:
        stateCard = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: data.records.map(_recordCard).toList(growable: false),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stateCard,
        if (data.faultRecommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Fault-analysis recommendations',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'These were returned with real fault-analysis results. They are not maintenance records or scheduled work.',
          ),
          const SizedBox(height: 8),
          ...data.faultRecommendations.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.build_outlined),
                title: Text(item.recommendation),
                subtitle: Text(
                  '${item.faultType} - Component ${item.componentId}',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _recordCard(MaintenanceRecord record) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.recordType,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (record.description != null) Text(record.description!),
          if (record.componentId != null)
            Text('Component: ${record.componentId}'),
          if (record.status != null) Text('Status: ${record.status}'),
          if (record.serviceDate != null)
            Text('Service date: ${record.serviceDate!.toLocal()}'),
          if (record.workOrderId != null)
            Text('Work order: ${record.workOrderId}'),
          if (record.workOrderStatus != null)
            Text('Work order status: ${record.workOrderStatus}'),
          if (record.repairDetails != null)
            Text('Repair: ${record.repairDetails}'),
          if (record.replacementDetails != null)
            Text('Replacement: ${record.replacementDetails}'),
        ],
      ),
    ),
  );

  Widget _statusCard(String title, String message) => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(title),
      subtitle: Text(message),
    ),
  );

  String _chargerName(String? manufacturer, String? model, String? type) {
    final parts = [
      manufacturer,
      model,
      type,
    ].whereType<String>().where((item) => item.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Selected charger' : parts.join(' ');
  }
}
