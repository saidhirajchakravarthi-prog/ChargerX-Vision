// lib/features/inspection/data/adapters/default_fault_detection_adapter.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import '../../domain/adapters/fault_detection_adapter.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';

class DefaultFaultDetectionAdapter
    implements FaultDetectionAdapter, InspectionAnalysisAdapter {
  final bool _connected;
  final Map<String, FaultResult> _registeredRealFaults = {};
  final Map<String, ComponentInspection> _registeredRealInspections = {};

  DefaultFaultDetectionAdapter({bool isConnected = false})
      : _connected = isConnected;

  @override
  bool get isConnected => _connected;

  /// Injects a REAL fault result received from a real hardware sensor,
  /// thermal image, camera/YOLO, electrical measurement, diagnostic, or backend AI payload.
  void registerRealFaultResult(FaultResult fault) {
    _registeredRealFaults[fault.componentId] = fault;
  }

  /// Injects a REAL completed component inspection.
  void registerRealInspection(ComponentInspection inspection) {
    _registeredRealInspections[inspection.component.componentId] = inspection;
  }

  /// Clears stored real results.
  void clearRealResults() {
    _registeredRealFaults.clear();
    _registeredRealInspections.clear();
  }

  @override
  Future<FaultResult?> detectFault({
    required String componentId,
    List<EvidenceSourceData> evidenceList = const [],
  }) async {
    if (!_connected) {
      return null;
    }

    // Check registered real faults for this component
    if (_registeredRealFaults.containsKey(componentId)) {
      final existingFault = _registeredRealFaults[componentId]!;
      if (evidenceList.isNotEmpty) {
        final combinedSources = [
          ...existingFault.evidenceSources,
          ...evidenceList.where(
            (newEv) => !existingFault.evidenceSources.any(
              (oldEv) => oldEv.type == newEv.type && oldEv.label == newEv.label,
            ),
          ),
        ];
        return existingFault.copyWith(evidenceSources: combinedSources);
      }
      return existingFault;
    }

    // If evidenceList contains real non-none evidence without prior registration, build evidence result
    final validEvidence = evidenceList
        .where((e) => e.type != EvidenceSourceType.none)
        .toList();

    if (validEvidence.isEmpty) {
      return null;
    }

    // Form fault result from provided real evidence
    final primary = validEvidence.first;
    return FaultResult(
      faultType: primary.label,
      componentId: componentId,
      evidenceSources: validEvidence,
      evidence: validEvidence.map((e) => '${e.type.displayName}: ${e.label}').toList(),
      detectedAt: primary.timestamp ?? DateTime.now(),
    );
  }

  @override
  Future<FaultResult?> fetchActiveFaultForComponent(String componentId) async {
    return _registeredRealFaults[componentId];
  }

  @override
  Future<List<FaultResult>> fetchAllActiveFaults() async {
    return _registeredRealFaults.values.toList();
  }

  @override
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
  }) async {
    if (_registeredRealInspections.containsKey(component.componentId)) {
      return _registeredRealInspections[component.componentId]!;
    }

    final activeFault = await detectFault(
      componentId: component.componentId,
      evidenceList: evidence != null ? [evidence] : const [],
    );

    if (activeFault != null) {
      return ComponentInspection.completed(
        component: component,
        evidenceSource: evidence ??
            (activeFault.evidenceSources.isNotEmpty
                ? activeFault.evidenceSources.first
                : EvidenceSourceData(
                    type: EvidenceSourceType.backendAnalysis,
                    label: 'Real Backend Analysis Evidence',
                    timestamp: activeFault.detectedAt,
                  )),
        detectedCondition: activeFault.faultType,
        confidence: activeFault.confidence ?? 1.0,
        severity: activeFault.severity ?? 'Medium',
        timestamp: activeFault.detectedAt ?? DateTime.now(),
        evidenceMetadata: {
          'evidenceList': activeFault.evidence,
          'locationDescription': activeFault.locationDescription,
        },
      );
    }

    if (!_connected) {
      return ComponentInspection.serviceNotConnected(component);
    }

    return ComponentInspection.unavailable(component);
  }
}
