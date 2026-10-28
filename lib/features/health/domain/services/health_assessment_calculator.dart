import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

import '../models/health_assessment.dart';

/// Deterministically assesses health from an identified charger and real
/// inspection/fault state. Severity mapping: Critical/High/Severe/Emergency
/// => Critical; Warning/Medium/Low/Minor => Warning; unknown severities stay
/// unavailable. Healthy requires an explicit available no-fault inspection.
class HealthAssessmentCalculator {
  const HealthAssessmentCalculator();

  HealthAssessment assess({
    required ChargerModel? charger,
    required String? inspectedChargerKey,
    required ComponentInspection? inspection,
    required Iterable<FaultResult> faults,
  }) {
    final key = chargerIdentityKey(charger);
    if (charger == null) {
      return _unavailable('No charger is selected.');
    }
    if (key == null) {
      return _unavailable(
        'Health assessment unavailable because this charger has no serial or QR identifier.',
        charger: charger,
      );
    }
    if (inspectedChargerKey != key) {
      return _unavailable(
        'Health assessment unavailable because no inspection is associated with this charger.',
        charger: charger,
      );
    }

    final validInspection =
        inspection != null &&
        (inspection.status == InspectionStatus.noFaultDetected ||
            inspection.status == InspectionStatus.completed);
    if (!validInspection) {
      return _unavailable(
        'Health assessment unavailable because inspection or backend data is unavailable.',
        charger: charger,
      );
    }

    final relevantFaults = List<FaultResult>.unmodifiable(faults);
    DateTime? timestamp = inspection.timestamp;
    for (final fault in relevantFaults) {
      final faultTime = fault.detectedAt;
      if (faultTime != null &&
          (timestamp == null || faultTime.isAfter(timestamp))) {
        timestamp = faultTime;
      }
    }

    if (relevantFaults.isEmpty) {
      if (inspection.status != InspectionStatus.noFaultDetected) {
        return _unavailable(
          'Health assessment unavailable because the inspection did not include a fault result or an explicit no-fault result.',
          charger: charger,
          inspectedComponent: inspection.component,
          sourceTimestamp: timestamp,
        );
      }
      return HealthAssessment(
        status: ChargerHealthStatus.healthy,
        charger: charger,
        inspectedComponent: inspection.component,
        sourceTimestamp: timestamp,
        reason: 'The available inspection reported no fault.',
      );
    }

    final ranks = relevantFaults.map(_severityRank).toList();
    final highest = ranks.reduce((a, b) => a > b ? a : b);
    if (highest == 2) {
      return HealthAssessment(
        status: ChargerHealthStatus.critical,
        charger: charger,
        faults: relevantFaults,
        inspectedComponent: inspection.component,
        sourceTimestamp: timestamp,
        reason:
            'One or more detected faults have Critical, High, Severe, or Emergency severity.',
      );
    }
    if (highest == 1) {
      return HealthAssessment(
        status: ChargerHealthStatus.warning,
        charger: charger,
        faults: relevantFaults,
        inspectedComponent: inspection.component,
        sourceTimestamp: timestamp,
        reason:
            'One or more detected faults have Warning, Medium, Low, or Minor severity.',
      );
    }
    return _unavailable(
      'Health assessment unavailable because detected fault severity is missing or unrecognized.',
      charger: charger,
      faults: relevantFaults,
      inspectedComponent: inspection.component,
      sourceTimestamp: timestamp,
    );
  }

  int _severityRank(FaultResult fault) {
    final value = fault.severity?.trim().toLowerCase();
    if (value == null || value.isEmpty) return 0;
    if ({'critical', 'high', 'severe', 'emergency'}.contains(value)) return 2;
    if ({'warning', 'medium', 'low', 'minor'}.contains(value)) return 1;
    return 0;
  }

  HealthAssessment _unavailable(
    String reason, {
    ChargerModel? charger,
    List<FaultResult> faults = const [],
    DigitalTwinComponent? inspectedComponent,
    DateTime? sourceTimestamp,
  }) => HealthAssessment(
    status: ChargerHealthStatus.unavailable,
    reason: reason,
    charger: charger,
    faults: faults,
    inspectedComponent: inspectedComponent,
    sourceTimestamp: sourceTimestamp,
  );
}
