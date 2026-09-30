// test/features/inspection/fault_category_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';

void main() {
  group('FaultCategory Model & Extension Tests', () {
    test('FaultCategory displayName maps correctly', () {
      expect(FaultCategory.power.displayName, 'POWER');
      expect(FaultCategory.wiring.displayName, 'WIRING');
      expect(FaultCategory.connector.displayName, 'CONNECTOR');
      expect(FaultCategory.internal.displayName, 'INTERNAL');
      expect(FaultCategory.sensor.displayName, 'SENSOR');
      expect(FaultCategory.communication.displayName, 'COMMUNICATION');
      expect(FaultCategory.other.displayName, 'OTHER');
    });

    test('FaultCategory supportedFaultTypes includes required Phase 7 fault types', () {
      expect(FaultCategory.power.supportedFaultTypes, contains('AC overvoltage'));
      expect(FaultCategory.power.supportedFaultTypes, contains('AC undervoltage'));
      expect(FaultCategory.power.supportedFaultTypes, contains('phase loss'));
      expect(FaultCategory.power.supportedFaultTypes, contains('surge'));
      expect(FaultCategory.power.supportedFaultTypes, contains('power failure'));

      expect(FaultCategory.wiring.supportedFaultTypes, contains('loose wire'));
      expect(FaultCategory.wiring.supportedFaultTypes, contains('broken wire'));
      expect(FaultCategory.wiring.supportedFaultTypes, contains('burnt wire'));
      expect(FaultCategory.wiring.supportedFaultTypes, contains('insulation damage'));
      expect(FaultCategory.wiring.supportedFaultTypes, contains('short-circuit evidence'));

      expect(FaultCategory.connector.supportedFaultTypes, contains('bent pin'));
      expect(FaultCategory.connector.supportedFaultTypes, contains('loose connector'));
      expect(FaultCategory.connector.supportedFaultTypes, contains('corrosion'));
      expect(FaultCategory.connector.supportedFaultTypes, contains('moisture'));
      expect(FaultCategory.connector.supportedFaultTypes, contains('overheating'));

      expect(FaultCategory.internal.supportedFaultTypes, contains('fuse failure'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('relay failure'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('contactor failure'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('capacitor damage'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('MOSFET damage'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('PCB overheating'));
      expect(FaultCategory.internal.supportedFaultTypes, contains('cooling fan failure'));

      expect(FaultCategory.sensor.supportedFaultTypes, contains('temperature sensor fault'));
      expect(FaultCategory.sensor.supportedFaultTypes, contains('voltage sensor fault'));
      expect(FaultCategory.sensor.supportedFaultTypes, contains('current sensor fault'));
      expect(FaultCategory.sensor.supportedFaultTypes, contains('humidity sensor fault'));

      expect(FaultCategory.communication.supportedFaultTypes, contains('CAN'));
      expect(FaultCategory.communication.supportedFaultTypes, contains('OCPP'));
      expect(FaultCategory.communication.supportedFaultTypes, contains('Wi-Fi'));
      expect(FaultCategory.communication.supportedFaultTypes, contains('Ethernet'));
      expect(FaultCategory.communication.supportedFaultTypes, contains('RFID'));
    });

    test('FaultCategoryExtension.fromString parses category keywords accurately', () {
      expect(FaultCategoryExtension.fromString('AC overvoltage'), FaultCategory.power);
      expect(FaultCategoryExtension.fromString('burnt wire'), FaultCategory.wiring);
      expect(FaultCategoryExtension.fromString('bent pin'), FaultCategory.connector);
      expect(FaultCategoryExtension.fromString('fuse failure'), FaultCategory.internal);
      expect(FaultCategoryExtension.fromString('temperature sensor fault'), FaultCategory.sensor);
      expect(FaultCategoryExtension.fromString('CAN communication'), FaultCategory.communication);
    });
  });
}
