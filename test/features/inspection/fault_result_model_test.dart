// test/features/inspection/fault_result_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

void main() {
  group('FaultResult Model Tests', () {
    test('FaultResult instantiation and field integrity', () {
      final now = DateTime.now();
      final fault = FaultResult(
        faultType: 'burnt wire',
        componentId: 'COMP-WIRING-01',
        componentDisplayName: 'Main DC Wiring Harness',
        locationDescription: 'Terminal Block A2',
        severity: 'Critical',
        evidence: const ['Thermal hotspot detected', 'Visual discoloration'],
        probableCause: 'High resistance contact point causing overheating',
        recommendation: 'Replace terminal lug and inspect insulation',
        confidence: 0.92,
        detectedAt: now,
      );

      expect(fault.faultType, 'burnt wire');
      expect(fault.componentId, 'COMP-WIRING-01');
      expect(fault.componentDisplayName, 'Main DC Wiring Harness');
      expect(fault.locationDescription, 'Terminal Block A2');
      expect(fault.severity, 'Critical');
      expect(fault.evidence.length, 2);
      expect(fault.confidence, 0.92);
      expect(fault.detectedAt, now);
    });

    test('FaultResult json serialization and deserialization', () {
      final now = DateTime(2026, 9, 25, 14, 30, 0);
      final original = FaultResult(
        faultType: 'corrosion',
        componentId: 'COMP-CONN-01',
        componentDisplayName: 'CCS Connector Pin',
        severity: 'Medium',
        evidence: const ['Oxidation visible on DC+ pin'],
        confidence: 0.85,
        detectedAt: now,
      );

      final json = original.toJson();
      expect(json['faultType'], 'corrosion');
      expect(json['componentId'], 'COMP-CONN-01');
      expect(json['confidence'], 0.85);

      final deserialized = FaultResult.fromJson(json);
      expect(deserialized.faultType, 'corrosion');
      expect(deserialized.componentId, 'COMP-CONN-01');
      expect(deserialized.severity, 'Medium');
      expect(deserialized.confidence, 0.85);
      expect(deserialized.evidence.first, 'Oxidation visible on DC+ pin');
    });

    test('FaultResult copyWith updates target fields', () {
      const initial = FaultResult(
        faultType: 'loose connector',
        componentId: 'COMP-CONN-02',
      );

      final updated = initial.copyWith(
        severity: 'Low',
        confidence: 0.75,
      );

      expect(updated.faultType, 'loose connector');
      expect(updated.componentId, 'COMP-CONN-02');
      expect(updated.severity, 'Low');
      expect(updated.confidence, 0.75);
    });
  });
}
