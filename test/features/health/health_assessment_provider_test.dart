import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/health/domain/models/health_assessment.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/health/domain/services/health_assessment_calculator.dart';
import 'package:chargex_vision/features/health/presentation/providers/health_assessment_provider.dart';

class _ThrowingCalculator implements HealthAssessmentCalculator {
  @override
  HealthAssessment assess({
    required ChargerModel? charger,
    required String? inspectedChargerKey,
    required ComponentInspection? inspection,
    required Iterable<FaultResult> faults,
  }) => throw StateError('assessment failed');
}

void main() {
  test(
    'health provider exposes loading then unavailable without selection',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final assessment = container.read(healthAssessmentProvider);
      expect(assessment.isLoading, isTrue);
      final result = await container.read(healthAssessmentProvider.future);
      expect(result.status, ChargerHealthStatus.unavailable);
    },
  );

  test('health provider exposes unexpected calculation errors', () async {
    final container = ProviderContainer(
      overrides: [
        healthAssessmentCalculatorProvider.overrideWithValue(
          _ThrowingCalculator(),
        ),
        selectedChargerProvider.overrideWith(() => SelectedChargerNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(selectedChargerProvider.notifier)
        .selectCharger(const ChargerModel(serialNumber: 'SN-100'));

    expect(container.read(healthAssessmentProvider).isLoading, isTrue);
    await expectLater(
      container.read(healthAssessmentProvider.future),
      throwsStateError,
    );
    expect(container.read(healthAssessmentProvider).hasError, isTrue);
  });
}
