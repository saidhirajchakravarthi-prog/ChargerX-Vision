import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/adapters/inspection_analysis_adapter.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

class _WaitingInspectionAdapter implements InspectionAnalysisAdapter {
  final Completer<ComponentInspection> result =
      Completer<ComponentInspection>();
  int calls = 0;
  bool throwOnCall = false;

  @override
  bool get isConnected => true;

  @override
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
    ChargerModel? charger,
  }) async {
    calls++;
    if (throwOnCall) throw StateError('backend failure');
    return result.future;
  }

  @override
  Future<FaultResult?> fetchActiveFaultForComponent(
    String componentId, {
    ChargerModel? charger,
  }) async => null;
}

void main() {
  test(
    'provider shows loading, prevents duplicates, and safely exposes errors',
    () async {
      const component = DigitalTwinComponent(
        componentId: 'fan-01',
        componentType: 'Cooling Fan',
        displayName: 'Cooling Fan',
        assetNodeIdentifier: 'fan-node-01',
        description: 'Cooling assembly fan',
      );
      final adapter = _WaitingInspectionAdapter();
      final container = ProviderContainer(
        overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(componentInspectionProvider.notifier);
      final firstRequest = notifier.runFaultAnalysis(component);
      expect(container.read(componentInspectionProvider).isAnalyzing, isTrue);
      await notifier.runFaultAnalysis(component);
      expect(adapter.calls, 1);

      adapter.result.complete(
        ComponentInspection.failed(component, 'Service rejected this request.'),
      );
      await firstRequest;
      final state = container.read(componentInspectionProvider);
      expect(state.isAnalyzing, isFalse);
      expect(state.currentInspection?.status, InspectionStatus.failed);
      expect(state.activeFaultResult, isNull);
      expect(state.errorMessage, 'Service rejected this request.');
    },
  );

  test('thrown backend errors clear prior component highlighting', () async {
    const component = DigitalTwinComponent(
      componentId: 'fan-01',
      componentType: 'Cooling Fan',
      displayName: 'Cooling Fan',
      assetNodeIdentifier: 'fan-node-01',
      description: 'Cooling assembly fan',
    );
    final adapter = _WaitingInspectionAdapter()..throwOnCall = true;
    final container = ProviderContainer(
      overrides: [inspectionAdapterProvider.overrideWithValue(adapter)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(componentInspectionProvider.notifier);
    notifier.registerRealFaultResult(
      const FaultResult(faultType: 'prior fault', componentId: 'fan-01'),
    );

    await notifier.runFaultAnalysis(component);

    final state = container.read(componentInspectionProvider);
    expect(state.currentInspection?.status, InspectionStatus.failed);
    expect(state.activeFaultResult, isNull);
    expect(state.activeComponentFaults, isEmpty);
  });
}
