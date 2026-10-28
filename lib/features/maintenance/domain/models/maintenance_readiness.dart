import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

enum MaintenanceReadinessStatus {
  recordsAvailable,
  noRecords,
  notConfigured,
  unavailable,
  missingChargerIdentity,
  error,
}

/// A maintenance record returned by the configured backend. Optional values
/// stay absent unless the backend supplied them.
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.recordId,
    required this.recordType,
    this.componentId,
    this.status,
    this.description,
    this.serviceDate,
    this.workOrderId,
    this.workOrderStatus,
    this.repairDetails,
    this.replacementDetails,
  });

  final String recordId;
  final String recordType;
  final String? componentId;
  final String? status;
  final String? description;
  final DateTime? serviceDate;
  final String? workOrderId;
  final String? workOrderStatus;
  final String? repairDetails;
  final String? replacementDetails;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Maintenance record $key is missing or invalid.');
      }
      return value.trim();
    }

    String? optionalText(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Maintenance record $key is invalid.');
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    DateTime? optionalDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Maintenance record $key is invalid.');
      }
      final date = DateTime.tryParse(value);
      if (date == null) {
        throw FormatException('Maintenance record $key is invalid.');
      }
      return date;
    }

    return MaintenanceRecord(
      recordId: requiredText('recordId'),
      recordType: requiredText('recordType'),
      componentId: optionalText('componentId'),
      status: optionalText('status'),
      description: optionalText('description'),
      serviceDate: optionalDate('serviceDate'),
      workOrderId: optionalText('workOrderId'),
      workOrderStatus: optionalText('workOrderStatus'),
      repairDetails: optionalText('repairDetails'),
      replacementDetails: optionalText('replacementDetails'),
    );
  }
}

/// Explicit recommendation originating in a real FaultResult. It is not a
/// maintenance record and contains no scheduled date or generated action.
class FaultAnalysisRecommendation {
  const FaultAnalysisRecommendation({
    required this.componentId,
    required this.faultType,
    required this.recommendation,
  });

  final String componentId;
  final String faultType;
  final String recommendation;

  factory FaultAnalysisRecommendation.fromFault(FaultResult fault) =>
      FaultAnalysisRecommendation(
        componentId: fault.componentId,
        faultType: fault.faultType,
        recommendation: fault.recommendation!.trim(),
      );
}

class MaintenanceReadiness {
  const MaintenanceReadiness._({
    required this.status,
    this.chargerIdentifier,
    this.records = const [],
    this.faultRecommendations = const [],
    this.message,
  });

  final MaintenanceReadinessStatus status;
  final String? chargerIdentifier;
  final List<MaintenanceRecord> records;
  final List<FaultAnalysisRecommendation> faultRecommendations;
  final String? message;

  factory MaintenanceReadiness.missingChargerIdentity() =>
      const MaintenanceReadiness._(
        status: MaintenanceReadinessStatus.missingChargerIdentity,
        message:
            'Maintenance data unavailable because charger identity is missing.',
      );

  factory MaintenanceReadiness.notConfigured({
    required String chargerIdentifier,
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) => MaintenanceReadiness._(
    status: MaintenanceReadinessStatus.notConfigured,
    chargerIdentifier: chargerIdentifier,
    faultRecommendations: List.unmodifiable(faultRecommendations),
    message: 'Maintenance service is not configured.',
  );

  factory MaintenanceReadiness.unavailable({
    required String chargerIdentifier,
    required String message,
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) => MaintenanceReadiness._(
    status: MaintenanceReadinessStatus.unavailable,
    chargerIdentifier: chargerIdentifier,
    faultRecommendations: List.unmodifiable(faultRecommendations),
    message: message,
  );

  factory MaintenanceReadiness.error({
    required String chargerIdentifier,
    required String message,
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) => MaintenanceReadiness._(
    status: MaintenanceReadinessStatus.error,
    chargerIdentifier: chargerIdentifier,
    faultRecommendations: List.unmodifiable(faultRecommendations),
    message: message,
  );

  factory MaintenanceReadiness.fromJson(
    Map<String, dynamic> json, {
    required String requestedChargerIdentifier,
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) {
    final responseIdentifier = json['chargerIdentifier'];
    if (responseIdentifier is! String || responseIdentifier.trim().isEmpty) {
      throw const FormatException(
        'Maintenance response has no charger identity.',
      );
    }
    if (responseIdentifier != requestedChargerIdentifier) {
      throw const FormatException(
        'Maintenance response belongs to another charger.',
      );
    }
    final responseStatus = json['status'];
    if (responseStatus is! String) {
      throw const FormatException('Maintenance response has no status.');
    }
    final message = json['message'];
    if (message != null && message is! String) {
      throw const FormatException('Maintenance response message is invalid.');
    }

    switch (responseStatus.toLowerCase()) {
      case 'available':
      case 'empty':
        final rawRecords = json['records'];
        if (rawRecords is! List) {
          throw const FormatException(
            'Maintenance response records are invalid.',
          );
        }
        final records = rawRecords
            .map((item) {
              if (item is! Map<String, dynamic>) {
                throw const FormatException('Maintenance record is invalid.');
              }
              return MaintenanceRecord.fromJson(item);
            })
            .toList(growable: false);
        return MaintenanceReadiness._(
          status: records.isEmpty
              ? MaintenanceReadinessStatus.noRecords
              : MaintenanceReadinessStatus.recordsAvailable,
          chargerIdentifier: requestedChargerIdentifier,
          records: List.unmodifiable(records),
          faultRecommendations: List.unmodifiable(faultRecommendations),
          message: message as String?,
        );
      case 'unavailable':
      case 'backend_unavailable':
        return MaintenanceReadiness.unavailable(
          chargerIdentifier: requestedChargerIdentifier,
          message:
              message as String? ??
              'Maintenance service is currently unavailable.',
          faultRecommendations: faultRecommendations,
        );
      case 'error':
      case 'backend_error':
        return MaintenanceReadiness.error(
          chargerIdentifier: requestedChargerIdentifier,
          message:
              message as String? ?? 'Maintenance service returned an error.',
          faultRecommendations: faultRecommendations,
        );
      default:
        throw FormatException(
          'Unknown maintenance response status: $responseStatus',
        );
    }
  }
}
