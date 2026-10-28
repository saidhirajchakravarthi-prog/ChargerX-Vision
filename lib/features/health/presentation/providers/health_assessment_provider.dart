import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

import '../../domain/models/health_assessment.dart';
import '../../domain/services/health_assessment_calculator.dart';

final healthAssessmentCalculatorProvider = Provider<HealthAssessmentCalculator>(
  (ref) => const HealthAssessmentCalculator(),
);

/// Derives health from the selected charger and existing, charger-scoped
/// component inspection/fault state. It does not make a network request.
final healthAssessmentProvider = FutureProvider<HealthAssessment>((ref) async {
  final charger = ref.watch(selectedChargerProvider);
  final inspectionState = ref.watch(componentInspectionProvider);
  final calculator = ref.watch(healthAssessmentCalculatorProvider);

  // Keep loading/error states observable through the standard Riverpod API.
  await Future<void>.delayed(Duration.zero);

  final chargerKey = chargerIdentityKey(charger);
  final faults = chargerKey == null
      ? const <FaultResult>[]
      : inspectionState.faultsForCharger(chargerKey).values.toList();

  return calculator.assess(
    charger: charger,
    inspectedChargerKey: inspectionState.currentInspectionChargerKey,
    inspection: inspectionState.currentInspection,
    faults: faults,
  );
});
