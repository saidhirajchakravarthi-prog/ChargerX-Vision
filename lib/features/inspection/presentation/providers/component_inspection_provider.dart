// lib/features/inspection/presentation/providers/component_inspection_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import '../../data/adapters/default_fault_detection_adapter.dart';
import '../../domain/adapters/fault_detection_adapter.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';

final faultDetectionAdapterProvider = Provider<FaultDetectionAdapter>((ref) {
  return DefaultFaultDetectionAdapter(isConnected: false);
});

final inspectionAdapterProvider = Provider<InspectionAnalysisAdapter>((ref) {
  return ref.watch(faultDetectionAdapterProvider);
});

class ComponentInspectionState {
  final DigitalTwinComponent? targetComponent;
  final ComponentInspection? currentInspection;
  final FaultResult? activeFaultResult;
  final Map<String, FaultResult> activeComponentFaults;
  final bool isAnalyzing;
  final String? errorMessage;

  const ComponentInspectionState({
    this.targetComponent,
    this.currentInspection,
    this.activeFaultResult,
    this.activeComponentFaults = const {},
    this.isAnalyzing = false,
    this.errorMessage,
  });

  ComponentInspectionState copyWith({
    DigitalTwinComponent? targetComponent,
    ComponentInspection? currentInspection,
    FaultResult? activeFaultResult,
    Map<String, FaultResult>? activeComponentFaults,
    bool? isAnalyzing,
    String? errorMessage,
    bool clearActiveFaultResult = false,
  }) {
    return ComponentInspectionState(
      targetComponent: targetComponent ?? this.targetComponent,
      currentInspection: currentInspection ?? this.currentInspection,
      activeFaultResult: clearActiveFaultResult
          ? null
          : (activeFaultResult ?? this.activeFaultResult),
      activeComponentFaults:
          activeComponentFaults ?? this.activeComponentFaults,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final componentInspectionProvider =
    NotifierProvider<ComponentInspectionNotifier, ComponentInspectionState>(
  ComponentInspectionNotifier.new,
);

class ComponentInspectionNotifier
    extends Notifier<ComponentInspectionState> {
  @override
  ComponentInspectionState build() {
    return const ComponentInspectionState();
  }

  /// Sets the active component for inspection and initializes its status.
  void setComponent(DigitalTwinComponent component) {
    final existingFault = state.activeComponentFaults[component.componentId];
    final initialInspection = existingFault != null
        ? ComponentInspection.completed(
            component: component,
            evidenceSource: existingFault.evidenceSources.isNotEmpty
                ? existingFault.evidenceSources.first
                : EvidenceSourceData(
                    type: EvidenceSourceType.backendAnalysis,
                    label: 'Real Backend Evidence',
                    timestamp: existingFault.detectedAt,
                  ),
            detectedCondition: existingFault.faultType,
            confidence: existingFault.confidence ?? 1.0,
            severity: existingFault.severity ?? 'Medium',
            timestamp: existingFault.detectedAt ?? DateTime.now(),
          )
        : ComponentInspection.unavailable(component);

    state = state.copyWith(
      targetComponent: component,
      currentInspection: initialInspection,
      activeFaultResult: existingFault,
      clearActiveFaultResult: existingFault == null,
      errorMessage: null,
    );
  }

  /// Runs fault analysis for a component against real evidence sources.
  Future<void> runFaultAnalysis(
    DigitalTwinComponent component, {
    List<EvidenceSourceData> evidenceList = const [],
  }) async {
    state = state.copyWith(
      targetComponent: component,
      isAnalyzing: true,
      errorMessage: null,
    );

    try {
      final adapter = ref.read(faultDetectionAdapterProvider);
      if (!adapter.isConnected) {
        state = state.copyWith(
          currentInspection: ComponentInspection.serviceNotConnected(component),
          isAnalyzing: false,
        );
        return;
      }

      final faultResult = await adapter.detectFault(
        componentId: component.componentId,
        evidenceList: evidenceList,
      );

      if (faultResult == null) {
        state = state.copyWith(
          currentInspection: ComponentInspection.unavailable(component),
          isAnalyzing: false,
        );
        return;
      }

      final updatedFaults = Map<String, FaultResult>.from(
        state.activeComponentFaults,
      );
      updatedFaults[component.componentId] = faultResult;

      final completedInspection = ComponentInspection.completed(
        component: component,
        evidenceSource: faultResult.evidenceSources.isNotEmpty
            ? faultResult.evidenceSources.first
            : EvidenceSourceData(
                type: EvidenceSourceType.backendAnalysis,
                label: 'Real Backend Analysis Evidence',
                timestamp: faultResult.detectedAt,
              ),
        detectedCondition: faultResult.faultType,
        confidence: faultResult.confidence ?? 1.0,
        severity: faultResult.severity ?? 'Medium',
        timestamp: faultResult.detectedAt ?? DateTime.now(),
        evidenceMetadata: {
          'evidenceList': faultResult.evidence,
          'locationDescription': faultResult.locationDescription,
        },
      );

      state = state.copyWith(
        currentInspection: completedInspection,
        activeFaultResult: faultResult,
        activeComponentFaults: updatedFaults,
        isAnalyzing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Triggers component inspection using the adapter interface.
  Future<void> runInspection(
    DigitalTwinComponent component, {
    EvidenceSourceData? customEvidence,
  }) async {
    await runFaultAnalysis(
      component,
      evidenceList: customEvidence != null ? [customEvidence] : const [],
    );
  }

  /// Registers a REAL fault result received from a real backend/sensor/AI payload.
  void registerRealFaultResult(FaultResult fault) {
    final updatedFaults = Map<String, FaultResult>.from(
      state.activeComponentFaults,
    );
    updatedFaults[fault.componentId] = fault;

    ComponentInspection? updatedInspection = state.currentInspection;
    FaultResult? updatedActiveFault = state.activeFaultResult;

    if (state.targetComponent?.componentId == fault.componentId) {
      updatedActiveFault = fault;
      updatedInspection = ComponentInspection.completed(
        component: state.targetComponent!,
        evidenceSource: fault.evidenceSources.isNotEmpty
            ? fault.evidenceSources.first
            : EvidenceSourceData(
                type: EvidenceSourceType.backendAnalysis,
                label: 'Real Backend Evidence',
                timestamp: fault.detectedAt,
              ),
        detectedCondition: fault.faultType,
        confidence: fault.confidence ?? 1.0,
        severity: fault.severity ?? 'Medium',
        timestamp: fault.detectedAt ?? DateTime.now(),
      );
    }

    state = state.copyWith(
      activeComponentFaults: updatedFaults,
      activeFaultResult: updatedActiveFault,
      currentInspection: updatedInspection,
    );
  }

  /// Clears active state.
  void clearState() {
    state = const ComponentInspectionState();
  }

  /// Check if a real fault result exists for a component ID.
  bool hasRealFaultForComponent(String componentId) {
    return state.activeComponentFaults.containsKey(componentId);
  }
}
