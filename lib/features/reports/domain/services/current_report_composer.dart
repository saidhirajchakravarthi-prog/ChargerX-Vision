import '../../../chargers/domain/models/charger_identity.dart';
import '../../../chargers/domain/models/charger_model.dart';
import '../../../health/domain/models/health_assessment.dart';
import '../../../inspection/domain/models/component_inspection.dart';
import '../../../inspection/domain/models/fault_result.dart';
import '../../../inspection/domain/models/charger_component_key.dart';
import '../../../maintenance/domain/models/maintenance_readiness.dart';
import '../models/current_charger_report.dart';

class CurrentReportComposer {
  const CurrentReportComposer();

  CurrentChargerReport compose({
    required ChargerModel? charger,
    required String? inspectedChargerKey,
    required ComponentInspection? currentInspection,
    required Map<ChargerComponentKey, FaultResult> activeFaults,
    required HealthAssessment healthAssessment,
    required MaintenanceReadiness maintenanceReadiness,
  }) {
    final identity = ChargerIdentitySnapshot.fromCharger(charger);
    final chargerKey = chargerIdentityKey(charger);
    final chargerId = chargerIdentifierValue(charger);
    final inspectionMatches =
        chargerKey != null && inspectedChargerKey == chargerKey;
    final scopedInspection = inspectionMatches ? currentInspection : null;
    final inspectionValid =
        scopedInspection != null &&
        (scopedInspection.status == InspectionStatus.completed ||
            scopedInspection.status == InspectionStatus.noFaultDetected);

    final InspectionReportSection inspectionSection;
    if (scopedInspection == null) {
      inspectionSection = InspectionReportSection(
        status: currentInspection == null
            ? ReportSectionStatus.noCurrentData
            : ReportSectionStatus.unavailable,
        message: currentInspection == null
            ? 'No current charger-associated inspection is available.'
            : 'Current inspection belongs to another charger.',
      );
    } else if (inspectionValid) {
      inspectionSection = InspectionReportSection(
        status: ReportSectionStatus.available,
        inspection: scopedInspection,
      );
    } else {
      inspectionSection = InspectionReportSection(
        status: ReportSectionStatus.unavailable,
        message: scopedInspection.statusMessage,
      );
    }

    final scopedFaults = chargerKey == null
        ? const <FaultResult>[]
        : activeFaults.entries
              .where(
                (entry) =>
                    entry.key.chargerKey == chargerKey &&
                    entry.key.componentId == entry.value.componentId,
              )
              .map((entry) => entry.value)
              .toList(growable: false);
    final FaultReportSection faultSection;
    if (scopedFaults.isNotEmpty) {
      faultSection = FaultReportSection(
        status: ReportSectionStatus.available,
        faults: List.unmodifiable(scopedFaults),
      );
    } else if (inspectionMatches &&
        scopedInspection?.status == InspectionStatus.noFaultDetected) {
      faultSection = const FaultReportSection(
        status: ReportSectionStatus.noActiveItems,
        message: 'No current active faults are available for this snapshot.',
      );
    } else {
      faultSection = const FaultReportSection(
        status: ReportSectionStatus.unavailable,
        message: 'Current charger-associated fault data is unavailable.',
      );
    }
    final healthMatches =
        chargerKey != null &&
        chargerIdentityKey(healthAssessment.charger) == chargerKey &&
        healthAssessment.chargerIdentifier == chargerId;
    final healthSection = healthMatches && healthAssessment.isAvailable
        ? HealthReportSection(
            status: ReportSectionStatus.available,
            assessment: healthAssessment,
          )
        : HealthReportSection(
            status: ReportSectionStatus.unavailable,
            message: healthMatches
                ? healthAssessment.reason
                : 'Current health assessment is unavailable for this charger.',
          );

    final maintenanceMatches =
        chargerId != null &&
        maintenanceReadiness.chargerIdentifier == chargerId;
    final MaintenanceReportSection maintenanceSection;
    if (maintenanceMatches &&
        maintenanceReadiness.status ==
            MaintenanceReadinessStatus.recordsAvailable) {
      maintenanceSection = MaintenanceReportSection(
        status: MaintenanceReportStatus.available,
        records: List.unmodifiable(maintenanceReadiness.records),
      );
    } else if (maintenanceMatches &&
        maintenanceReadiness.status == MaintenanceReadinessStatus.noRecords) {
      maintenanceSection = const MaintenanceReportSection(
        status: MaintenanceReportStatus.noRecords,
        message: 'No maintenance records were returned for this charger.',
      );
    } else {
      maintenanceSection = MaintenanceReportSection(
        status: MaintenanceReportStatus.unavailable,
        message:
            maintenanceReadiness.status ==
                MaintenanceReadinessStatus.notConfigured
            ? 'Maintenance data unavailable; no maintenance service is configured.'
            : 'Maintenance data unavailable for this charger.',
      );
    }

    return CurrentChargerReport(
      charger: identity,
      inspection: inspectionSection,
      faults: faultSection,
      health: healthSection,
      maintenance: maintenanceSection,
      rulMessage:
          'RUL data unavailable in this snapshot; Phase 10 provides readiness only.',
    );
  }
}
