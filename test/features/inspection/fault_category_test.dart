// test/features/inspection/fault_category_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_category.dart';

void main() {
  group('FaultCategory Model & Extension Tests', () {
    test('FaultCategory displayName maps correctly', () {
      expect(FaultCategory.power.displayName, 'POWER SYSTEM');
      expect(FaultCategory.wiring.displayName, 'WIRING');
      expect(FaultCategory.connector.displayName, 'CONNECTOR');
      expect(FaultCategory.internal.displayName, 'INTERNAL COMPONENTS');
      expect(FaultCategory.sensor.displayName, 'SENSORS');
      expect(FaultCategory.communication.displayName, 'COMMUNICATION');
      expect(FaultCategory.other.displayName, 'OTHER');
    });

    test(
      'FaultCategory supportedFaultTypes includes required Phase 7 fault types',
      () {
        expect(
          FaultCategory.power.supportedFaultTypes,
          contains('AC overvoltage'),
        );
        expect(
          FaultCategory.power.supportedFaultTypes,
          contains('AC undervoltage'),
        );
        expect(FaultCategory.power.supportedFaultTypes, contains('Phase loss'));
        expect(
          FaultCategory.power.supportedFaultTypes,
          contains('Power surge'),
        );
        expect(
          FaultCategory.power.supportedFaultTypes,
          contains('Power failure'),
        );

        expect(
          FaultCategory.wiring.supportedFaultTypes,
          contains('Loose wiring'),
        );
        expect(
          FaultCategory.wiring.supportedFaultTypes,
          contains('Broken wire'),
        );
        expect(
          FaultCategory.wiring.supportedFaultTypes,
          contains('Burnt wire'),
        );
        expect(
          FaultCategory.wiring.supportedFaultTypes,
          contains('Wire insulation damage'),
        );
        expect(
          FaultCategory.wiring.supportedFaultTypes,
          contains('Short circuit'),
        );

        expect(
          FaultCategory.connector.supportedFaultTypes,
          contains('Bent pin'),
        );
        expect(
          FaultCategory.connector.supportedFaultTypes,
          contains('Loose connector'),
        );
        expect(
          FaultCategory.connector.supportedFaultTypes,
          contains('Corrosion'),
        );
        expect(
          FaultCategory.connector.supportedFaultTypes,
          contains('Moisture'),
        );
        expect(
          FaultCategory.connector.supportedFaultTypes,
          contains('Connector overheating'),
        );

        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('Fuse failure'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('Relay failure'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('Contactor failure'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('Capacitor damage'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('MOSFET damage'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('PCB overheating'),
        );
        expect(
          FaultCategory.internal.supportedFaultTypes,
          contains('Cooling fan failure'),
        );

        expect(
          FaultCategory.sensor.supportedFaultTypes,
          contains('Temperature sensor fault'),
        );
        expect(
          FaultCategory.sensor.supportedFaultTypes,
          contains('Voltage sensor fault'),
        );
        expect(
          FaultCategory.sensor.supportedFaultTypes,
          contains('Current sensor fault'),
        );
        expect(
          FaultCategory.sensor.supportedFaultTypes,
          contains('Humidity sensor fault'),
        );

        expect(
          FaultCategory.communication.supportedFaultTypes,
          contains('CAN communication failure'),
        );
        expect(
          FaultCategory.communication.supportedFaultTypes,
          contains('OCPP communication failure'),
        );
        expect(
          FaultCategory.communication.supportedFaultTypes,
          contains('Wi-Fi issue'),
        );
        expect(
          FaultCategory.communication.supportedFaultTypes,
          contains('Ethernet issue'),
        );
        expect(
          FaultCategory.communication.supportedFaultTypes,
          contains('RFID failure'),
        );
      },
    );

    test(
      'FaultCategoryExtension.fromString parses category keywords accurately',
      () {
        expect(
          FaultCategoryExtension.fromString('AC overvoltage'),
          FaultCategory.power,
        );
        expect(
          FaultCategoryExtension.fromString('burnt wire'),
          FaultCategory.wiring,
        );
        expect(
          FaultCategoryExtension.fromString('bent pin'),
          FaultCategory.connector,
        );
        expect(
          FaultCategoryExtension.fromString('fuse failure'),
          FaultCategory.internal,
        );
        expect(
          FaultCategoryExtension.fromString('temperature sensor fault'),
          FaultCategory.sensor,
        );
        expect(
          FaultCategoryExtension.fromString('CAN communication'),
          FaultCategory.communication,
        );
      },
    );
  });
}
