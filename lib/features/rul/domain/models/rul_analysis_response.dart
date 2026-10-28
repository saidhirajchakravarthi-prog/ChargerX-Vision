import '../../../chargers/domain/models/charger_model.dart';
import 'rul_analysis_request.dart';
import 'rul_assessment.dart';

enum RulResponseOutcome {
  available,
  insufficientData,
  unavailable,
  backendError,
  malformedResponse,
}

class RulAnalysisResponse {
  const RulAnalysisResponse({
    required this.outcome,
    this.assessment,
    this.message,
  });

  final RulResponseOutcome outcome;
  final RulAssessment? assessment;
  final String? message;

  factory RulAnalysisResponse.fromJson(
    Map<String, dynamic> json, {
    required RulAnalysisRequest request,
    ChargerModel? charger,
  }) {
    final status = json['status'];
    if (status is! String) {
      throw const FormatException('RUL response has no status.');
    }
    final message = json['message'];
    if (message != null && message is! String) {
      throw const FormatException('RUL response message is invalid.');
    }
    switch (status.toLowerCase()) {
      case 'insufficient_data':
      case 'insufficientdata':
        return RulAnalysisResponse(
          outcome: RulResponseOutcome.insufficientData,
          assessment: RulAssessment.insufficientData(
            chargerIdentifier: request.chargerIdentifier,
            charger: charger ?? request.charger,
            reason:
                message ?? 'The backend reported insufficient data for RUL.',
          ),
          message: message,
        );
      case 'unavailable':
      case 'backend_unavailable':
        return RulAnalysisResponse(
          outcome: RulResponseOutcome.unavailable,
          assessment: RulAssessment.unavailable(
            chargerIdentifier: request.chargerIdentifier,
            charger: charger ?? request.charger,
            reason: message ?? 'RUL service is unavailable.',
          ),
          message: message,
        );
      case 'error':
      case 'backend_error':
        return RulAnalysisResponse(
          outcome: RulResponseOutcome.backendError,
          message: message ?? 'RUL service returned an error.',
        );
      case 'available':
      case 'rul_available':
        return _parseAvailable(
          json,
          request: request,
          charger: charger ?? request.charger,
          message: message,
        );
      default:
        throw FormatException('Unknown RUL response status: $status');
    }
  }

  static RulAnalysisResponse _parseAvailable(
    Map<String, dynamic> json, {
    required RulAnalysisRequest request,
    ChargerModel? charger,
    String? message,
  }) {
    final raw = json['result'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException(
        'Available RUL response has no result object.',
      );
    }
    final chargerId = raw['chargerIdentifier'];
    if (chargerId is! String || chargerId.trim().isEmpty) {
      throw const FormatException('RUL result has no charger association.');
    }
    if (chargerId != request.chargerIdentifier) {
      throw const FormatException('RUL result belongs to a different charger.');
    }

    final componentId = raw['componentId'];
    if (componentId != null &&
        (componentId is! String || componentId.trim().isEmpty)) {
      throw const FormatException('RUL component association is invalid.');
    }
    if (request.componentId != null && componentId != request.componentId) {
      throw const FormatException(
        'RUL result belongs to a different component.',
      );
    }

    final value = raw['remainingUsefulLife'];
    if (value is! num || !value.toDouble().isFinite || value < 0) {
      throw const FormatException('RUL result has no valid RUL value.');
    }
    final unit = raw['unit'];
    if (unit is! String || unit.trim().isEmpty) {
      throw const FormatException('RUL result has no unit.');
    }
    final confidence = raw['confidence'];
    if (confidence != null &&
        (confidence is! num || !confidence.toDouble().isFinite)) {
      throw const FormatException('RUL confidence is invalid.');
    }

    String? optionalString(String key) {
      final item = raw[key];
      if (item != null && item is! String) {
        throw FormatException('RUL field $key must be a string.');
      }
      return item as String?;
    }

    DateTime? optionalTime(String key) {
      final item = raw[key];
      if (item == null) return null;
      if (item is! String) throw FormatException('RUL field $key is invalid.');
      final parsed = DateTime.tryParse(item);
      if (parsed == null) throw FormatException('RUL field $key is invalid.');
      return parsed;
    }

    return RulAnalysisResponse(
      outcome: RulResponseOutcome.available,
      message: message,
      assessment: RulAssessment.available(
        chargerIdentifier: chargerId,
        charger: charger ?? request.charger,
        componentId: componentId as String?,
        componentDisplayName: optionalString('componentDisplayName'),
        remainingUsefulLife: value.toDouble(),
        unit: unit,
        assessedAt: optionalTime('assessedAt'),
        horizonStart: optionalTime('horizonStart'),
        horizonEnd: optionalTime('horizonEnd'),
        modelName: optionalString('modelName'),
        modelVersion: optionalString('modelVersion'),
        confidence: (confidence as num?)?.toDouble(),
        reason:
            message ??
            optionalString('explanation') ??
            'RUL result supplied by backend.',
      ),
    );
  }
}
