import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/digital_twin/presentation/widgets/twin_viewer_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_model.dart';
import 'package:chargex_vision/features/digital_twin/presentation/providers/digital_twin_provider.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/domain/models/charger_component_key.dart';
import 'package:chargex_vision/features/digital_twin/data/repositories/digital_twin_repository.dart';
import 'package:dio/dio.dart';

void main() {
  group('DigitalTwin Model & Provider Tests', () {
    test(
      'configured registry response is parsed from a mocked HTTP call',
      () async {
        RequestOptions? request;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                request = options;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'twinId': 'TWIN-FIXTURE',
                      'manufacturer': 'Fixture manufacturer',
                      'chargerModel': 'Fixture model',
                      'chargerType': 'Fixture type',
                      'assetReference': 'fixture-asset',
                      'version': 'fixture-version',
                      'components': const [],
                    },
                  ),
                );
              },
            ),
          );

        final twin =
            await DigitalTwinRepository(
              dio,
              endpointUrl: 'https://registry.example.invalid/v1/twins',
            ).getDigitalTwinForCharger(
              const ChargerModel(
                manufacturer: 'Fixture manufacturer',
                model: 'Fixture model',
              ),
            );

        expect(request?.path, 'https://registry.example.invalid/v1/twins');
        expect(
          request?.queryParameters['manufacturer'],
          'Fixture manufacturer',
        );
        expect(request?.queryParameters['model'], 'Fixture model');
        expect(twin?.twinId, 'TWIN-FIXTURE');
      },
    );

    test('unconfigured registry does not send a request', () async {
      var requestCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount++;
              handler.resolve(
                Response(requestOptions: options, statusCode: 200),
              );
            },
          ),
        );

      final twin = await DigitalTwinRepository(
        dio,
        endpointUrl: '',
      ).getDigitalTwinForCharger(const ChargerModel(serialNumber: 'SERIAL-A'));

      expect(twin, isNull);
      expect(requestCount, 0);
    });

    test(
      'unconfigured Twin provider exposes an explicit unavailable reason',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(digitalTwinProvider.notifier)
            .loadTwinForCharger(const ChargerModel(serialNumber: 'SERIAL-A'));

        final state = container.read(digitalTwinProvider);
        expect(state.status, DigitalTwinStateStatus.twinUnavailable);
        expect(state.errorMessage, contains('not configured'));
      },
    );

    test('fault highlights are limited to the displayed charger', () {
      const chargerA = ChargerModel(serialNumber: 'SERIAL-A');
      const chargerB = ChargerModel(serialNumber: 'SERIAL-B');
      const fault = FaultResult(
        faultType: 'overheating',
        componentId: 'COMP-1',
      );

      final faults = {
        chargerComponentKey('serial:SERIAL-A', 'COMP-1'): fault,
        chargerComponentKey('serial:SERIAL-B', 'COMP-1'): const FaultResult(
          faultType: 'wear',
          componentId: 'COMP-1',
        ),
      };

      expect(
        faultedComponentIdsForCharger(activeFaults: faults, charger: chargerA),
        {'COMP-1'},
      );
      expect(
        faultedComponentIdsForCharger(activeFaults: faults, charger: chargerB),
        {'COMP-1'},
      );
    });

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
          },
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

    test(
      'DigitalTwinNotifier initial state and invalid charger handling',
      () async {
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
      },
    );

    testWidgets('Twin viewer marks only the supplied faulty component', (
      tester,
    ) async {
      const twin = DigitalTwinModel(
        twinId: 'TWIN-001',
        manufacturer: 'ABB',
        chargerModel: 'Terra 184',
        chargerType: 'DC Fast Charger',
        assetReference: 'assets/models/terra_184.glb',
        version: '1.0.0',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwinViewerWidget(
              twin: twin,
              faultedComponentIds: const {'COMP-CONN-01'},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FAULT DETECTED'), findsOneWidget);
      expect(find.textContaining('COMP-CONN-01'), findsOneWidget);
    });
  });
}
