// test/features/inspection/component_inspection_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/presentation/providers/component_inspection_provider.dart';
import 'package:chargex_vision/features/inspection/presentation/screens/component_inspection_screen.dart';

void main() {
  group('ComponentInspectionScreen Widget Tests', () {
    const testComponent = DigitalTwinComponent(
      componentId: 'COMP-FAN-01',
      componentType: 'Cooling Fan',
      displayName: 'Main Cooling Fan',
      assetNodeIdentifier: 'fan_node_01',
      description: 'Primary intake cooling fan',
    );

    testWidgets('renders unavailable inspection state by default', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ComponentInspectionScreen(component: testComponent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Component Inspection'), findsOneWidget);
      expect(find.text('Main Cooling Fan'), findsOneWidget);
      expect(find.text('Cooling Fan'), findsWidgets);
      expect(find.text('Inspection data unavailable'), findsWidgets);
      expect(find.text('No camera/IoT/backend evidence available.'), findsOneWidget);
      expect(find.text('Run Fault Analysis'), findsOneWidget);
      expect(find.text('No fault detection data available.'), findsOneWidget);
    });

    testWidgets('displays serviceNotConnected warning after clicking Run Fault Analysis when disconnected', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ComponentInspectionScreen(component: testComponent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run Fault Analysis'));
      await tester.pumpAndSettle();

      expect(find.text('Fault detection service is not connected.'), findsWidgets);
      expect(find.textContaining('Fault detection service is not connected'), findsWidgets);
    });

    testWidgets('displays REAL fault result when a real fault is registered', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final realFault = FaultResult(
        faultType: 'obstruction',
        componentId: 'COMP-FAN-01',
        componentDisplayName: 'Main Cooling Fan',
        severity: 'High',
        evidence: const ['Foreign debris jammed in intake blades'],
        probableCause: 'Environmental debris accumulation',
        recommendation: 'Clear blockage and test fan rotation',
        confidence: 0.95,
        detectedAt: DateTime(2026, 9, 25, 10, 0, 0),
      );

      container
          .read(componentInspectionProvider.notifier)
          .registerRealFaultResult(realFault);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ComponentInspectionScreen(component: testComponent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FAULT DETECTED'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('95.0%'), findsOneWidget);
      expect(find.text('Foreign debris jammed in intake blades'), findsOneWidget);
    });
  });
}
