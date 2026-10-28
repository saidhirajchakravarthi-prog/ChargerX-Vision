// Fault taxonomy for ChargeX Vision component inspection.
enum FaultCategory {
  power,
  wiring,
  connector,
  internal,
  sensor,
  communication,
  other,
}

extension FaultCategoryExtension on FaultCategory {
  String get displayName => switch (this) {
    FaultCategory.power => 'POWER SYSTEM',
    FaultCategory.wiring => 'WIRING',
    FaultCategory.connector => 'CONNECTOR',
    FaultCategory.internal => 'INTERNAL COMPONENTS',
    FaultCategory.sensor => 'SENSORS',
    FaultCategory.communication => 'COMMUNICATION',
    FaultCategory.other => 'OTHER',
  };

  List<String> get supportedFaultTypes => switch (this) {
    FaultCategory.power => const [
      'AC overvoltage',
      'AC undervoltage',
      'Phase loss',
      'Power surge',
      'Power failure',
    ],
    FaultCategory.wiring => const [
      'Loose wiring',
      'Broken wire',
      'Burnt wire',
      'Wire insulation damage',
      'Short circuit',
    ],
    FaultCategory.connector => const [
      'Bent pin',
      'Loose connector',
      'Corrosion',
      'Moisture',
      'Connector overheating',
    ],
    FaultCategory.internal => const [
      'Fuse failure',
      'Relay failure',
      'Contactor failure',
      'Capacitor damage',
      'MOSFET damage',
      'PCB overheating',
      'Cooling fan failure',
    ],
    FaultCategory.sensor => const [
      'Temperature sensor fault',
      'Voltage sensor fault',
      'Current sensor fault',
      'Humidity sensor fault',
    ],
    FaultCategory.communication => const [
      'CAN communication failure',
      'OCPP communication failure',
      'Wi-Fi issue',
      'Ethernet issue',
      'RFID failure',
    ],
    FaultCategory.other => const ['Unspecified fault'],
  };

  static FaultCategory fromString(String value) {
    final text = value.toLowerCase().trim();
    if (text.contains('wire') ||
        text.contains('cable') ||
        text.contains('short')) {
      return FaultCategory.wiring;
    }
    if (text.contains('connector') ||
        text.contains('pin') ||
        text.contains('plug') ||
        text.contains('corrosion') ||
        text.contains('moisture')) {
      return FaultCategory.connector;
    }
    if (text.contains('fuse') ||
        text.contains('relay') ||
        text.contains('contactor') ||
        text.contains('capacitor') ||
        text.contains('mosfet') ||
        text.contains('pcb') ||
        text.contains('fan') ||
        text.contains('internal')) {
      return FaultCategory.internal;
    }
    if (text.contains('sensor') ||
        text.contains('temperature') ||
        text.contains('humidity')) {
      return FaultCategory.sensor;
    }
    if (text.contains('communication') ||
        text.contains('ocpp') ||
        text.contains('can ') ||
        text.contains('wi-fi') ||
        text.contains('wifi') ||
        text.contains('ethernet') ||
        text.contains('rfid')) {
      return FaultCategory.communication;
    }
    if (text.contains('power') ||
        text.contains('ac ') ||
        text.contains('phase loss') ||
        text.contains('voltage') ||
        text.contains('surge')) {
      return FaultCategory.power;
    }
    return FaultCategory.other;
  }
}
