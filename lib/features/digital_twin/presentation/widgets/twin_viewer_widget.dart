// lib/features/digital_twin/presentation/widgets/twin_viewer_widget.dart
import 'package:flutter/material.dart';
import '../../domain/models/digital_twin_model.dart';

/// Abstract 3D Digital Twin viewer.
///
/// This is an abstraction layer for a future real 3D engine integration
/// (Unity, WebGL, Flutter 3D, etc.). For now it renders a clear placeholder
/// indicating that the 3D viewer is not yet connected.
class TwinViewerWidget extends StatelessWidget {
  final DigitalTwinModel twin;

  const TwinViewerWidget({super.key, required this.twin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_in_ar_rounded,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '3D viewer not connected',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'A real 3D engine (Unity / WebGL / Flutter 3D) will render the '
              ' digital twin here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Asset: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
