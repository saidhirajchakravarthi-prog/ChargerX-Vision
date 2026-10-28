import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../inspection/domain/models/component_inspection.dart';
import '../../../inspection/domain/models/inspection_history_record.dart';
import '../providers/inspection_history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(inspectionHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Local inspection history is unavailable.'),
        ),
        data: (records) => records.isEmpty
            ? const Center(child: Text('No saved inspections yet.'))
            : ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) => _HistoryTile(
                  record: records[index],
                  onTap: () => _showDetail(context, ref, records[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    InspectionHistoryRecord record,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.component.displayName),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Result: ${record.inspection.status.displayName}'),
                Text('Provenance: ${record.provenance.name}'),
                Text('Charger: ${record.canonicalChargerId}'),
                Text('Digital Twin: ${record.twinId} (${record.twinVersion})'),
                Text('Component ID: ${record.component.componentId}'),
                Text('Saved: ${record.createdAt.toLocal()}'),
                if (record.fault case final fault?) ...[
                  const SizedBox(height: 8),
                  Text('Fault: ${fault.faultType}'),
                  if (fault.severity != null)
                    Text('Severity: ${fault.severity}'),
                  if (fault.recommendation != null)
                    Text('Recommendation: ${fault.recommendation}'),
                ],
                for (final evidence in record.evidenceFiles)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Image.file(
                      File(evidence.path),
                      errorBuilder: (_, _, _) => const Text(
                        'Evidence image is missing or cannot be opened.',
                      ),
                    ),
                  ),
                if (record.evidenceFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No local image evidence was attached.'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete inspection'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final approved = await showDialog<bool>(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Delete saved inspection?'),
                  content: const Text(
                    'This removes the inspection and any evidence used only by this record.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (approved != true || !context.mounted) return;
              try {
                final repository = await ref.read(
                  localInspectionRepositoryProvider.future,
                );
                await repository.deleteInspection(record.id);
                ref.invalidate(inspectionHistoryProvider);
              } on Object {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not fully delete the inspection. Cleanup will be retried when history is opened again.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onTap});

  final InspectionHistoryRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.history),
    title: Text(record.component.displayName),
    subtitle: Text(
      '${record.inspection.status.displayName} • ${record.provenance.name} • ${record.createdAt.toLocal()}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
