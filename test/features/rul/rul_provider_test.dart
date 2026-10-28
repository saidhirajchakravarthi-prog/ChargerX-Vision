import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_request.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_response.dart';
import 'package:chargex_vision/features/rul/domain/repositories/rul_repository.dart';
import 'package:chargex_vision/features/rul/presentation/providers/rul_provider.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_assessment.dart';

class _FakeRulRepository implements RulRepository {
  _FakeRulRepository(this.response, {this.shouldThrow = false});

  final RulAnalysisResponse response;
  final bool shouldThrow;

  @override
  Future<RulAnalysisResponse> analyze(RulAnalysisRequest request) async {
    if (shouldThrow) throw StateError('request failed');
    return response;
  }
}

void main() {
  test(
    'provider loading resolves to insufficient data with no charger',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(rulAssessmentProvider).isLoading, isTrue);
      final assessment = await container.read(rulAssessmentProvider.future);
      expect(assessment.status, RulAssessmentStatus.insufficientData);
      expect(assessment.remainingUsefulLife, isNull);
    },
  );

  test('provider returns unavailable when backend is not configured', () async {
    final container = ProviderContainer(
      overrides: [
        selectedChargerProvider.overrideWith(() => SelectedChargerNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(selectedChargerProvider.notifier)
        .selectCharger(const ChargerModel(serialNumber: 'SN-1'));

    final assessment = await container.read(rulAssessmentProvider.future);
    expect(assessment.status, RulAssessmentStatus.unavailable);
    expect(assessment.remainingUsefulLife, isNull);
  });

  test(
    'provider exposes unexpected repository errors through AsyncError',
    () async {
      final container = ProviderContainer(
        overrides: [
          selectedChargerProvider.overrideWith(() => SelectedChargerNotifier()),
          rulRepositoryProvider.overrideWithValue(
            _FakeRulRepository(
              const RulAnalysisResponse(
                outcome: RulResponseOutcome.backendError,
              ),
              shouldThrow: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(selectedChargerProvider.notifier)
          .selectCharger(const ChargerModel(serialNumber: 'SN-1'));

      await expectLater(
        container.read(rulAssessmentProvider.future),
        throwsStateError,
      );
      expect(container.read(rulAssessmentProvider).hasError, isTrue);
    },
  );
}
