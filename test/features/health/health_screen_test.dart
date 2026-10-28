import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/health/presentation/screens/health_screen.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

void main() {
  testWidgets('shows assessment status and real fault/component details', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(selectedChargerProvider.notifier)
        .selectCharger(
          const ChargerModel(
            manufacturer: 'ABB',
            model: 'Terra',
            serialNumber: 'SN-100',
          ),
        );
    const component = DigitalTwinComponent(
      componentId: 'fan-01',
      componentType: 'Cooling Fan',
      displayName: 'Cooling Fan',
      assetNodeIdentifier: 'fan-node-01',
      description: 'Cooling assembly fan',
    );
    final notifier = container.read(componentInspectionProvider.notifier);
    notifier.setComponent(component);
    notifier.registerRealFaultResult(
      const FaultResult(
        faultType: 'Fan obstruction',
        componentId: 'fan-01',
        componentDisplayName: 'Cooling Fan',
        severity: 'Warning',
        locationDescription: 'Upper vent',
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HealthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Fan obstruction'), findsOneWidget);
    expect(find.textContaining('Cooling Fan'), findsWidgets);
    expect(find.textContaining('Upper vent'), findsOneWidget);
  });
}
