// lib/features/inspection/domain/models/fault_category.dart

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
  String get displayName {
    switch (this) {
      case FaultCategory.power:
        return 'POWER';
      case FaultCategory.wiring:
        return 'WIRING';
      case FaultCategory.connector:
        return 'CONNECTOR';
      case FaultCategory.internal:
        return 'INTERNAL';
      case FaultCategory.sensor:
        return 'SENSOR';
      case FaultCategory.communication:
        return 'COMMUNICATION';
      case FaultCategory.other:
        return 'OTHER';
    }
  }

  List<String> get supportedFaultTypes {
    switch (this) {
      case FaultCategory.power:
        return const [
          'AC overvoltage',
          'AC undervoltage',
          'phase loss',
          'surge',
          'power failure',
        ];
      case FaultCategory.wiring:
        return const [
          'loose wire',
          'broken wire',
          'burnt wire',
          'insulation damage',
          'short-circuit evidence',
        ];
      case FaultCategory.connector:
        return const [
          'bent pin',
          'loose connector',
          'corrosion',
          'moisture',
          'overheating',
        ];
      case FaultCategory.internal:
        return const [
          'fuse failure',
          'relay failure',
          'contactor failure',
          'capacitor damage',
          'MOSFET damage',
          'PCB overheating',
          'cooling fan failure',
        ];
      case FaultCategory.sensor:
        return const [
          'temperature sensor fault',
          'voltage sensor fault',
          'current sensor fault',
          'humidity sensor fault',
        ];
      case FaultCategory.communication:
        return const [
          'CAN',
          'OCPP',
          'Wi-Fi',
          'Ethernet',
          'RFID',
        ];
      case FaultCategory.other:
        return const ['unspecified fault'];
    }
  }

  static FaultCategory fromString(String categoryStr) {
    final lower = categoryStr.toLowerCase().trim();
    if (lower.contains('power') || lower.contains('ac') || lower.contains('voltage') || lower.contains('surge')) {
      return FaultCategory.power;
    }
    if (lower.contains('wire') || lower.contains('cable') || lower.contains('short')) {
      return FaultCategory.wiring;
    }
    if (lower.contains('connector') || lower.contains('pin') || lower.contains('plug')) {
      return FaultCategory.connector;
    }
    if (lower.contains('internal') ||
        lower.contains('fuse') ||
        lower.contains('relay') ||
        lower.contains('contactor') ||
        lower.contains('capacitor') ||
        lower.contains('mosfet') ||
        lower.contains('pcb') ||
        lower.contains('fan')) {
      return FaultCategory.internal;
    }
    if (lower.contains('sensor') || lower.contains('temp') || lower.contains('current') || lower.contains('humidity')) {
      return FaultCategory.sensor;
    }
    if (lower.contains('comm') ||
        lower.contains('can') ||
        lower.contains('ocpp') ||
        lower.contains('wifi') ||
        lower.contains('ethernet') ||
        lower.contains('rfid')) {
      return FaultCategory.communication;
    }
    return FaultCategory.other;
  }
}
