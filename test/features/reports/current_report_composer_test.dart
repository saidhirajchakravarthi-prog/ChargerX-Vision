import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/health/domain/models/health_assessment.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/domain/models/charger_component_key.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';
import 'package:chargex_vision/features/reports/domain/models/current_charger_report.dart';
import 'package:chargex_vision/features/reports/domain/services/current_report_composer.dart';

const composer = CurrentReportComposer();
const charger = ChargerModel(
  serialNumber: 'S-1',
  manufacturer: 'Maker',
  model: 'M1',
);
const component = DigitalTwinComponent(
  componentId: 'fan-1',
  componentType: 'fan',
  displayName: 'Cooling fan',
  assetNodeIdentifier: 'node-1',
  description: 'Fan component',
);

MaintenanceReadiness maintenance(String id) =>
    MaintenanceReadiness.notConfigured(chargerIdentifier: id);

HealthAssessment health(ChargerModel value) => HealthAssessment(
  status: ChargerHealthStatus.healthy,
  reason: 'Current inspection reported no fault.',
  charger: value,
);

void main() {
  test('current no-fault inspection preserves absent timestamp as absent', () {
    final inspection = ComponentInspection.noFaultDetected(
      component: component,
      evidenceSource: EvidenceSourceData.none,
    );
    final report = composer.compose(
      charger: charger,
      inspectedChargerKey: 'serial:S-1',
      currentInspection: inspection,
      activeFaults: const {},
      healthAssessment: health(charger),
      maintenanceReadiness: maintenance('S-1'),
    );
    expect(report.charger.identifier, 'S-1');
    expect(report.charger.manufacturer, 'Maker');
    expect(report.inspection.status, ReportSectionStatus.available);
    expect(report.inspection.inspection?.timestamp, isNull);
    expect(report.faults.status, ReportSectionStatus.noActiveItems);
    expect(report.health.status, ReportSectionStatus.available);
    expect(report.maintenance.status, MaintenanceReportStatus.unavailable);
    expect(report.maintenance.records, isEmpty);
    expect(report.rulMessage, contains('unavailable'));
  });

  test(
    'only selected charger faults are included with optional fields intact',
    () {
      const selectedFault = FaultResult(
        faultType: 'overheating',
        componentId: 'fan-1',
        severity: 'Warning',
      );
      const otherFault = FaultResult(
        faultType: 'cable wear',
        componentId: 'fan-1',
        severity: 'Critical',
        locationDescription: 'Connector',
      );
      final inspection = ComponentInspection.completed(
        component: component,
        evidenceSource: EvidenceSourceData.none,
        detectedCondition: 'overheating',
      );
      final report = composer.compose(
        charger: charger,
        inspectedChargerKey: 'serial:S-1',
        currentInspection: inspection,
        activeFaults: {
          chargerComponentKey('serial:S-1', 'fan-1'): selectedFault,
          chargerComponentKey('serial:S-2', 'fan-1'): otherFault,
        },
        healthAssessment: health(charger),
        maintenanceReadiness: maintenance('S-1'),
      );
      expect(report.faults.status, ReportSectionStatus.available);
      expect(report.faults.faults, [selectedFault]);
      expect(report.faults.faults.single.detectedAt, isNull);
      expect(report.faults.faults.single.locationDescription, isNull);
    },
  );

  test(
    'no-fault result for one component does not hide another active fault',
    () {
      const chargerFault = FaultResult(
        faultType: 'cable wear',
        componentId: 'cable-1',
        severity: 'Warning',
      );
      final report = composer.compose(
        charger: charger,
        inspectedChargerKey: 'serial:S-1',
        currentInspection: ComponentInspection.noFaultDetected(
          component: component,
          evidenceSource: EvidenceSourceData.none,
        ),
        activeFaults: {
          chargerComponentKey('serial:S-1', 'cable-1'): chargerFault,
        },
        healthAssessment: health(charger),
        maintenanceReadiness: maintenance('S-1'),
      );
      expect(report.faults.status, ReportSectionStatus.available);
      expect(report.faults.faults.single.componentId, 'cable-1');
    },
  );
  test(
    'other charger fault with same component ID is excluded after no-fault',
    () {
      final report = composer.compose(
        charger: charger,
        inspectedChargerKey: 'serial:S-1',
        currentInspection: ComponentInspection.noFaultDetected(
          component: component,
          evidenceSource: EvidenceSourceData.none,
        ),
        activeFaults: {
          chargerComponentKey('serial:S-2', 'fan-1'): const FaultResult(
            faultType: 'other charger fault',
            componentId: 'fan-1',
          ),
        },
        healthAssessment: health(charger),
        maintenanceReadiness: maintenance('S-1'),
      );

      expect(report.faults.status, ReportSectionStatus.noActiveItems);
      expect(report.faults.faults, isEmpty);
    },
  );

  test('another charger inspection and health cannot enter this report', () {
    final inspection = ComponentInspection.completed(
      component: component,
      evidenceSource: EvidenceSourceData.none,
      detectedCondition: 'fault',
    );
    final report = composer.compose(
      charger: charger,
      inspectedChargerKey: 'serial:S-2',
      currentInspection: inspection,
      activeFaults: const {},
      healthAssessment: health(const ChargerModel(serialNumber: 'S-2')),
      maintenanceReadiness: maintenance('S-2'),
    );
    expect(report.inspection.status, ReportSectionStatus.unavailable);
    expect(report.inspection.inspection, isNull);
    expect(report.faults.status, ReportSectionStatus.unavailable);
    expect(report.health.status, ReportSectionStatus.unavailable);
    expect(report.maintenance.status, MaintenanceReportStatus.unavailable);
  });

  test('missing unique identity and unavailable health stay unavailable', () {
    final noUniqueId = const ChargerModel(manufacturer: 'Maker', model: 'M1');
    final report = composer.compose(
      charger: noUniqueId,
      inspectedChargerKey: null,
      currentInspection: null,
      activeFaults: const {},
      healthAssessment: const HealthAssessment(
        status: ChargerHealthStatus.unavailable,
        reason: 'Missing inspection.',
      ),
      maintenanceReadiness: MaintenanceReadiness.missingChargerIdentity(),
    );
    expect(report.charger.hasUniqueIdentity, isFalse);
    expect(report.charger.identifier, isNull);
    expect(report.inspection.status, ReportSectionStatus.noCurrentData);
    expect(report.faults.status, ReportSectionStatus.unavailable);
    expect(report.health.status, ReportSectionStatus.unavailable);
    expect(report.maintenance.status, MaintenanceReportStatus.unavailable);
  });

  test(
    'real matching maintenance records are kept; no RUL value is modeled',
    () {
      final maintenanceData = MaintenanceReadiness.fromJson({
        'status': 'available',
        'chargerIdentifier': 'S-1',
        'records': [
          {'recordId': 'real-id', 'recordType': 'inspection'},
        ],
      }, requestedChargerIdentifier: 'S-1');
      final report = composer.compose(
        charger: charger,
        inspectedChargerKey: null,
        currentInspection: null,
        activeFaults: const {},
        healthAssessment: const HealthAssessment(
          status: ChargerHealthStatus.unavailable,
          reason: 'No inspection.',
        ),
        maintenanceReadiness: maintenanceData,
      );
      expect(report.maintenance.status, MaintenanceReportStatus.available);
      expect(report.maintenance.records.single.recordId, 'real-id');
      expect(report.rulMessage, contains('RUL data unavailable'));
      expect(report.toString(), isNot(contains('remainingUsefulLife')));
    },
  );
}
