import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_model.dart';
import 'package:chargex_vision/features/digital_twin/presentation/providers/digital_twin_provider.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';

void main() {
  group('DigitalTwin Model & Provider Tests', () {
    test('DigitalTwinModel json deserialization', () {
      final json = {
        'twinId': 'TWIN-001',
        'manufacturer': 'ABB',
        'chargerModel': 'Terra 184',
        'chargerType': 'DC Fast Charger',
        'assetReference': 'assets/models/terra_184.glb',
        'version': '1.0.0',
        'metadata': {'location': 'Station A'},
        'components': [
          {
            'componentId': 'COMP-01',
            'componentType': 'Connector',
            'displayName': 'CCS Combo 2 Cable',
            'assetNodeIdentifier': 'cable_node_01',
            'description': 'Main high power DC charging cable',
          }
        ],
      };

      final twin = DigitalTwinModel.fromJson(json);
      expect(twin.twinId, 'TWIN-001');
      expect(twin.manufacturer, 'ABB');
      expect(twin.chargerModel, 'Terra 184');
      expect(twin.components.length, 1);
      expect(twin.components.first.displayName, 'CCS Combo 2 Cable');
    });

    test('SelectedChargerNotifier updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedChargerProvider), null);

      const charger = ChargerModel(
        manufacturer: 'ABB',
        model: 'Terra 184',
        type: 'DC Fast Charger',
      );

      container.read(selectedChargerProvider.notifier).selectCharger(charger);
      expect(container.read(selectedChargerProvider), charger);

      container.read(selectedChargerProvider.notifier).clearCharger();
      expect(container.read(selectedChargerProvider), null);
    });

    test('DigitalTwinNotifier initial state and invalid charger handling', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(digitalTwinProvider);
      expect(state.status, DigitalTwinStateStatus.idle);
      expect(state.twin, null);
      expect(state.selectedComponent, null);

      // Unrecognized charger with no QR identifier
      const invalidCharger = ChargerModel();
      await container
          .read(digitalTwinProvider.notifier)
          .loadTwinForCharger(invalidCharger);

      final newState = container.read(digitalTwinProvider);
      expect(newState.status, DigitalTwinStateStatus.invalidChargerModel);
    });
  });
}
