// test/features/inspection/component_inspection_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';

void main() {
  group('ComponentInspection Model Tests', () {
    const testComponent = DigitalTwinComponent(
      componentId: 'COMP-FAN-01',
      componentType: 'Cooling Fan',
      displayName: 'Main Cooling Fan',
      assetNodeIdentifier: 'fan_node_01',
      description: 'Primary intake cooling fan',
    );

    test('ComponentInspection.unavailable initializes with unavailable state', () {
      final inspection = ComponentInspection.unavailable(testComponent);

      expect(inspection.component.componentId, 'COMP-FAN-01');
      expect(inspection.status, InspectionStatus.unavailable);
      expect(inspection.evidenceSource.type, EvidenceSourceType.none);
      expect(inspection.statusMessage, 'No inspection data available.');
      expect(inspection.confidence, null);
      expect(inspection.severity, null);
      expect(inspection.detectedCondition, null);
    });

    test('ComponentInspection.serviceNotConnected initializes with service message', () {
      final inspection = ComponentInspection.serviceNotConnected(testComponent);

      expect(inspection.status, InspectionStatus.serviceNotConnected);
      expect(
        inspection.statusMessage,
        contains('Analysis service is not connected'),
      );
      expect(inspection.confidence, null);
      expect(inspection.severity, null);
    });

    test('ComponentInspection.completed initializes with real result values', () {
      final now = DateTime.now();
      final inspection = ComponentInspection.completed(
        component: testComponent,
        evidenceSource: const EvidenceSourceData(
          type: EvidenceSourceType.aiYolo,
          label: 'YOLO Camera Detection',
        ),
        detectedCondition: 'obstruction',
        confidence: 0.94,
        severity: 'High',
        timestamp: now,
      );

      expect(inspection.status, InspectionStatus.completed);
      expect(inspection.detectedCondition, 'obstruction');
      expect(inspection.confidence, 0.94);
      expect(inspection.severity, 'High');
      expect(inspection.timestamp, now);
      expect(inspection.evidenceSource.type, EvidenceSourceType.aiYolo);
    });

    test('ComponentInspection json serialization and deserialization', () {
      final now = DateTime(2026, 9, 25, 12, 0, 0);
      final original = ComponentInspection.completed(
        component: testComponent,
        evidenceSource: const EvidenceSourceData(
          type: EvidenceSourceType.thermalImage,
          label: 'Thermal Camera Scan',
        ),
        detectedCondition: 'overheating evidence',
        confidence: 0.88,
        severity: 'Critical',
        timestamp: now,
      );

      final json = original.toJson();
      expect(json['status'], 'completed');
      expect(json['confidence'], 0.88);
      expect(json['severity'], 'Critical');

      final deserialized = ComponentInspection.fromJson(json, testComponent);
      expect(deserialized.status, InspectionStatus.completed);
      expect(deserialized.detectedCondition, 'overheating evidence');
      expect(deserialized.confidence, 0.88);
      expect(deserialized.severity, 'Critical');
    });

    test('ComponentInspection copyWith updates fields correctly', () {
      final initial = ComponentInspection.unavailable(testComponent);
      final updated = initial.copyWith(
        status: InspectionStatus.completed,
        confidence: 0.95,
        severity: 'Medium',
      );

      expect(updated.status, InspectionStatus.completed);
      expect(updated.confidence, 0.95);
      expect(updated.severity, 'Medium');
      expect(updated.component, testComponent);
    });
  });
}
