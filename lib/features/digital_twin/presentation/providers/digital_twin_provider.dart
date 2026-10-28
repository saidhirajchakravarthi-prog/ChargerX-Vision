// lib/features/digital_twin/presentation/providers/digital_twin_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/digital_twin_repository.dart';
import '../../domain/models/digital_twin_model.dart';
import '../../domain/models/digital_twin_component.dart';
import '../../../chargers/domain/models/charger_model.dart';
import '../../../chargers/domain/models/charger_identity.dart';
import '../../../inspection/domain/models/fault_result.dart';
import '../../../inspection/domain/models/charger_component_key.dart';

Set<String> faultedComponentIdsForCharger({
  required Map<ChargerComponentKey, FaultResult> activeFaults,
  required ChargerModel? charger,
}) {
  final chargerKey = chargerIdentityKey(charger);
  if (chargerKey == null) return const {};
  return activeFaults.entries
      .where(
        (entry) =>
            entry.key.chargerKey == chargerKey &&
            entry.key.componentId == entry.value.componentId,
      )
      .map((entry) => entry.key.componentId)
      .toSet();
}

// Provide a singleton Dio instance for this feature (or could be global)
final _dioProvider = Provider<Dio>((ref) => Dio());

final digitalTwinRepositoryProvider = Provider<DigitalTwinRepository>((ref) {
  return DigitalTwinRepository(ref.read(_dioProvider));
});

enum DigitalTwinStateStatus {
  idle,
  loading,
  twinAvailable,
  twinUnavailable,
  invalidChargerModel,
  assetLoadingError,
}

class DigitalTwinState {
  final DigitalTwinStateStatus status;
  final DigitalTwinModel? twin;
  final DigitalTwinComponent? selectedComponent;
  final String? errorMessage;
  final String? chargerKey;

  const DigitalTwinState({
    this.status = DigitalTwinStateStatus.idle,
    this.twin,
    this.selectedComponent,
    this.errorMessage,
    this.chargerKey,
  });

  DigitalTwinState copyWith({
    DigitalTwinStateStatus? status,
    DigitalTwinModel? twin,
    DigitalTwinComponent? selectedComponent,
    String? errorMessage,
    String? chargerKey,
    bool clearTwin = false,
  }) {
    return DigitalTwinState(
      status: status ?? this.status,
      twin: clearTwin ? null : (twin ?? this.twin),
      selectedComponent:
          selectedComponent, // Intentionally not coalescing to allow nullification
      errorMessage: errorMessage ?? this.errorMessage,
      chargerKey: chargerKey ?? this.chargerKey,
    );
  }
}

final digitalTwinProvider =
    NotifierProvider<DigitalTwinNotifier, DigitalTwinState>(
      DigitalTwinNotifier.new,
    );

class DigitalTwinNotifier extends Notifier<DigitalTwinState> {
  @override
  DigitalTwinState build() {
    return const DigitalTwinState();
  }

  Future<void> loadTwinForCharger(ChargerModel charger) async {
    if (!charger.isRecognized && charger.rawQrIdentifier == null) {
      state = state.copyWith(
        status: DigitalTwinStateStatus.invalidChargerModel,
      );
      return;
    }

    state = state.copyWith(
      status: DigitalTwinStateStatus.loading,
      errorMessage: null,
      clearTwin: true,
      chargerKey: chargerIdentityKey(charger),
    );

    try {
      final repository = ref.read(digitalTwinRepositoryProvider);
      if (!repository.isConfigured) {
        state = state.copyWith(
          status: DigitalTwinStateStatus.twinUnavailable,
          errorMessage: 'Digital Twin registry service is not configured.',
        );
        return;
      }
      final twin = await repository.getDigitalTwinForCharger(charger);

      if (twin != null) {
        state = state.copyWith(
          status: DigitalTwinStateStatus.twinAvailable,
          twin: twin,
          chargerKey: chargerIdentityKey(charger),
        );
      } else {
        state = state.copyWith(
          status: DigitalTwinStateStatus.twinUnavailable,
          errorMessage:
              'Digital twin asset not available for this charger model.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: DigitalTwinStateStatus.assetLoadingError,
        errorMessage: e.toString(),
      );
    }
  }

  void selectComponent(DigitalTwinComponent? component) {
    state = state.copyWith(selectedComponent: component);
  }
}
