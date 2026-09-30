// lib/features/inspection/domain/adapters/fault_detection_adapter.dart

import 'inspection_analysis_adapter.dart';
import '../models/evidence_source.dart';
import '../models/fault_result.dart';

abstract class FaultDetectionAdapter implements InspectionAnalysisAdapter {
  /// Whether the fault detection AI or sensor backend is connected.
  @override
  bool get isConnected;

  /// Detects faults for a target component using REAL evidence provided.
  /// Returns null if no fault is identified or if evidence is unavailable.
  Future<FaultResult?> detectFault({
    required String componentId,
    List<EvidenceSourceData> evidenceList = const [],
  });

  /// Retrieves active fault for a component if registered by a real evidence pipeline.
  @override
  Future<FaultResult?> fetchActiveFaultForComponent(String componentId);

  /// Retrieves all active component faults across the digital twin.
  Future<List<FaultResult>> fetchAllActiveFaults();
}
