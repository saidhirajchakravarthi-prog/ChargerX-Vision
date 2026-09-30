// lib/features/digital_twin/presentation/widgets/twin_viewer_widget.dart
import 'package:flutter/material.dart';
import '../../domain/models/digital_twin_model.dart';
import '../../domain/models/digital_twin_component.dart';

/// Abstract 3D Digital Twin viewer with Fault Visualization Foundation.
///
/// This is an abstraction layer for a future real 3D engine integration
/// (Unity, WebGL, Flutter 3D, etc.). When a real [FaultResult] identifies a component,
/// the component highlight activates.
class TwinViewerWidget extends StatelessWidget {
  final DigitalTwinModel twin;
  final DigitalTwinComponent? selectedComponent;
  final Set<String> faultedComponentIds;

  const TwinViewerWidget({
    super.key,
    required this.twin,
    this.selectedComponent,
    this.faultedComponentIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFault = faultedComponentIds.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: hasActiveFault
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveFault
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant,
          width: hasActiveFault ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFault ? Icons.warning_amber_rounded : Icons.view_in_ar_rounded,
            size: 56,
            color: hasActiveFault
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveFault
                ? 'REAL FAULT HIGHLIGHT ACTIVE'
                : '3D viewer not connected',
            style: theme.textTheme.titleMedium?.copyWith(
              color: hasActiveFault
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: hasActiveFault ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              hasActiveFault
                  ? 'Active real fault payload detected for component(s): ${faultedComponentIds.join(', ')}'
                  : 'A real 3D engine (Unity / WebGL / Flutter 3D) will render the digital twin here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasActiveFault
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Asset: ${twin.assetReference}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
