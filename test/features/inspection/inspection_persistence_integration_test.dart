import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_model.dart';
import 'package:chargex_vision/features/digital_twin/presentation/providers/digital_twin_provider.dart';
import 'package:chargex_vision/features/inspection/data/adapters/default_inspection_analysis_adapter.dart';
import 'package:chargex_vision/features/inspection/data/repositories/local_inspection_repository.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/domain/models/inspection_history_record.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';

void main() {
  test(
    'completed inspection is persisted with Twin identity and unknown provenance',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chargex-provider-test-',
      );
      final repository = LocalInspectionRepository(directory: root);
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });

      const charger = ChargerModel(serialNumber: 'SERIAL-1');
      const component = DigitalTwinComponent(
        componentId: 'fan-1',
        componentType: 'fan',
        displayName: 'Cooling fan',
        assetNodeIdentifier: 'node-1',
        description: 'Primary fan',
      );
      const twin = DigitalTwinModel(
        twinId: 'twin-1',
        manufacturer: 'Maker',
        chargerModel: 'Model 1',
        chargerType: 'DC',
        assetReference: 'asset-1',
        version: '1',
        components: [component],
      );
      final adapter = DefaultInspectionAnalysisAdapter(isConnected: true)
        ..registerRealFaultResult(
          const FaultResult(faultType: 'overheating', componentId: 'fan-1'),
          charger: charger,
        );
      var containerDisposed = false;
      final container = ProviderContainer(
        overrides: [
          inspectionAdapterProvider.overrideWithValue(adapter),
          localInspectionRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          digitalTwinProvider.overrideWith(
            () => _FixedTwinNotifier(
              DigitalTwinState(
                status: DigitalTwinStateStatus.twinAvailable,
                twin: twin,
                chargerKey: 'serial:SERIAL-1',
              ),
            ),
          ),
        ],
      );
      addTearDown(() {
        if (!containerDisposed) container.dispose();
      });
      container.read(selectedChargerProvider.notifier).selectCharger(charger);

      await container
          .read(componentInspectionProvider.notifier)
          .runInspection(component);

      final history = await repository.getHistory();
      expect(history, hasLength(1));
      expect(history.single.inspection.status, InspectionStatus.completed);
      expect(history.single.twinId, 'twin-1');
      expect(history.single.twinVersion, '1');
      expect(history.single.provenance, InspectionProvenance.unknown);
      expect(
        container.read(componentInspectionProvider).persistenceMessage,
        contains('provenance: unknown'),
      );

      await repository.close();
      container.dispose();
      containerDisposed = true;
      final reopenedRepository = LocalInspectionRepository(directory: root);
      final restoredContainer = ProviderContainer(
        overrides: [
          localInspectionRepositoryProvider.overrideWith(
            (ref) async => reopenedRepository,
          ),
          digitalTwinProvider.overrideWith(
            () => _FixedTwinNotifier(
              DigitalTwinState(
                status: DigitalTwinStateStatus.twinAvailable,
                twin: twin,
                chargerKey: 'serial:SERIAL-1',
              ),
            ),
          ),
        ],
      );
      addTearDown(() async {
        restoredContainer.dispose();
        await reopenedRepository.close();
      });
      restoredContainer
          .read(selectedChargerProvider.notifier)
          .selectCharger(charger);
      restoredContainer
          .read(componentInspectionProvider.notifier)
          .setComponent(component);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        restoredContainer
            .read(componentInspectionProvider)
            .currentInspection
            ?.status,
        InspectionStatus.completed,
      );
      expect(
        restoredContainer.read(componentInspectionProvider).persistenceMessage,
        'Restored from local inspection history • provenance: unknown.',
      );
    },
  );
}

class _FixedTwinNotifier extends DigitalTwinNotifier {
  _FixedTwinNotifier(this.initialState);
  final DigitalTwinState initialState;

  @override
  DigitalTwinState build() => initialState;
}
