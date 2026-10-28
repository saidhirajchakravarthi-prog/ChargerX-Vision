import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';
import 'package:chargex_vision/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:chargex_vision/features/maintenance/presentation/providers/maintenance_provider.dart';

class _Repo implements MaintenanceRepository {
  final identifiers = <String>[];
  bool throwError = false;

  @override
  Future<MaintenanceReadiness> fetchForCharger(
    String chargerIdentifier, {
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) async {
    identifiers.add(chargerIdentifier);
    if (throwError) throw StateError('expected test error');
    return MaintenanceReadiness.fromJson(
      {
        'status': 'empty',
        'chargerIdentifier': chargerIdentifier,
        'records': [],
      },
      requestedChargerIdentifier: chargerIdentifier,
      faultRecommendations: faultRecommendations,
    );
  }
}

void main() {
  test(
    'missing selection is represented without making a backend request',
    () async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [maintenanceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      expect(container.read(maintenanceReadinessProvider).isLoading, isTrue);
      final value = await container.read(maintenanceReadinessProvider.future);
      expect(value.status, MaintenanceReadinessStatus.missingChargerIdentity);
      expect(repo.identifiers, isEmpty);
    },
  );

  test(
    'provider scopes each request to the selected charger identity',
    () async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [maintenanceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container
          .read(selectedChargerProvider.notifier)
          .selectCharger(const ChargerModel(serialNumber: 'S-1'));
      final first = await container.read(maintenanceReadinessProvider.future);
      expect(first.chargerIdentifier, 'S-1');
      container
          .read(selectedChargerProvider.notifier)
          .selectCharger(const ChargerModel(rawQrIdentifier: 'QR-2'));
      final second = await container.read(maintenanceReadinessProvider.future);
      expect(second.chargerIdentifier, 'QR-2');
      expect(repo.identifiers, ['S-1', 'QR-2']);
    },
  );

  test('unexpected provider errors remain errors', () async {
    final repo = _Repo()..throwError = true;
    final container = ProviderContainer(
      overrides: [maintenanceRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(selectedChargerProvider.notifier)
        .selectCharger(const ChargerModel(serialNumber: 'S-1'));
    await expectLater(
      container.read(maintenanceReadinessProvider.future),
      throwsStateError,
    );
    expect(container.read(maintenanceReadinessProvider).hasError, isTrue);
  });
}
