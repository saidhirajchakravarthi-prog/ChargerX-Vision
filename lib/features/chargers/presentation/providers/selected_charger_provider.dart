// lib/features/chargers/presentation/providers/selected_charger_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/charger_model.dart';

final selectedChargerProvider =
    NotifierProvider<SelectedChargerNotifier, ChargerModel?>(
  SelectedChargerNotifier.new,
);

class SelectedChargerNotifier extends Notifier<ChargerModel?> {
  @override
  ChargerModel? build() {
    return null;
  }

  void selectCharger(ChargerModel? charger) {
    state = charger;
  }

  void clearCharger() {
    state = null;
  }
}
