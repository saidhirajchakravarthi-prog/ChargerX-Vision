// lib/features/inspection/domain/models/component_category.dart

enum ComponentCategory {
  wiring,
  connector,
  pcb,
  fuse,
  relayContactor,
  capacitorMosfet,
  coolingFan,
  sensors,
  communication,
  other,
}

extension ComponentCategoryExtension on ComponentCategory {
  String get displayName {
    switch (this) {
      case ComponentCategory.wiring:
        return 'Wiring';
      case ComponentCategory.connector:
        return 'Connector';
      case ComponentCategory.pcb:
        return 'PCB';
      case ComponentCategory.fuse:
        return 'Fuse';
      case ComponentCategory.relayContactor:
        return 'Relay / Contactor';
      case ComponentCategory.capacitorMosfet:
        return 'Capacitor / MOSFET';
      case ComponentCategory.coolingFan:
        return 'Cooling Fan';
      case ComponentCategory.sensors:
        return 'Sensors';
      case ComponentCategory.communication:
        return 'Communication';
      case ComponentCategory.other:
        return 'Other';
    }
  }

  List<String> get supportedConditions {
    switch (this) {
      case ComponentCategory.wiring:
        return const [
          'loose wire',
          'broken wire',
          'burnt wire',
          'insulation damage',
          'possible short-circuit evidence',
        ];
      case ComponentCategory.connector:
        return const [
          'loose connector',
          'bent pin',
          'corrosion',
          'moisture evidence',
          'overheating evidence',
        ];
      case ComponentCategory.pcb:
        return const [
          'visible overheating',
          'visible component damage',
          'burn marks',
          'abnormal condition',
        ];
      case ComponentCategory.fuse:
        return const ['visible damage', 'blown-fuse evidence'];
      case ComponentCategory.relayContactor:
        return const ['visible damage', 'abnormal condition'];
      case ComponentCategory.capacitorMosfet:
        return const ['visible damage', 'overheating evidence'];
      case ComponentCategory.coolingFan:
        return const [
          'obstruction',
          'visible damage',
          'fan status when real sensor/device data is available',
        ];
      case ComponentCategory.sensors:
        return const [
          'temperature sensor',
          'voltage sensor',
          'current sensor',
          'humidity sensor',
        ];
      case ComponentCategory.communication:
        return const ['CAN', 'OCPP', 'Wi-Fi', 'Ethernet', 'RFID'];
      case ComponentCategory.other:
        return const ['abnormal condition'];
    }
  }

  static ComponentCategory fromString(String type) {
    final lower = type.toLowerCase().trim();
    if (lower.contains('wire') ||
        lower.contains('cable') ||
        lower.contains('wiring')) {
      return ComponentCategory.wiring;
    }
    if (lower.contains('connector') ||
        lower.contains('plug') ||
        lower.contains('ccs') ||
        lower.contains('chademo') ||
        lower.contains('gun')) {
      return ComponentCategory.connector;
    }
    if (lower.contains('pcb') ||
        lower.contains('board') ||
        lower.contains('circuit')) {
      return ComponentCategory.pcb;
    }
    if (lower.contains('fuse')) {
      return ComponentCategory.fuse;
    }
    if (lower.contains('relay') || lower.contains('contactor')) {
      return ComponentCategory.relayContactor;
    }
    if (lower.contains('capacitor') ||
        lower.contains('mosfet') ||
        lower.contains('transistor')) {
      return ComponentCategory.capacitorMosfet;
    }
    if (lower.contains('fan') || lower.contains('cooling')) {
      return ComponentCategory.coolingFan;
    }
    if (lower.contains('sensor') ||
        lower.contains('temp') ||
        lower.contains('voltage') ||
        lower.contains('current')) {
      return ComponentCategory.sensors;
    }
    if (lower.contains('can') ||
        lower.contains('ocpp') ||
        lower.contains('wifi') ||
        lower.contains('ethernet') ||
        lower.contains('rfid') ||
        lower.contains('comm')) {
      return ComponentCategory.communication;
    }
    return ComponentCategory.other;
  }
}
