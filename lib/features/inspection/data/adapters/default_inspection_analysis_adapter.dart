// lib/features/inspection/data/adapters/default_inspection_analysis_adapter.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';

class DefaultInspectionAnalysisAdapter implements InspectionAnalysisAdapter {
  final bool _connected;
  final Map<String, FaultResult> _realFaults = {};
  final Map<String, ComponentInspection> _realInspections = {};

  DefaultInspectionAnalysisAdapter({bool isConnected = false})
      : _connected = isConnected;

  @override
  bool get isConnected => _connected;

  /// Injects a real fault result received from camera image analysis, AI/YOLO,
  /// thermal, electrical, IoT/ESP32, or backend service.
  void registerRealFaultResult(FaultResult fault) {
    _realFaults[fault.componentId] = fault;
  }

  /// Injects a real completed component inspection from an external real pipeline.
  void registerRealInspection(ComponentInspection inspection) {
    _realInspections[inspection.component.componentId] = inspection;
  }

  /// Clears stored real results.
  void clearRealResults() {
    _realFaults.clear();
    _realInspections.clear();
  }

  @override
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
  }) async {
    // If a real inspection result was registered for this component, return it.
    if (_realInspections.containsKey(component.componentId)) {
      return _realInspections[component.componentId]!;
    }

    // If a real fault was registered for this component, construct a completed inspection.
    if (_realFaults.containsKey(component.componentId)) {
      final fault = _realFaults[component.componentId]!;
      return ComponentInspection.completed(
        component: component,
        evidenceSource: evidence ??
            EvidenceSourceData(
              type: EvidenceSourceType.backendAnalysis,
              label: 'Real Backend Analysis Evidence',
              timestamp: fault.detectedAt,
            ),
        detectedCondition: fault.faultType,
        confidence: fault.confidence ?? 1.0,
        severity: fault.severity ?? 'Medium',
        timestamp: fault.detectedAt ?? DateTime.now(),
        evidenceMetadata: {
          'evidenceList': fault.evidence,
          'locationDescription': fault.locationDescription,
        },
      );
    }

    // When no real backend/AI is connected, return serviceNotConnected
    if (!_connected) {
      return ComponentInspection.serviceNotConnected(component);
    }

    // If connected but no real evidence or fault is found, return unavailable.
    return ComponentInspection.unavailable(component);
  }

  @override
  Future<FaultResult?> fetchActiveFaultForComponent(String componentId) async {
    return _realFaults[componentId];
  }
}
