// test/features/inspection/fault_localization_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/data/adapters/default_fault_detection_adapter.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

void main() {
  group('Component Fault Localization & State Tests', () {
    const componentA = DigitalTwinComponent(
      componentId: 'COMP-WIRING-01',
      componentType: 'Wiring',
      displayName: 'Main DC Power Harness',
      assetNodeIdentifier: 'wiring_harness_01',
      description: 'DC high-current wiring bundle',
    );

    const componentB = DigitalTwinComponent(
      componentId: 'COMP-FAN-01',
      componentType: 'Cooling Fan',
      displayName: 'Primary Intake Fan',
      assetNodeIdentifier: 'fan_01',
      description: 'Enclosure cooling fan',
    );

    test('runFaultAnalysis when disconnected transitions to serviceNotConnected state', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: false);
      final container = ProviderContainer(
        overrides: [
          faultDetectionAdapterProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      await notifier.runFaultAnalysis(componentA);

      final state = container.read(componentInspectionProvider);
      expect(
        state.currentInspection?.statusMessage,
        contains('Fault detection service is not connected'),
      );
      expect(state.activeFaultResult, null);
    });

    test('runFaultAnalysis when connected with no evidence transitions to unavailable state', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: true);
      final container = ProviderContainer(
        overrides: [
          faultDetectionAdapterProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      await notifier.runFaultAnalysis(componentA);

      final state = container.read(componentInspectionProvider);
      expect(state.currentInspection?.statusMessage, 'No inspection data available.');
      expect(state.activeFaultResult, null);
    });

    test('component localization activates fault state for target component only', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      notifier.setComponent(componentA);

      final realFault = FaultResult(
        faultType: 'short-circuit evidence',
        category: FaultCategory.wiring,
        componentId: componentA.componentId,
        componentDisplayName: componentA.displayName,
        severity: 'Critical',
        evidenceSources: const [
          EvidenceSourceData(
            type: EvidenceSourceType.electricalMeasurement,
            label: 'Impedance drop < 0.1 ohm detected',
          ),
        ],
      );

      notifier.registerRealFaultResult(realFault);

      expect(notifier.hasRealFaultForComponent(componentA.componentId), true);
      expect(notifier.hasRealFaultForComponent(componentB.componentId), false);

      final state = container.read(componentInspectionProvider);
      expect(state.activeFaultResult?.faultType, 'short-circuit evidence');
      expect(state.activeFaultResult?.category, FaultCategory.wiring);
    });

    test('multiple fault results localization tracks independent component fault states', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);

      final faultA = FaultResult(
        faultType: 'short-circuit evidence',
        category: FaultCategory.wiring,
        componentId: componentA.componentId,
      );

      final faultB = FaultResult(
        faultType: 'cooling fan failure',
        category: FaultCategory.internal,
        componentId: componentB.componentId,
      );

      notifier.registerRealFaultResult(faultA);
      notifier.registerRealFaultResult(faultB);

      expect(notifier.hasRealFaultForComponent(componentA.componentId), true);
      expect(notifier.hasRealFaultForComponent(componentB.componentId), true);
      expect(notifier.hasRealFaultForComponent('COMP-FUSE-99'), false);
    });
  });
}
