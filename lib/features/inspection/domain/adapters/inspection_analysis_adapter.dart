// lib/features/inspection/domain/adapters/inspection_analysis_adapter.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import '../models/component_inspection.dart';
import '../models/evidence_source.dart';
import '../models/fault_result.dart';

abstract class InspectionAnalysisAdapter {
  /// Whether a real backend AI or physical sensor analysis service is currently connected.
  bool get isConnected;

  /// Inspect a digital twin component.
  /// If connected and provided with real evidence, returns a real [ComponentInspection].
  /// Otherwise, returns a clean serviceNotConnected or unavailable result.
  Future<ComponentInspection> inspectComponent(
    DigitalTwinComponent component, {
    EvidenceSourceData? evidence,
    ChargerModel? charger,
  });

  /// Retrieve active [FaultResult] for a specific component if a real backend result exists.
  Future<FaultResult?> fetchActiveFaultForComponent(
    String componentId, {
    ChargerModel? charger,
  });
}
