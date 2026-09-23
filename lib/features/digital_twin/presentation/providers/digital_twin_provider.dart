// lib/features/digital_twin/presentation/providers/digital_twin_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/digital_twin_repository.dart';
import '../../domain/models/digital_twin_model.dart';
import '../../domain/models/digital_twin_component.dart';
import '../../../chargers/domain/models/charger_model.dart';

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

  const DigitalTwinState({
    this.status = DigitalTwinStateStatus.idle,
    this.twin,
    this.selectedComponent,
    this.errorMessage,
  });

  DigitalTwinState copyWith({
    DigitalTwinStateStatus? status,
    DigitalTwinModel? twin,
    DigitalTwinComponent? selectedComponent,
    String? errorMessage,
  }) {
    return DigitalTwinState(
      status: status ?? this.status,
      twin: twin ?? this.twin,
      selectedComponent: selectedComponent, // Intentionally not coalescing to allow nullification
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final digitalTwinProvider = NotifierProvider<DigitalTwinNotifier, DigitalTwinState>(
  DigitalTwinNotifier.new,
);

class DigitalTwinNotifier extends Notifier<DigitalTwinState> {
  @override
  DigitalTwinState build() {
    return const DigitalTwinState();
  }

  Future<void> loadTwinForCharger(ChargerModel charger) async {
    if (!charger.isRecognized && charger.rawQrIdentifier == null) {
      state = state.copyWith(status: DigitalTwinStateStatus.invalidChargerModel);
      return;
    }

    state = state.copyWith(status: DigitalTwinStateStatus.loading, errorMessage: null);

    try {
      final repository = ref.read(digitalTwinRepositoryProvider);
      final twin = await repository.getDigitalTwinForCharger(charger);

      if (twin != null) {
        state = state.copyWith(
          status: DigitalTwinStateStatus.twinAvailable,
          twin: twin,
        );
      } else {
        state = state.copyWith(
          status: DigitalTwinStateStatus.twinUnavailable,
          errorMessage: 'Digital twin asset not available for this charger model.',
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
