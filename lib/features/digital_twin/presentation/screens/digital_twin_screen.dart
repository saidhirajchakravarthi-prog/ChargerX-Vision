// lib/features/digital_twin/presentation/screens/digital_twin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../chargers/domain/models/charger_model.dart';
import '../../../chargers/domain/models/charger_identity.dart';
import '../../../chargers/presentation/providers/selected_charger_provider.dart';
import '../../../inspection/presentation/providers/component_inspection_provider.dart';
import '../../domain/models/digital_twin_component.dart';
import '../providers/digital_twin_provider.dart';
import '../widgets/twin_viewer_widget.dart';

class DigitalTwinScreen extends ConsumerStatefulWidget {
  final ChargerModel? charger;

  const DigitalTwinScreen({super.key, this.charger});

  @override
  ConsumerState<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends ConsumerState<DigitalTwinScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final chargerToLoad = widget.charger ?? ref.read(selectedChargerProvider);
      if (chargerToLoad != null) {
        ref
            .read(digitalTwinProvider.notifier)
            .loadTwinForCharger(chargerToLoad);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCharger = ref.watch(selectedChargerProvider);
    final effectiveCharger = widget.charger ?? selectedCharger;
    final state = ref.watch(digitalTwinProvider);
    final stateForCharger =
        state.chargerKey == chargerIdentityKey(effectiveCharger)
        ? state
        : const DigitalTwinState(status: DigitalTwinStateStatus.loading);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Twin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: effectiveCharger == null
            ? _buildNoChargerView(theme)
            : _buildStateView(stateForCharger, theme),
      ),
    );
  }

  // ── No charger selected ──────────────────────────────────────────
  Widget _buildNoChargerView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ev_station_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'No Charger Selected',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a QR code or use AI recognition to identify a charger first.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Charger'),
              onPressed: () => context.go('/scan'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI Recognition'),
              onPressed: () => context.go('/ai-recognition'),
            ),
          ],
        ),
      ),
    );
  }

  // ── State router ─────────────────────────────────────────────────
  Widget _buildStateView(DigitalTwinState state, ThemeData theme) {
    switch (state.status) {
      case DigitalTwinStateStatus.idle:
      case DigitalTwinStateStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case DigitalTwinStateStatus.twinAvailable:
        return _buildTwinAvailableView(state, theme);

      case DigitalTwinStateStatus.twinUnavailable:
        return _buildErrorView(
          theme,
          icon: Icons.view_in_ar_outlined,
          iconColor: Colors.orange,
          title: 'Digital Twin Not Available',
          message:
              state.errorMessage ??
              'Digital twin asset not available for this charger model.',
        );

      case DigitalTwinStateStatus.invalidChargerModel:
        return _buildErrorView(
          theme,
          icon: Icons.error_outline,
          iconColor: Colors.red,
          title: 'Invalid Charger Data',
          message: 'The charger information is incomplete or invalid.',
        );

      case DigitalTwinStateStatus.assetLoadingError:
        return _buildErrorView(
          theme,
          icon: Icons.cloud_off_rounded,
          iconColor: Colors.red,
          title: 'Connection Error',
          message:
              state.errorMessage ??
              'Digital twin asset not available for this charger model.',
        );
    }
  }

  // ── Twin available ───────────────────────────────────────────────
  Widget _buildTwinAvailableView(DigitalTwinState state, ThemeData theme) {
    final twin = state.twin!;
    final inspectionState = ref.watch(componentInspectionProvider);
    final faultedComponentIds = faultedComponentIdsForCharger(
      activeFaults: inspectionState.faultsByChargerComponent,
      charger: widget.charger ?? ref.read(selectedChargerProvider),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ 3D Viewer ─
          TwinViewerWidget(
            twin: twin,
            selectedComponent: state.selectedComponent,
            faultedComponentIds: faultedComponentIds,
          ),
          const SizedBox(height: 20),

          // ─ Charger Info Card ─
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Twin Information', style: theme.textTheme.titleMedium),
                  const Divider(),
                  _infoRow('Manufacturer', twin.manufacturer),
                  _infoRow('Model', twin.chargerModel),
                  _infoRow('Type', twin.chargerType),
                  _infoRow('Version', twin.version),
                  _infoRow('Twin ID', twin.twinId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─ Components ─
          Text(
            'Components (${twin.components.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          if (twin.components.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No components defined for this twin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            ...twin.components.map(
              (comp) => _buildComponentTile(
                comp,
                state.selectedComponent,
                faultedComponentIds.contains(comp.componentId),
                theme,
              ),
            ),

          // ─ Selected component details ─
          if (state.selectedComponent != null) ...[
            const SizedBox(height: 16),
            _buildComponentDetail(
              state.selectedComponent!,
              faultedComponentIds.contains(
                state.selectedComponent!.componentId,
              ),
              theme,
            ),
          ],
        ],
      ),
    );
  }

  // ── Component list tile ──────────────────────────────────────────
  Widget _buildComponentTile(
    DigitalTwinComponent comp,
    DigitalTwinComponent? selected,
    bool hasRealFault,
    ThemeData theme,
  ) {
    final isSelected = selected?.componentId == comp.componentId;

    return Card(
      color: hasRealFault
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
          : (isSelected ? theme.colorScheme.primaryContainer : null),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasRealFault
            ? BorderSide(color: theme.colorScheme.error, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          hasRealFault
              ? Icons.warning_amber_rounded
              : _componentIcon(comp.componentType),
          color: hasRealFault
              ? theme.colorScheme.error
              : (isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
        ),
        title: Row(
          children: [
            Expanded(child: Text(comp.displayName)),
            if (hasRealFault)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FAULT DETECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(comp.componentType),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Inspect Component',
              onPressed: () {
                context.push('/component-inspection', extra: comp);
              },
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: () {
          ref
              .read(digitalTwinProvider.notifier)
              .selectComponent(isSelected ? null : comp);
          context.push('/component-inspection', extra: comp);
        },
      ),
    );
  }

  // ── Selected component detail card ───────────────────────────────
  Widget _buildComponentDetail(
    DigitalTwinComponent comp,
    bool hasRealFault,
    ThemeData theme,
  ) {
    return Card(
      color: hasRealFault
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasRealFault
            ? BorderSide(color: theme.colorScheme.error, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Component Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: hasRealFault
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasRealFault)
                  Chip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: const Text('REAL FAULT DETECTED'),
                    backgroundColor: theme.colorScheme.error,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const Divider(),
            _infoRow('ID', comp.componentId),
            _infoRow('Type', comp.componentType),
            _infoRow('Display Name', comp.displayName),
            _infoRow('Asset Node', comp.assetNodeIdentifier),
            _infoRow('Description', comp.description),
            if (comp.positionMetadata.isNotEmpty)
              _infoRow('Position', comp.positionMetadata.toString()),
            if (comp.inspectionCapabilityMetadata.isNotEmpty)
              _infoRow(
                'Inspection Capabilities',
                comp.inspectionCapabilityMetadata.toString(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: const Text('Inspect Component'),
                onPressed: () {
                  context.push('/component-inspection', extra: comp);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error / unavailable view ─────────────────────────────────────
  Widget _buildErrorView(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: iconColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Another Charger'),
              onPressed: () => context.go('/scan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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

  IconData _componentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'connector':
        return Icons.power;
      case 'cable':
        return Icons.cable;
      case 'display':
      case 'screen':
        return Icons.monitor;
      case 'cooling':
      case 'fan':
        return Icons.air;
      case 'board':
      case 'pcb':
        return Icons.memory;
      default:
        return Icons.settings_input_component;
    }
  }
}
