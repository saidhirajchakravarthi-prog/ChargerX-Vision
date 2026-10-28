import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

class ComponentInspectionScreen extends ConsumerStatefulWidget {
  final DigitalTwinComponent component;

  const ComponentInspectionScreen({super.key, required this.component});

  @override
  ConsumerState<ComponentInspectionScreen> createState() =>
      _ComponentInspectionScreenState();
}

class _ComponentInspectionScreenState
    extends ConsumerState<ComponentInspectionScreen> {
  EvidenceSourceData? _selectedEvidence;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(componentInspectionProvider.notifier)
          .setComponent(widget.component),
    );
  }

  Future<void> _pickEvidence(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (!mounted || image == null) return;
      setState(() {
        _selectedEvidence = EvidenceSourceData(
          type: EvidenceSourceType.cameraImage,
          label: source == ImageSource.camera
              ? 'Camera image selected'
              : 'Gallery image selected',
          metadata: {'path': image.path},
          timestamp: DateTime.now(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not access the image. Check camera or photo permissions and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(componentInspectionProvider);
    final inspection =
        state.currentInspection ??
        ComponentInspection.unavailable(widget.component);
    final category = ComponentCategoryExtension.fromString(
      widget.component.componentType,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Component Inspection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Return to Digital Twin',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/digital-twin'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_input_component),
                title: Text(widget.component.displayName),
                subtitle: Text(
                  '${category.displayName} • ${widget.component.componentId}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _statusCard(context, inspection),
            if (state.persistenceMessage != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Local record status'),
                  subtitle: Text(state.persistenceMessage!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidence',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedEvidence?.label ??
                          'No image selected. Connect an analysis service to analyze evidence.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickEvidence(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choose image'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickEvidence(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Capture photo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isAnalyzing
                  ? null
                  : () => ref
                        .read(componentInspectionProvider.notifier)
                        .runFaultAnalysis(
                          widget.component,
                          evidenceList: _selectedEvidence == null
                              ? const []
                              : [_selectedEvidence!],
                        ),
              icon: state.isAnalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.troubleshoot),
              label: Text(
                state.isAnalyzing ? 'Analyzing…' : 'Start component inspection',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Inspection result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _resultCard(context, inspection, state.activeFaultResult),
            const SizedBox(height: 16),
            Text(
              'Supported conditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: category.supportedConditions
                  .map((condition) => Chip(label: Text(condition)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context, ComponentInspection inspection) {
    final color = switch (inspection.status) {
      InspectionStatus.completed ||
      InspectionStatus.noFaultDetected => Colors.green,
      InspectionStatus.serviceNotConnected => Colors.orange,
      InspectionStatus.pending => Theme.of(context).colorScheme.primary,
      InspectionStatus.failed => Theme.of(context).colorScheme.error,
      InspectionStatus.unavailable => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Card(
      child: ListTile(
        leading: inspection.status == InspectionStatus.pending
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                inspection.status == InspectionStatus.noFaultDetected
                    ? Icons.check_circle_outline
                    : inspection.status == InspectionStatus.failed
                    ? Icons.error_outline
                    : Icons.info_outline,
                color: color,
              ),
        title: Text(inspection.status.displayName),
        subtitle: Text(inspection.statusMessage),
      ),
    );
  }

  Widget _resultCard(
    BuildContext context,
    ComponentInspection inspection,
    FaultResult? fault,
  ) {
    final theme = Theme.of(context);
    if (fault != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.error, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAULT DETECTED',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              _detail(
                'Component',
                fault.componentDisplayName ?? widget.component.displayName,
              ),
              _detail('Component ID', fault.componentId),
              _detail('Fault type', fault.faultType),
              _detail('Category', fault.category.displayName),
              if (fault.locationDescription != null &&
                  fault.locationDescription!.isNotEmpty)
                _detail('Location', fault.locationDescription!),
              if (fault.severity != null) _detail('Severity', fault.severity!),
              if (fault.probableCause != null)
                _detail('Cause', fault.probableCause!),
              if (fault.recommendation != null)
                _detail('Recommended repair', fault.recommendation!),
              if (fault.confidence != null)
                _detail(
                  'Confidence',
                  '${(fault.confidence! * 100).toStringAsFixed(1)}%',
                ),
              if (fault.evidenceSources.isNotEmpty)
                _detail(
                  'Evidence',
                  fault.evidenceSources.map((e) => e.label).join(', '),
                )
              else if (fault.evidence.isNotEmpty)
                _detail('Evidence', fault.evidence.join(', ')),
            ],
          ),
        ),
      );
    }
    final message = switch (inspection.status) {
      InspectionStatus.noFaultDetected =>
        'The connected analysis service reported no fault for this component.',
      InspectionStatus.serviceNotConnected =>
        'Fault analysis is unavailable because no backend or sensor service is connected.',
      InspectionStatus.failed => inspection.statusMessage,
      InspectionStatus.unavailable => 'No inspection result is available.',
      InspectionStatus.pending => 'Analysis is in progress.',
      InspectionStatus.completed => inspection.statusMessage,
    };
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
