// lib/features/inspection/data/adapters/default_fault_detection_adapter.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import '../../domain/adapters/fault_detection_adapter.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';
import '../../domain/models/charger_component_key.dart';

class DefaultFaultDetectionAdapter
    implements FaultDetectionAdapter, InspectionAnalysisAdapter {
  final bool _connected;
  final Map<ChargerComponentKey, FaultResult> _registeredRealFaults = {};
  final Map<ChargerComponentKey, ComponentInspection>
  _registeredRealInspections = {};

  ChargerComponentKey _key(ChargerModel? charger, String componentId) =>
      chargerComponentKey(chargerIdentityKey(charger) ?? '', componentId);

  DefaultFaultDetectionAdapter({bool isConnected = false})
    : _connected = isConnected;

  @override
  bool get isConnected => _connected;

  /// Injects a REAL fault result received from a real hardware sensor,
  /// thermal image, camera/YOLO, electrical measurement, diagnostic, or backend AI payload.
  void registerRealFaultResult(FaultResult fault, {ChargerModel? charger}) {
    _registeredRealFaults[_key(charger, fault.componentId)] = fault;
  }

  /// Injects a REAL completed component inspection.
  void registerRealInspection(
    ComponentInspection inspection, {
    ChargerModel? charger,
  }) {
    _registeredRealInspections[_key(
          charger,
          inspection.component.componentId,
        )] =
        inspection;
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
    ChargerModel? charger,
  }) async {
    if (!_connected) {
      return null;
    }

    // Check registered real faults for this component
    final key = _key(charger, componentId);
    if (_registeredRealFaults.containsKey(key)) {
      final existingFault = _registeredRealFaults[key]!;
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

    // Evidence is input to an analyzer, not a detection result.
    return null;
  }

  @override
  Future<FaultResult?> fetchActiveFaultForComponent(
    String componentId, {
    ChargerModel? charger,
  }) async {
    return _registeredRealFaults[_key(charger, componentId)];
  }

  @override
  Future<List<FaultResult>> fetchAllActiveFaults() async {
    return _registeredRealFaults.values.toList();
  }

  @override
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
    ChargerModel? charger,
  }) async {
    final key = _key(charger, component.componentId);
    if (_registeredRealInspections.containsKey(key)) {
      return _registeredRealInspections[key]!;
    }

    final activeFault = await detectFault(
      componentId: component.componentId,
      evidenceList: evidence != null ? [evidence] : const [],
      charger: charger,
    );

    if (activeFault != null) {
      return ComponentInspection.completed(
        component: component,
        evidenceSource:
            evidence ??
            (activeFault.evidenceSources.isNotEmpty
                ? activeFault.evidenceSources.first
                : EvidenceSourceData.none),
        detectedCondition: activeFault.faultType,
        confidence: activeFault.confidence,
        severity: activeFault.severity,
        timestamp: activeFault.detectedAt,
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
