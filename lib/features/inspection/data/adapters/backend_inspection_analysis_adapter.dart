import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';

import '../../domain/adapters/fault_detection_adapter.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_analysis_request.dart';
import '../../domain/models/fault_analysis_response.dart';
import '../../domain/models/fault_result.dart';
import '../../domain/models/charger_component_key.dart';
import '../repositories/fault_analysis_repository.dart';

/// Bridges the configured real API to the existing inspection and Twin flow.
class BackendInspectionAnalysisAdapter implements FaultDetectionAdapter {
  BackendInspectionAnalysisAdapter(this._repository);

  final FaultAnalysisRepository _repository;
  final Map<ChargerComponentKey, FaultResult> _activeFaults = {};

  ChargerComponentKey _key(ChargerModel? charger, String componentId) =>
      chargerComponentKey(chargerIdentityKey(charger) ?? '', componentId);

  @override
  bool get isConnected => _repository.isConfigured;

  @override
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
    ChargerModel? charger,
  }) async {
    final response = await _repository.analyze(
      FaultAnalysisRequest.forComponent(
        component: component,
        charger: charger,
        evidence: evidence,
      ),
    );
    return _toInspection(component, response, evidence, charger);
  }

  ComponentInspection _toInspection(
    DigitalTwinComponent component,
    FaultAnalysisResponse response,
    EvidenceSourceData? evidence,
    ChargerModel? charger,
  ) {
    final id = component.componentId;
    final key = _key(charger, id);
    switch (response.outcome) {
      case FaultAnalysisOutcome.faultDetected:
        final fault = response.faultResult;
        if (fault == null || fault.componentId != id) {
          _activeFaults.remove(key);
          return ComponentInspection.failed(
            component,
            'The analysis service returned a result for a different component.',
          );
        }
        _activeFaults[key] = fault;
        return ComponentInspection.completed(
          component: component,
          evidenceSource:
              evidence ??
              (fault.evidenceSources.isNotEmpty
                  ? fault.evidenceSources.first
                  : EvidenceSourceData.none),
          detectedCondition: fault.faultType,
          confidence: fault.confidence,
          severity: fault.severity,
          timestamp: fault.detectedAt,
          evidenceMetadata: {
            'evidence': fault.evidence,
            if (fault.locationDescription != null)
              'locationDescription': fault.locationDescription,
          },
        );
      case FaultAnalysisOutcome.noFaultDetected:
        _activeFaults.remove(key);
        return ComponentInspection.noFaultDetected(
          component: component,
          evidenceSource: evidence ?? EvidenceSourceData.none,
        );
      case FaultAnalysisOutcome.unavailable:
      case FaultAnalysisOutcome.backendUnavailable:
        _activeFaults.remove(key);
        return ComponentInspection.unavailable(
          component,
          message: response.message,
        );
      case FaultAnalysisOutcome.invalidRequest:
      case FaultAnalysisOutcome.backendError:
        _activeFaults.remove(key);
        return ComponentInspection.failed(
          component,
          response.message ??
              'The analysis service could not complete the request.',
        );
    }
  }

  @override
  Future<FaultResult?> detectFault({
    required String componentId,
    List<EvidenceSourceData> evidenceList = const [],
    ChargerModel? charger,
  }) async {
    final response = await _repository.analyze(
      FaultAnalysisRequest(
        componentId: componentId,
        evidence: evidenceList.isEmpty ? null : evidenceList.first,
        charger: charger,
      ),
    );
    final fault = response.faultResult;
    if (response.outcome != FaultAnalysisOutcome.faultDetected ||
        fault == null ||
        fault.componentId != componentId) {
      _activeFaults.remove(_key(charger, componentId));
      return null;
    }
    _activeFaults[_key(charger, componentId)] = fault;
    return fault;
  }

  @override
  Future<FaultResult?> fetchActiveFaultForComponent(
    String componentId, {
    ChargerModel? charger,
  }) async => _activeFaults[_key(charger, componentId)];

  @override
  Future<List<FaultResult>> fetchAllActiveFaults() async =>
      _activeFaults.values.toList(growable: false);
}
