import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/health/domain/models/health_assessment.dart';
import 'package:chargex_vision/features/health/domain/services/health_assessment_calculator.dart';

const charger = ChargerModel(
  manufacturer: 'ABB',
  model: 'Terra',
  serialNumber: 'SN-100',
);
const component = DigitalTwinComponent(
  componentId: 'fan-01',
  componentType: 'Cooling Fan',
  displayName: 'Cooling Fan',
  assetNodeIdentifier: 'fan-node',
  description: 'Cooling assembly fan',
);

ComponentInspection inspection(
  InspectionStatus status, {
  DateTime? timestamp,
}) => ComponentInspection(
  component: component,
  status: status,
  timestamp: timestamp,
  statusMessage: 'Inspection result',
);

FaultResult fault(String id, String? severity, {DateTime? detectedAt}) =>
    FaultResult(
      faultType: 'Fan fault',
      componentId: id,
      componentDisplayName: id == 'fan-01' ? 'Cooling Fan' : 'Power Module',
      severity: severity,
      detectedAt: detectedAt,
    );

const calculator = HealthAssessmentCalculator();

void main() {
  test('no-fault inspection produces Healthy without a percentage', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.noFaultDetected),
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.healthy);
    expect(result.reason, contains('reported no fault'));
    expect(result.chargerIdentifier, 'SN-100');
  });

  test('warning severity maps to Warning and retains fault details', () {
    final detected = fault('fan-01', 'Warning');
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.completed),
      faults: [detected],
    );
    expect(result.status, ChargerHealthStatus.warning);
    expect(result.faults.single, detected);
    expect(result.inspectedComponent?.componentId, 'fan-01');
  });

  test('critical and high severity map to Critical', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.completed),
      faults: [fault('fan-01', 'High')],
    );
    expect(result.status, ChargerHealthStatus.critical);
  });

  test('multiple faults use the highest applicable severity', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.completed),
      faults: [fault('fan-01', 'Warning'), fault('power-01', 'Severe')],
    );
    expect(result.status, ChargerHealthStatus.critical);
    expect(result.faults, hasLength(2));
  });

  test('inspection or backend unavailable never becomes Healthy', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.serviceNotConnected),
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
    expect(result.reason, contains('unavailable'));
  });

  test('missing inspection data is unavailable', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: null,
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
  });

  test('no selected charger is unavailable', () {
    final result = calculator.assess(
      charger: null,
      inspectedChargerKey: null,
      inspection: null,
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
    expect(result.reason, contains('No charger'));
  });

  test('charger without serial/QR identifier is not falsely associated', () {
    final result = calculator.assess(
      charger: const ChargerModel(manufacturer: 'ABB', model: 'Terra'),
      inspectedChargerKey: null,
      inspection: inspection(InspectionStatus.noFaultDetected),
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
    expect(result.chargerIdentifier, isNull);
  });

  test('unrecognized severity remains unavailable', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.completed),
      faults: [fault('fan-01', 'Unclassified')],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
  });

  test('inspection associated with another charger remains unavailable', () {
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'qr:OTHER-CHARGER',
      inspection: inspection(InspectionStatus.noFaultDetected),
      faults: const [],
    );
    expect(result.status, ChargerHealthStatus.unavailable);
  });
  test('source timestamp uses an actual inspection or fault timestamp', () {
    final timestamp = DateTime.utc(2026, 3, 1);
    final result = calculator.assess(
      charger: charger,
      inspectedChargerKey: 'serial:SN-100',
      inspection: inspection(InspectionStatus.completed),
      faults: [fault('fan-01', 'Critical', detectedAt: timestamp)],
    );
    expect(result.sourceTimestamp, timestamp);
  });
}
