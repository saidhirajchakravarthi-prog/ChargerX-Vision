// lib/features/inspection/presentation/screens/component_inspection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

class ComponentInspectionScreen extends ConsumerStatefulWidget {
  final DigitalTwinComponent component;

  const ComponentInspectionScreen({
    super.key,
    required this.component,
  });

  @override
  ConsumerState<ComponentInspectionScreen> createState() =>
      _ComponentInspectionScreenState();
}

class _ComponentInspectionScreenState
    extends ConsumerState<ComponentInspectionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(componentInspectionProvider.notifier)
          .setComponent(widget.component);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inspectionState = ref.watch(componentInspectionProvider);
    final component = widget.component;
    final category = ComponentCategoryExtension.fromString(component.componentType);
    final inspection = inspectionState.currentInspection ??
        ComponentInspection.unavailable(component);
    final activeFault = inspectionState.activeFaultResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Component Inspection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/digital-twin');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── COMPONENT HEADER ─────────────────────────────────────
              _buildComponentHeaderCard(theme, component, category),
              const SizedBox(height: 16),

              // ── STATUS CARD ──────────────────────────────────────────
              _buildStatusCard(theme, inspection),
              const SizedBox(height: 16),

              // ── EVIDENCE CARD ────────────────────────────────────────
              _buildEvidenceCard(theme, inspection),
              const SizedBox(height: 20),

              // ── ACTION AREA ──────────────────────────────────────────
              _buildActionArea(theme, inspectionState),
              const SizedBox(height: 24),

              // ── RESULT / SERVICE STATE AREA ──────────────────────────
              Text(
                'Inspection Result',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildResultArea(theme, inspection, activeFault),

              const SizedBox(height: 24),
              // ── SUPPORTED CONDITIONS REFERENCE ──────────────────────
              _buildSupportedConditionsCard(theme, category),
            ],
          ),
        ),
      ),
    );
  }

  // ── Component Header ─────────────────────────────────────────────
  Widget _buildComponentHeaderCard(
    ThemeData theme,
    DigitalTwinComponent comp,
    ComponentCategory category,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                _getCategoryIcon(category),
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPONENT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comp.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${comp.componentId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (comp.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comp.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Card ──────────────────────────────────────────────────
  Widget _buildStatusCard(ThemeData theme, ComponentInspection inspection) {
    final statusColor = _getStatusColor(theme, inspection.status);
    final statusIcon = _getStatusIcon(inspection.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STATUS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    inspection.status.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Evidence Card ────────────────────────────────────────────────
  Widget _buildEvidenceCard(ThemeData theme, ComponentInspection inspection) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EVIDENCE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inspection.evidenceSource.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (inspection.evidenceSource.type != EvidenceSourceType.none) ...[
              const SizedBox(height: 6),
              Text(
                'Source Type: ${inspection.evidenceSource.type.displayName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Action Area ──────────────────────────────────────────────────
  Widget _buildActionArea(
    ThemeData theme,
    ComponentInspectionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ACTION',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: state.isAnalyzing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.troubleshoot_rounded),
          label: Text(
            state.isAnalyzing ? 'Running Fault Analysis...' : 'Run Fault Analysis',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: state.isAnalyzing
              ? null
              : () {
                  ref
                      .read(componentInspectionProvider.notifier)
                      .runFaultAnalysis(widget.component);
                },
        ),
      ],
    );
  }

  // ── Result Area ──────────────────────────────────────────────────
  Widget _buildResultArea(
    ThemeData theme,
    ComponentInspection inspection,
    FaultResult? activeFault,
  ) {
    if (activeFault != null) {
      return _buildFaultDetailsCard(theme, activeFault);
    }

    switch (inspection.status) {
      case InspectionStatus.unavailable:
        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No fault detection data available.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case InspectionStatus.serviceNotConnected:
        return Card(
          elevation: 0,
          color: Colors.amber.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.amber, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Fault detection service is not connected.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fault detection service is not connected. Connect a camera, thermal scanner, ESP32/IoT device, electrical meter, diagnostic interface, or backend AI service to analyze this component.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );

      case InspectionStatus.completed:
        return Card(
          elevation: 0,
          color: Colors.green.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.green),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Inspection Complete',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (inspection.detectedCondition != null)
                  Text('Detected Condition: ${inspection.detectedCondition}'),
                if (inspection.confidence != null)
                  Text(
                    'Confidence: ${(inspection.confidence! * 100).toStringAsFixed(1)}%',
                  ),
                if (inspection.severity != null)
                  Text('Severity: ${inspection.severity}'),
              ],
            ),
          ),
        );

      case InspectionStatus.pending:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );

      case InspectionStatus.failed:
        return Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Inspection Failed: ${inspection.statusMessage}',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        );
    }
  }

  // ── Real Fault Details Card (Only shown when a REAL result exists) ──────
  Widget _buildFaultDetailsCard(ThemeData theme, FaultResult fault) {
    final evidenceText = fault.evidenceSources.isNotEmpty
        ? fault.evidenceSources.map((e) => e.label).join(', ')
        : (fault.evidence.isNotEmpty ? fault.evidence.join(', ') : null);

    return Card(
      elevation: 2,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.error, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_problem_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FAULT DETECTED',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoDetailRow('Component', '${widget.component.displayName} (${widget.component.componentId})'),
            _infoDetailRow('Fault', fault.faultType),
            _infoDetailRow('Category', fault.category.displayName),
            if (evidenceText != null)
              _infoDetailRow('Evidence', evidenceText),
            if (fault.severity != null)
              _infoDetailRow('Severity', fault.severity!),
            if (fault.locationDescription != null)
              _infoDetailRow('Location', fault.locationDescription!),
            if (fault.probableCause != null)
              _infoDetailRow('Probable Cause', fault.probableCause!),
            if (fault.recommendation != null)
              _infoDetailRow('Recommended Action', fault.recommendation!),
            if (fault.confidence != null)
              _infoDetailRow(
                'Confidence',
                '${(fault.confidence! * 100).toStringAsFixed(1)}%',
              ),
            if (fault.detectedAt != null)
              _infoDetailRow('Detected At', fault.detectedAt!.toIso8601String()),
          ],
        ),
      ),
    );
  }

  // ── Supported Conditions Card ───────────────────────────────────
  Widget _buildSupportedConditionsCard(
    ThemeData theme,
    ComponentCategory category,
  ) {
    final conditions = category.supportedConditions;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUPPORTED INSPECTION CONDITIONS (${category.displayName})',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conditions
                  .map(
                    (cond) => Chip(
                      label: Text(cond),
                      labelStyle: theme.textTheme.bodySmall,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                      padding: const EdgeInsets.all(4),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _infoDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(ThemeData theme, InspectionStatus status) {
    switch (status) {
      case InspectionStatus.unavailable:
        return theme.colorScheme.onSurfaceVariant;
      case InspectionStatus.serviceNotConnected:
        return Colors.amber.shade800;
      case InspectionStatus.pending:
        return theme.colorScheme.primary;
      case InspectionStatus.completed:
        return Colors.green;
      case InspectionStatus.failed:
        return theme.colorScheme.error;
    }
  }

  IconData _getStatusIcon(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.unavailable:
        return Icons.do_not_disturb_on_outlined;
      case InspectionStatus.serviceNotConnected:
        return Icons.cloud_off_rounded;
      case InspectionStatus.pending:
        return Icons.hourglass_top_rounded;
      case InspectionStatus.completed:
        return Icons.check_circle_rounded;
      case InspectionStatus.failed:
        return Icons.error_rounded;
    }
  }

  IconData _getCategoryIcon(ComponentCategory cat) {
    switch (cat) {
      case ComponentCategory.wiring:
        return Icons.cable_rounded;
      case ComponentCategory.connector:
        return Icons.power_rounded;
      case ComponentCategory.pcb:
        return Icons.memory_rounded;
      case ComponentCategory.fuse:
        return Icons.electric_bolt_rounded;
      case ComponentCategory.relayContactor:
        return Icons.toggle_on_rounded;
      case ComponentCategory.capacitorMosfet:
        return Icons.developer_board_rounded;
      case ComponentCategory.coolingFan:
        return Icons.air_rounded;
      case ComponentCategory.sensors:
        return Icons.sensors_rounded;
      case ComponentCategory.communication:
        return Icons.wifi_rounded;
      case ComponentCategory.other:
        return Icons.settings_input_component_rounded;
    }
  }
}
