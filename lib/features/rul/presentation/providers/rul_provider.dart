import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

import '../../data/repositories/dio_rul_repository.dart';
import '../../domain/models/rul_analysis_request.dart';
import '../../domain/models/rul_analysis_response.dart';
import '../../domain/models/rul_assessment.dart';
import '../../domain/repositories/rul_repository.dart';

final rulDioProvider = Provider<Dio>((ref) => Dio());

final rulRepositoryProvider = Provider<RulRepository>((ref) {
  const requiresAuth = bool.fromEnvironment(
    'CHARGEX_RUL_API_REQUIRE_FIREBASE_AUTH',
  );
  return DioRulRepository(
    dio: ref.watch(rulDioProvider),
    requireAuthentication: requiresAuth,
    idTokenProvider: requiresAuth
        ? () async => await FirebaseAuth.instance.currentUser?.getIdToken()
        : null,
  );
});

/// AsyncValue provides loading and unexpected-error states. Expected backend
/// and data-readiness states are returned as typed RulAssessment statuses.
final rulAssessmentProvider = FutureProvider<RulAssessment>((ref) async {
  final charger = ref.watch(selectedChargerProvider);
  final inspectionState = ref.watch(componentInspectionProvider);
  final repository = ref.watch(rulRepositoryProvider);

  await Future<void>.delayed(Duration.zero);

  final identifier = chargerIdentifierValue(charger);
  if (charger == null) {
    return RulAssessment.insufficientData(
      reason:
          'No charger is selected. Identify a charger to check RUL readiness.',
    );
  }
  if (identifier == null) {
    return RulAssessment.insufficientData(
      reason:
          'RUL unavailable - insufficient real operational data. This charger has no serial number or QR identifier.',
      charger: charger,
    );
  }

  final chargerKey = chargerIdentityKey(charger);
  final inspectionMatches =
      chargerKey != null &&
      inspectionState.currentInspectionChargerKey == chargerKey;
  final inspection = inspectionMatches
      ? inspectionState.currentInspection
      : null;
  final component = inspection?.component;
  final faults = inspectionState.faultsForCharger(chargerKey).values.toList();

  final request = RulAnalysisRequest.fromAvailableData(
    charger: charger,
    chargerIdentifier: identifier,
    component: component,
    inspection: inspection,
    faults: faults,
  );
  final response = await repository.analyze(request);
  switch (response.outcome) {
    case RulResponseOutcome.available:
      final assessment = response.assessment;
      if (assessment == null || !assessment.hasRulValue) {
        return RulAssessment.error(
          charger: charger,
          chargerIdentifier: identifier,
          reason: 'RUL backend returned an incomplete result.',
        );
      }
      return assessment.copyWithContext(
        charger: charger,
        faultContext: faults,
        inspectedComponent: component,
      );
    case RulResponseOutcome.insufficientData:
      return response.assessment ??
          RulAssessment.insufficientData(
            charger: charger,
            chargerIdentifier: identifier,
            reason:
                response.message ??
                'Backend reports insufficient data for RUL.',
            inspectedComponent: component,
            faultContext: faults,
          );
    case RulResponseOutcome.unavailable:
      return response.assessment ??
          RulAssessment.unavailable(
            charger: charger,
            chargerIdentifier: identifier,
            reason: response.message ?? 'RUL backend is unavailable.',
          );
    case RulResponseOutcome.backendError:
    case RulResponseOutcome.malformedResponse:
      return RulAssessment.error(
        charger: charger,
        chargerIdentifier: identifier,
        reason:
            response.message ?? 'RUL backend could not provide a valid result.',
      );
  }
});
