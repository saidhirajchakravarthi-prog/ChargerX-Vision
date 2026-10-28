import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chargers/domain/models/charger_identity.dart';
import '../../../chargers/presentation/providers/selected_charger_provider.dart';
import '../../../inspection/presentation/providers/component_inspection_provider.dart';
import '../../data/repositories/dio_maintenance_repository.dart';
import '../../domain/models/maintenance_readiness.dart';
import '../../domain/repositories/maintenance_repository.dart';

final maintenanceDioProvider = Provider<Dio>((ref) => Dio());

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  const requiresAuth = bool.fromEnvironment(
    'CHARGEX_MAINTENANCE_API_REQUIRE_FIREBASE_AUTH',
  );
  return DioMaintenanceRepository(
    dio: ref.watch(maintenanceDioProvider),
    requireAuthentication: requiresAuth,
    idTokenProvider: requiresAuth
        ? () async => await FirebaseAuth.instance.currentUser?.getIdToken()
        : null,
  );
});

/// Loads only selected-charger records and filters recommendations to real
/// faults associated with that charger's serial/QR identity.
final maintenanceReadinessProvider = FutureProvider<MaintenanceReadiness>((
  ref,
) async {
  final charger = ref.watch(selectedChargerProvider);
  final inspection = ref.watch(componentInspectionProvider);
  final repository = ref.watch(maintenanceRepositoryProvider);

  await Future<void>.delayed(Duration.zero);
  final identifier = chargerIdentifierValue(charger);
  if (charger == null || identifier == null) {
    return MaintenanceReadiness.missingChargerIdentity();
  }

  final chargerKey = chargerIdentityKey(charger);
  final recommendations = inspection
      .faultsForCharger(chargerKey)
      .values
      .where((fault) => fault.recommendation?.trim().isNotEmpty == true)
      .map(FaultAnalysisRecommendation.fromFault)
      .toList(growable: false);

  final result = await repository.fetchForCharger(
    identifier,
    faultRecommendations: recommendations,
  );
  // Recheck identity after the asynchronous request so a response cannot be
  // exposed under a different currently selected charger.
  if (chargerIdentityKey(ref.read(selectedChargerProvider)) != chargerKey) {
    return MaintenanceReadiness.missingChargerIdentity();
  }
  if (result.chargerIdentifier != null &&
      result.chargerIdentifier != identifier) {
    return MaintenanceReadiness.error(
      chargerIdentifier: identifier,
      message: 'Maintenance response did not match the selected charger.',
      faultRecommendations: recommendations,
    );
  }
  return result;
});
