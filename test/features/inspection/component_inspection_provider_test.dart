// test/features/inspection/component_inspection_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/data/adapters/default_inspection_analysis_adapter.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

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

    test('setComponent sets target and initializes unavailable inspection state', () {
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
    });

    test('runInspection when analysis service is disconnected transitions to serviceNotConnected', () async {
      final adapter = DefaultInspectionAnalysisAdapter(isConnected: false);
      final container = ProviderContainer(
        overrides: [
          inspectionAdapterProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      await notifier.runInspection(testComponent);

      final state = container.read(componentInspectionProvider);
      expect(state.isAnalyzing, false);
      expect(state.currentInspection?.status, InspectionStatus.serviceNotConnected);
      expect(
        state.currentInspection?.statusMessage,
        contains('Analysis service is not connected'),
      );
      expect(state.activeFaultResult, null);
    });

    test('runInspection when real fault is registered returns completed inspection with real fault result', () async {
      final adapter = DefaultInspectionAnalysisAdapter(isConnected: true);
      final now = DateTime.now();
      final realFault = FaultResult(
        faultType: 'obstruction',
        componentId: 'COMP-FAN-01',
        componentDisplayName: 'Main Cooling Fan',
        severity: 'High',
        evidence: const ['Fan rotation stalled', 'Foreign object visual signal'],
        confidence: 0.96,
        detectedAt: now,
      );
      adapter.registerRealFaultResult(realFault);

      final container = ProviderContainer(
        overrides: [
          inspectionAdapterProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      await notifier.runInspection(testComponent);

      final state = container.read(componentInspectionProvider);
      expect(state.currentInspection?.status, InspectionStatus.completed);
      expect(state.currentInspection?.detectedCondition, 'obstruction');
      expect(state.currentInspection?.confidence, 0.96);
      expect(state.activeFaultResult?.faultType, 'obstruction');
      expect(notifier.hasRealFaultForComponent('COMP-FAN-01'), true);
    });

    test('registerRealFaultResult updates fault tracking and activates component highlight state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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
    });
  });
}
