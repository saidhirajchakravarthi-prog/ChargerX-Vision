import 'fault_result.dart';

/// Outcomes understood from the fault-analysis endpoint, including failures.
enum FaultAnalysisOutcome {
  faultDetected,
  noFaultDetected,
  unavailable,
  backendUnavailable,
  invalidRequest,
  backendError,
}

class FaultAnalysisResponse {
  final FaultAnalysisOutcome outcome;
  final FaultResult? faultResult;
  final String? message;

  const FaultAnalysisResponse({
    required this.outcome,
    this.faultResult,
    this.message,
  });

  bool get isSuccessful =>
      outcome == FaultAnalysisOutcome.faultDetected ||
      outcome == FaultAnalysisOutcome.noFaultDetected;

  factory FaultAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final rawOutcome = json['status'];
    if (rawOutcome is! String) {
      throw const FormatException('Fault analysis response has no status.');
    }

    final outcome = switch (rawOutcome.toLowerCase()) {
      'fault_detected' || 'faultdetected' => FaultAnalysisOutcome.faultDetected,
      'no_fault_detected' ||
      'nofaultdetected' => FaultAnalysisOutcome.noFaultDetected,
      'unavailable' => FaultAnalysisOutcome.unavailable,
      'backend_unavailable' ||
      'backendunavailable' => FaultAnalysisOutcome.backendUnavailable,
      'invalid_request' ||
      'invalidrequest' => FaultAnalysisOutcome.invalidRequest,
      'backend_error' || 'backenderror' => FaultAnalysisOutcome.backendError,
      _ => throw FormatException('Unknown fault analysis status: $rawOutcome'),
    };

    FaultResult? fault;
    if (outcome == FaultAnalysisOutcome.faultDetected) {
      final rawFault = json['fault'];
      if (rawFault is! Map<String, dynamic>) {
        throw const FormatException(
          'Fault-detected response has no fault object.',
        );
      }
      fault = FaultResult.fromJson(rawFault);
    }

    return FaultAnalysisResponse(
      outcome: outcome,
      faultResult: fault,
      message: json['message'] as String?,
    );
  }
}
