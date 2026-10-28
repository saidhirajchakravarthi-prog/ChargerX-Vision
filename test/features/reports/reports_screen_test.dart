import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/health/domain/models/health_assessment.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';
import 'package:chargex_vision/features/reports/domain/services/current_report_composer.dart';
import 'package:chargex_vision/features/reports/presentation/providers/current_charger_report_provider.dart';
import 'package:chargex_vision/features/reports/presentation/screens/reports_screen.dart';

void main() {
  testWidgets(
    'renders a labeled current snapshot and truthful unavailable sections',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = const CurrentReportComposer().compose(
        charger: const ChargerModel(serialNumber: 'S-1', manufacturer: 'Maker'),
        inspectedChargerKey: null,
        currentInspection: null,
        activeFaults: const {},
        healthAssessment: const HealthAssessment(
          status: ChargerHealthStatus.unavailable,
          reason: 'No current inspection.',
        ),
        maintenanceReadiness: MaintenanceReadiness.notConfigured(
          chargerIdentifier: 'S-1',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentChargerReportProvider.overrideWith((ref) async => report),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Charger Snapshot'), findsOneWidget);
      expect(find.textContaining('not historical reporting'), findsOneWidget);
      expect(find.text('S-1'), findsOneWidget);
      expect(find.text('Current Inspection'), findsOneWidget);
      expect(find.text('Current Faults'), findsOneWidget);
      expect(find.text('Current Health Assessment'), findsOneWidget);
      expect(find.text('Maintenance Data'), findsOneWidget);
      expect(find.text('RUL Data'), findsOneWidget);
      expect(
        find.textContaining('Current health assessment is unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('RUL data unavailable'), findsOneWidget);
      expect(find.textContaining('148'), findsNothing);
      expect(find.textContaining('INSP-1042'), findsNothing);
      expect(find.textContaining('trend report'), findsOneWidget);
      expect(find.textContaining('PDF'), findsNothing);
      expect(find.textContaining('CSV'), findsNothing);
    },
  );

  testWidgets(
    'renders actual optional inspection/fault values without inventing timestamp',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const component = DigitalTwinComponent(
        componentId: 'pump-1',
        componentType: 'pump',
        displayName: 'Pump',
        assetNodeIdentifier: 'node',
        description: 'Pump component',
      );
      final inspection = ComponentInspection.noFaultDetected(
        component: component,
        evidenceSource: EvidenceSourceData.none,
      );
      final report = const CurrentReportComposer().compose(
        charger: ChargerModel(rawQrIdentifier: 'QR-1'),
        inspectedChargerKey: 'qr:QR-1',
        currentInspection: inspection,
        activeFaults: const {},
        healthAssessment: HealthAssessment(
          status: ChargerHealthStatus.healthy,
          reason: 'No fault.',
          charger: ChargerModel(rawQrIdentifier: 'QR-1'),
        ),
        maintenanceReadiness: MaintenanceReadiness.notConfigured(
          chargerIdentifier: 'QR-1',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentChargerReportProvider.overrideWith((ref) async => report),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('QR-1'), findsOneWidget);
      expect(find.textContaining('Pump (pump-1)'), findsOneWidget);
      expect(find.textContaining('No fault detected'), findsOneWidget);
      expect(find.text('Inspection timestamp unavailable.'), findsOneWidget);
      expect(find.textContaining('0 faults'), findsNothing);
      expect(find.textContaining('Health trend'), findsNothing);
    },
  );
}
