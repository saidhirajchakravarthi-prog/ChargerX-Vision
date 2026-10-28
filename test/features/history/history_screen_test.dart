import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/history/presentation/providers/inspection_history_provider.dart';
import 'package:chargex_vision/features/history/presentation/screens/history_screen.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/inspection_history_record.dart';

void main() {
  testWidgets('history shows provenance and inspection detail', (tester) async {
    const component = DigitalTwinComponent(
      componentId: 'connector-1',
      componentType: 'connector',
      displayName: 'Charge connector',
      assetNodeIdentifier: 'node-1',
      description: 'Main connector',
    );
    final inspection = ComponentInspection.noFaultDetected(
      component: component,
      evidenceSource: EvidenceSourceData.none,
      timestamp: DateTime.utc(2026, 1, 1),
    );
    final record = InspectionHistoryRecord(
      id: 'ui-record',
      canonicalChargerId: 'charger-ui',
      chargerIdentifiers: const {'serial': 'SERIAL-UI'},
      twinId: 'twin-ui',
      twinVersion: 'v1',
      component: component,
      inspection: inspection,
      provenance: InspectionProvenance.unknown,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inspectionHistoryProvider.overrideWith((ref) async => [record]),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Inspection History'), findsOneWidget);
    expect(find.text('Charge connector'), findsOneWidget);
    expect(find.textContaining('unknown'), findsOneWidget);

    await tester.tap(find.text('Charge connector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('twin-ui'), findsOneWidget);
    expect(find.textContaining('unknown'), findsWidgets);
    expect(find.text('No local image evidence was attached.'), findsOneWidget);
  });
}
