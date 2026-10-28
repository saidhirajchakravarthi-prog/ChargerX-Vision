// test/features/inspection/component_inspection_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/data/adapters/default_inspection_analysis_adapter.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';

void main() {
  group('ComponentInspectionProvider State & Transition Tests', () {
    const testComponent = DigitalTwinComponent(
      componentId: 'COMP-FAN-01',
      componentType: 'Cooling Fan',
      displayName: 'Main Cooling Fan',
      assetNodeIdentifier: 'fan_node_01',
      description: 'Primary intake cooling fan',
    );

    test('Initial provider state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(componentInspectionProvider);
      expect(state.targetComponent, null);
      expect(state.currentInspection, null);
      expect(state.activeFaultResult, null);
      expect(state.activeComponentFaults, isEmpty);
      expect(state.isAnalyzing, false);
    });

    test(
      'setComponent sets target and initializes unavailable inspection state',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(componentInspectionProvider.notifier)
            .setComponent(testComponent);

        final state = container.read(componentInspectionProvider);
        expect(state.targetComponent, testComponent);
        expect(state.currentInspection?.status, InspectionStatus.unavailable);
        expect(
          state.currentInspection?.statusMessage,
          'No inspection data available.',
        );
      },
    );

    test('setComponent does not reuse another charger\'s same-ID fault', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final selectedCharger = container.read(selectedChargerProvider.notifier);
      selectedCharger.selectCharger(
        const ChargerModel(serialNumber: 'SERIAL-A'),
      );
      final notifier = container.read(componentInspectionProvider.notifier);
      notifier.registerRealFaultResult(
        const FaultResult(faultType: 'overheating', componentId: 'COMP-FAN-01'),
      );

      selectedCharger.selectCharger(
        const ChargerModel(serialNumber: 'SERIAL-B'),
      );
      notifier.setComponent(testComponent);

      final state = container.read(componentInspectionProvider);
      expect(state.currentInspection?.status, InspectionStatus.unavailable);
      expect(state.activeFaultResult, isNull);
      expect(state.currentInspectionChargerKey, 'serial:SERIAL-B');
    });

    test(
      'runInspection when analysis service is disconnected transitions to serviceNotConnected',
      () async {
        final adapter = DefaultInspectionAnalysisAdapter(isConnected: false);
        final container = ProviderContainer(
          overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(componentInspectionProvider.notifier);
        await notifier.runInspection(testComponent);

        final state = container.read(componentInspectionProvider);
        expect(state.isAnalyzing, false);
        expect(
          state.currentInspection?.status,
          InspectionStatus.serviceNotConnected,
        );
        expect(
          state.currentInspection?.statusMessage,
          contains('Analysis service is not connected'),
        );
        expect(state.activeFaultResult, null);
      },
    );

    test(
      'runInspection when real fault is registered returns completed inspection with real fault result',
      () async {
        final adapter = DefaultInspectionAnalysisAdapter(isConnected: true);
        const charger = ChargerModel(serialNumber: 'SERIAL-A');
        final now = DateTime.now();
        final realFault = FaultResult(
          faultType: 'obstruction',
          componentId: 'COMP-FAN-01',
          componentDisplayName: 'Main Cooling Fan',
          severity: 'High',
          evidence: const [
            'Fan rotation stalled',
            'Foreign object visual signal',
          ],
          confidence: 0.96,
          detectedAt: now,
        );
        adapter.registerRealFaultResult(realFault, charger: charger);

        final container = ProviderContainer(
          overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
        );
        addTearDown(container.dispose);
        container.read(selectedChargerProvider.notifier).selectCharger(charger);

        final notifier = container.read(componentInspectionProvider.notifier);
        await notifier.runInspection(testComponent);

        final state = container.read(componentInspectionProvider);
        expect(state.currentInspection?.status, InspectionStatus.completed);
        expect(state.currentInspection?.detectedCondition, 'obstruction');
        expect(state.currentInspection?.confidence, 0.96);
        expect(state.activeFaultResult?.faultType, 'obstruction');
        expect(notifier.hasRealFaultForComponent('COMP-FAN-01'), true);
      },
    );

    test(
      'explicit backend no-fault result is preserved without a highlight',
      () async {
        final adapter = DefaultInspectionAnalysisAdapter(isConnected: true);
        adapter.registerRealInspection(
          ComponentInspection.noFaultDetected(
            component: testComponent,
            evidenceSource: const EvidenceSourceData(
              type: EvidenceSourceType.backendAnalysis,
              label: 'Backend inspection result',
            ),
          ),
        );
        final container = ProviderContainer(
          overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
        );
        addTearDown(container.dispose);

        await container
            .read(componentInspectionProvider.notifier)
            .runInspection(testComponent);
        final state = container.read(componentInspectionProvider);
        expect(
          state.currentInspection?.status,
          InspectionStatus.noFaultDetected,
        );
        expect(state.activeFaultResult, isNull);
        expect(state.activeComponentFaults, isEmpty);
      },
    );

    test(
      'registered real fault with missing confidence and severity stays unknown',
      () async {
        final adapter = DefaultInspectionAnalysisAdapter(isConnected: true);
        const charger = ChargerModel(serialNumber: 'SERIAL-A');
        adapter.registerRealFaultResult(
          const FaultResult(
            faultType: 'cooling fan failure',
            componentId: 'COMP-FAN-01',
          ),
          charger: charger,
        );
        final container = ProviderContainer(
          overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
        );
        addTearDown(container.dispose);
        container.read(selectedChargerProvider.notifier).selectCharger(charger);

        await container
            .read(componentInspectionProvider.notifier)
            .runInspection(testComponent);
        final state = container.read(componentInspectionProvider);
        expect(state.currentInspection?.confidence, isNull);
        expect(state.currentInspection?.severity, isNull);
        expect(state.currentInspection?.timestamp, isNull);
      },
    );

    test(
      'registerRealFaultResult updates fault tracking and activates component highlight state',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(selectedChargerProvider.notifier)
            .selectCharger(const ChargerModel(serialNumber: 'SERIAL-A'));

        final notifier = container.read(componentInspectionProvider.notifier);
        notifier.setComponent(testComponent);

        final realFault = FaultResult(
          faultType: 'visible overheating',
          componentId: 'COMP-FAN-01',
          severity: 'Critical',
          confidence: 0.91,
        );

        notifier.registerRealFaultResult(realFault);

        final state = container.read(componentInspectionProvider);
        expect(state.activeFaultResult, realFault);
        expect(state.currentInspection?.status, InspectionStatus.completed);
        expect(state.currentInspection?.confidence, 0.91);
        expect(notifier.hasRealFaultForComponent('COMP-FAN-01'), true);
        expect(notifier.hasRealFaultForComponent('COMP-WIRING-99'), false);
      },
    );

    test(
      'same component ID keeps independent faults and inspections per charger',
      () async {
        const chargerA = ChargerModel(serialNumber: 'SERIAL-A');
        const chargerB = ChargerModel(serialNumber: 'SERIAL-B');
        final adapter = DefaultInspectionAnalysisAdapter(isConnected: true)
          ..registerRealFaultResult(
            const FaultResult(faultType: 'fault A', componentId: 'COMP-FAN-01'),
            charger: chargerA,
          )
          ..registerRealInspection(
            ComponentInspection.noFaultDetected(
              component: testComponent,
              evidenceSource: EvidenceSourceData.none,
            ),
            charger: chargerB,
          );
        final container = ProviderContainer(
          overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
        );
        addTearDown(container.dispose);
        final selected = container.read(selectedChargerProvider.notifier);
        final notifier = container.read(componentInspectionProvider.notifier);

        selected.selectCharger(chargerA);
        await notifier.runInspection(testComponent);
        expect(notifier.hasRealFaultForComponent('COMP-FAN-01'), isTrue);

        selected.selectCharger(chargerB);
        notifier.setComponent(testComponent);
        expect(
          container.read(componentInspectionProvider).currentInspection?.status,
          InspectionStatus.unavailable,
        );
        await notifier.runInspection(testComponent);
        var state = container.read(componentInspectionProvider);
        expect(
          state.currentInspection?.status,
          InspectionStatus.noFaultDetected,
        );
        expect(
          state.faultsForCharger('serial:SERIAL-A')['COMP-FAN-01']?.faultType,
          'fault A',
        );
        expect(state.faultsForCharger('serial:SERIAL-B'), isEmpty);

        selected.selectCharger(chargerA);
        notifier.setComponent(testComponent);
        state = container.read(componentInspectionProvider);
        expect(state.currentInspection?.status, InspectionStatus.completed);
        expect(state.activeFaultResult?.faultType, 'fault A');
      },
    );

    test(
      'two chargers retain different faults for an identical component ID',
      () {
        const chargerA = ChargerModel(serialNumber: 'SERIAL-A');
        const chargerB = ChargerModel(serialNumber: 'SERIAL-B');
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final selected = container.read(selectedChargerProvider.notifier);
        final notifier = container.read(componentInspectionProvider.notifier);

        selected.selectCharger(chargerA);
        notifier.setComponent(testComponent);
        notifier.registerRealFaultResult(
          const FaultResult(faultType: 'fault A', componentId: 'COMP-FAN-01'),
        );
        selected.selectCharger(chargerB);
        notifier.setComponent(testComponent);
        notifier.registerRealFaultResult(
          const FaultResult(faultType: 'fault B', componentId: 'COMP-FAN-01'),
        );

        var state = container.read(componentInspectionProvider);
        expect(
          state.faultsForCharger('serial:SERIAL-A')['COMP-FAN-01']?.faultType,
          'fault A',
        );
        expect(
          state.faultsForCharger('serial:SERIAL-B')['COMP-FAN-01']?.faultType,
          'fault B',
        );

        selected.selectCharger(chargerA);
        notifier.setComponent(testComponent);
        state = container.read(componentInspectionProvider);
        expect(state.activeFaultResult?.faultType, 'fault A');
        selected.selectCharger(chargerB);
        notifier.setComponent(testComponent);
        state = container.read(componentInspectionProvider);
        expect(state.activeFaultResult?.faultType, 'fault B');
      },
    );

    test('fault registered without charger identity is not scoped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(componentInspectionProvider.notifier);
      notifier.setComponent(testComponent);
      notifier.registerRealFaultResult(
        const FaultResult(faultType: 'unscoped', componentId: 'COMP-FAN-01'),
      );

      final state = container.read(componentInspectionProvider);
      expect(state.faultsByChargerComponent, isEmpty);
      expect(state.activeFaultChargerKeys, isEmpty);
      expect(notifier.hasRealFaultForComponent('COMP-FAN-01'), isFalse);
      expect(state.currentInspectionChargerKey, isNull);
    });
  });
}
