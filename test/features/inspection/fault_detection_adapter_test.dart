// test/features/inspection/fault_detection_adapter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/data/adapters/default_fault_detection_adapter.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

void main() {
  group('DefaultFaultDetectionAdapter Unit Tests', () {
    const testComponent = DigitalTwinComponent(
      componentId: 'COMP-CONN-01',
      componentType: 'Connector',
      displayName: 'DC Fast Charging Connector',
      assetNodeIdentifier: 'conn_node_01',
      description: 'Primary CCS2 Connector Assembly',
    );

    test('backend unavailable state returns null when disconnected', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: false);

      final fault = await adapter.detectFault(
        componentId: testComponent.componentId,
        evidenceList: const [
          EvidenceSourceData(
            type: EvidenceSourceType.cameraImage,
            label: 'Connector corrosion visual',
          ),
        ],
      );

      expect(fault, null);
      expect(adapter.isConnected, false);
    });

    test('unavailable evidence state returns null when no evidence provided', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: true);

      final fault = await adapter.detectFault(
        componentId: testComponent.componentId,
        evidenceList: const [],
      );

      expect(fault, null);
    });

    test('evidence validation processes real multi-source evidence payloads', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: true);

      final cameraEv = EvidenceSourceData(
        type: EvidenceSourceType.cameraImage,
        label: 'Corrosion discoloration on DC+ terminal',
        timestamp: DateTime(2026, 9, 25, 10, 0, 0),
      );

      final thermalEv = EvidenceSourceData(
        type: EvidenceSourceType.thermalImage,
        label: 'Thermal hot-spot 85C detected',
        timestamp: DateTime(2026, 9, 25, 10, 0, 1),
      );

      final fault = await adapter.detectFault(
        componentId: testComponent.componentId,
        evidenceList: [cameraEv, thermalEv],
      );

      expect(fault, isNotNull);
      expect(fault!.componentId, 'COMP-CONN-01');
      expect(fault.evidenceSources.length, 2);
      expect(fault.evidenceSources.first.type, EvidenceSourceType.cameraImage);
      expect(fault.evidenceSources.last.type, EvidenceSourceType.thermalImage);
    });

    test('fault detection result parsing handles JSON serialization and deserialization', () {
      final now = DateTime(2026, 9, 25, 11, 30, 0);
      final original = FaultResult(
        faultType: 'corrosion',
        category: FaultCategory.connector,
        componentId: 'COMP-CONN-01',
        componentDisplayName: 'DC Fast Charging Connector',
        locationDescription: 'DC+ Terminal Pin',
        severity: 'High',
        evidence: const ['Visual green oxidation', 'Elevated pin resistance'],
        evidenceSources: [
          EvidenceSourceData(
            type: EvidenceSourceType.cameraImage,
            label: 'Visual green oxidation',
            timestamp: now,
          ),
        ],
        probableCause: 'Moisture ingress through damaged seal',
        recommendation: 'Clean pin contacts and replace rubber seal',
        confidence: 0.93,
        detectedAt: now,
      );

      final json = original.toJson();
      expect(json['faultType'], 'corrosion');
      expect(json['category'], 'connector');
      expect(json['confidence'], 0.93);

      final parsed = FaultResult.fromJson(json);
      expect(parsed.faultType, 'corrosion');
      expect(parsed.category, FaultCategory.connector);
      expect(parsed.confidence, 0.93);
      expect(parsed.evidenceSources.first.label, 'Visual green oxidation');
    });

    test('multiple fault results tracking across components', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: true);

      final fault1 = FaultResult(
        faultType: 'burnt wire',
        category: FaultCategory.wiring,
        componentId: 'COMP-WIRING-01',
        severity: 'Critical',
      );

      final fault2 = FaultResult(
        faultType: 'fuse failure',
        category: FaultCategory.internal,
        componentId: 'COMP-FUSE-01',
        severity: 'High',
      );

      adapter.registerRealFaultResult(fault1);
      adapter.registerRealFaultResult(fault2);

      final allFaults = await adapter.fetchAllActiveFaults();
      expect(allFaults.length, 2);

      final fetched1 = await adapter.fetchActiveFaultForComponent('COMP-WIRING-01');
      expect(fetched1?.faultType, 'burnt wire');

      final fetched2 = await adapter.fetchActiveFaultForComponent('COMP-FUSE-01');
      expect(fetched2?.faultType, 'fuse failure');
    });

    test('no-fault/no-data handling returns null for unaffected components', () async {
      final adapter = DefaultFaultDetectionAdapter(isConnected: true);

      final result = await adapter.fetchActiveFaultForComponent('COMP-HEALTHY-99');
      expect(result, null);
    });
  });
}
