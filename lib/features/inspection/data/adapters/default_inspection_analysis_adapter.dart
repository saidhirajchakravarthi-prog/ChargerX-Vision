// lib/features/inspection/data/adapters/default_inspection_analysis_adapter.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';
import '../../domain/models/charger_component_key.dart';

class DefaultInspectionAnalysisAdapter implements InspectionAnalysisAdapter {
  final bool _connected;
  final Map<ChargerComponentKey, FaultResult> _realFaults = {};
  final Map<ChargerComponentKey, ComponentInspection> _realInspections = {};

  ChargerComponentKey _key(ChargerModel? charger, String componentId) =>
      chargerComponentKey(chargerIdentityKey(charger) ?? '', componentId);

  DefaultInspectionAnalysisAdapter({bool isConnected = false})
    : _connected = isConnected;

  @override
  bool get isConnected => _connected;

  /// Injects a real fault result received from camera image analysis, AI/YOLO,
  /// thermal, electrical, IoT/ESP32, or backend service.
  void registerRealFaultResult(FaultResult fault, {ChargerModel? charger}) {
    _realFaults[_key(charger, fault.componentId)] = fault;
  }

  /// Injects a real completed component inspection from an external real pipeline.
  void registerRealInspection(
    ComponentInspection inspection, {
    ChargerModel? charger,
  }) {
    _realInspections[_key(charger, inspection.component.componentId)] =
        inspection;
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
    ChargerModel? charger,
  }) async {
    // If a real inspection result was registered for this component, return it.
    final key = _key(charger, component.componentId);
    if (_realInspections.containsKey(key)) {
      return _realInspections[key]!;
    }

    // If a real fault was registered for this component, construct a completed inspection.
    if (_realFaults.containsKey(key)) {
      final fault = _realFaults[key]!;
      return ComponentInspection.completed(
        component: component,
        evidenceSource: evidence ?? EvidenceSourceData.none,
        detectedCondition: fault.faultType,
        confidence: fault.confidence,
        severity: fault.severity,
        timestamp: fault.detectedAt,
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
  Future<FaultResult?> fetchActiveFaultForComponent(
    String componentId, {
    ChargerModel? charger,
  }) async {
    return _realFaults[_key(charger, componentId)];
  }
}
