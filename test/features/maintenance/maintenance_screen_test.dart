import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';
import 'package:chargex_vision/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:chargex_vision/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:chargex_vision/features/maintenance/presentation/screens/maintenance_screen.dart';

class _SelectedChargerNotifier extends SelectedChargerNotifier {
  _SelectedChargerNotifier(this.charger);

  final ChargerModel charger;

  @override
  ChargerModel? build() => charger;
}

class _Repo implements MaintenanceRepository {
  _Repo(this.response);
  final MaintenanceReadiness response;

  @override
  Future<MaintenanceReadiness> fetchForCharger(
    String chargerIdentifier, {
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) async => response;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ChargerModel? charger,
    required MaintenanceReadiness response,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceRepositoryProvider.overrideWithValue(_Repo(response)),
          if (charger != null)
            selectedChargerProvider.overrideWith(
              () => _SelectedChargerNotifier(charger),
            ),
        ],
        child: const MaterialApp(home: MaintenanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows missing charger identity', (tester) async {
    await pump(tester, response: MaintenanceReadiness.missingChargerIdentity());
    expect(find.textContaining('charger identity is missing'), findsOneWidget);
  });

  testWidgets('does not request data for an unidentified charger', (
    tester,
  ) async {
    await pump(
      tester,
      charger: const ChargerModel(manufacturer: 'Maker', model: 'Model'),
      response: MaintenanceReadiness.missingChargerIdentity(),
    );
    expect(find.text('Unique charger identifier unavailable'), findsOneWidget);
    expect(find.textContaining('charger identity is missing'), findsOneWidget);
  });

  testWidgets('shows configured empty response clearly', (tester) async {
    await pump(
      tester,
      charger: const ChargerModel(serialNumber: 'S-1'),
      response: MaintenanceReadiness.fromJson({
        'status': 'empty',
        'chargerIdentifier': 'S-1',
        'records': [],
      }, requestedChargerIdentifier: 'S-1'),
    );
    expect(find.text('No maintenance records'), findsOneWidget);
    expect(
      find.textContaining('No maintenance records were returned'),
      findsOneWidget,
    );
    expect(find.textContaining('next service'), findsNothing);
    expect(find.textContaining('Work order:'), findsNothing);
    expect(find.text('Fault-analysis recommendations'), findsNothing);
  });

  testWidgets(
    'renders only actual record fields and explicit fault recommendation',
    (tester) async {
      final recommendation = FaultAnalysisRecommendation(
        componentId: 'fan-1',
        faultType: 'blocked fan',
        recommendation: 'Clear blockage and verify fan rotation',
      );
      await pump(
        tester,
        charger: const ChargerModel(serialNumber: 'S-1'),
        response: MaintenanceReadiness.fromJson(
          {
            'status': 'available',
            'chargerIdentifier': 'S-1',
            'records': [
              {
                'recordId': 'R-1',
                'recordType': 'repair',
                'serviceDate': '2025-03-04T00:00:00Z',
                'repairDetails': 'Replaced backend-confirmed component',
              },
            ],
          },
          requestedChargerIdentifier: 'S-1',
          faultRecommendations: [recommendation],
        ),
      );
      expect(find.text('repair'), findsOneWidget);
      expect(find.textContaining('Service date:'), findsOneWidget);
      expect(find.text('Fault-analysis recommendations'), findsOneWidget);
      expect(
        find.text('Clear blockage and verify fan rotation'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not maintenance records or scheduled work'),
        findsOneWidget,
      );
      expect(find.textContaining('Next service:'), findsNothing);
      expect(find.textContaining('Technician:'), findsNothing);
    },
  );

  testWidgets('shows unavailable backend without invented records', (
    tester,
  ) async {
    await pump(
      tester,
      charger: const ChargerModel(serialNumber: 'S-1'),
      response: MaintenanceReadiness.notConfigured(chargerIdentifier: 'S-1'),
    );
    expect(find.text('Maintenance service not configured'), findsOneWidget);
    expect(find.textContaining('schedule'), findsNothing);
  });

  testWidgets('shows currently unavailable backend distinctly', (tester) async {
    await pump(
      tester,
      charger: const ChargerModel(serialNumber: 'S-1'),
      response: MaintenanceReadiness.unavailable(
        chargerIdentifier: 'S-1',
        message: 'Maintenance service is currently unavailable.',
      ),
    );
    expect(find.text('Maintenance service unavailable'), findsOneWidget);
    expect(find.textContaining('currently unavailable'), findsOneWidget);
    expect(find.text('No maintenance records'), findsNothing);
  });
}
