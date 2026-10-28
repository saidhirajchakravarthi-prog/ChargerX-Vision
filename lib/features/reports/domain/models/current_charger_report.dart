import '../../../chargers/domain/models/charger_model.dart';
import '../../../health/domain/models/health_assessment.dart';
import '../../../inspection/domain/models/component_inspection.dart';
import '../../../inspection/domain/models/fault_result.dart';
import '../../../maintenance/domain/models/maintenance_readiness.dart';

enum ReportSectionStatus {
  available,
  noCurrentData,
  noActiveItems,
  unavailable,
}

enum MaintenanceReportStatus { available, noRecords, unavailable }

class ChargerIdentitySnapshot {
  const ChargerIdentitySnapshot({
    required this.hasUniqueIdentity,
    this.identifier,
    this.manufacturer,
    this.model,
    this.type,
  });

  final bool hasUniqueIdentity;
  final String? identifier;
  final String? manufacturer;
  final String? model;
  final String? type;

  factory ChargerIdentitySnapshot.fromCharger(ChargerModel? charger) {
    final serial = charger?.serialNumber?.trim();
    final qr = charger?.rawQrIdentifier?.trim();
    final identifier = serial != null && serial.isNotEmpty
        ? serial
        : qr != null && qr.isNotEmpty
        ? qr
        : null;
    return ChargerIdentitySnapshot(
      hasUniqueIdentity: identifier != null,
      identifier: identifier,
      manufacturer: charger?.manufacturer,
      model: charger?.model,
      type: charger?.type,
    );
  }
}

class InspectionReportSection {
  const InspectionReportSection({
    required this.status,
    this.inspection,
    this.message,
  });

  final ReportSectionStatus status;
  final ComponentInspection? inspection;
  final String? message;
}

class FaultReportSection {
  const FaultReportSection({
    required this.status,
    this.faults = const [],
    this.message,
  });

  final ReportSectionStatus status;
  final List<FaultResult> faults;
  final String? message;
}

class HealthReportSection {
  const HealthReportSection({
    required this.status,
    this.assessment,
    this.message,
  });

  final ReportSectionStatus status;
  final HealthAssessment? assessment;
  final String? message;
}

class MaintenanceReportSection {
  const MaintenanceReportSection({
    required this.status,
    this.records = const [],
    this.message,
  });

  final MaintenanceReportStatus status;
  final List<MaintenanceRecord> records;
  final String? message;
}

/// Report-ready data from the current application state only. It deliberately
/// has no report ID, generated timestamp, history collection, or trend fields.
class CurrentChargerReport {
  const CurrentChargerReport({
    required this.charger,
    required this.inspection,
    required this.faults,
    required this.health,
    required this.maintenance,
    required this.rulMessage,
  });

  final ChargerIdentitySnapshot charger;
  final InspectionReportSection inspection;
  final FaultReportSection faults;
  final HealthReportSection health;
  final MaintenanceReportSection maintenance;
  final String rulMessage;
}
