import 'package:flutter/material.dart';
import '../../domain/models/digital_twin_model.dart';
import '../../domain/models/digital_twin_component.dart';

/// Viewer boundary for a future 3D engine. A red pulse is shown only for
/// component IDs with a registered fault result from the analysis adapter.
class TwinViewerWidget extends StatefulWidget {
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
  State<TwinViewerWidget> createState() => _TwinViewerWidgetState();
}

class _TwinViewerWidgetState extends State<TwinViewerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFault = widget.faultedComponentIds.isNotEmpty;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final intensity = hasFault ? 0.35 + (_pulse.value * 0.65) : 0.0;
        return Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: hasFault
                ? theme.colorScheme.errorContainer.withValues(
                    alpha: 0.08 + intensity * 0.18,
                  )
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFault
                  ? theme.colorScheme.error.withValues(alpha: intensity)
                  : theme.colorScheme.outlineVariant,
              width: hasFault ? 1.5 + intensity * 1.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFault
                    ? Icons.warning_amber_rounded
                    : Icons.view_in_ar_rounded,
                size: 56,
                color: hasFault
                    ? theme.colorScheme.error.withValues(alpha: intensity)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                hasFault ? 'FAULT DETECTED' : '3D viewer not connected',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: hasFault
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: hasFault ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  hasFault
                      ? 'Tap the marked component to review its fault: ${widget.faultedComponentIds.join(', ')}'
                      : 'A real 3D engine will render this digital twin here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasFault
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Asset: ${widget.twin.assetReference}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
