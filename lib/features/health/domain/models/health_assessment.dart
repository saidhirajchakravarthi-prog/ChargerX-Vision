import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';

enum ChargerHealthStatus { healthy, warning, critical, unavailable }

class HealthAssessment {
  const HealthAssessment({
    required this.status,
    required this.reason,
    this.charger,
    this.faults = const [],
    this.inspectedComponent,
    this.sourceTimestamp,
  });

  final ChargerHealthStatus status;
  final String reason;
  final ChargerModel? charger;
  final List<FaultResult> faults;
  final DigitalTwinComponent? inspectedComponent;

  /// Latest timestamp actually supplied by inspection or fault data.
  final DateTime? sourceTimestamp;

  bool get isAvailable => status != ChargerHealthStatus.unavailable;

  String get statusLabel => switch (status) {
    ChargerHealthStatus.healthy => 'Healthy',
    ChargerHealthStatus.warning => 'Warning',
    ChargerHealthStatus.critical => 'Critical',
    ChargerHealthStatus.unavailable => 'Unknown / Unavailable',
  };

  String? get chargerIdentifier {
    final serial = charger?.serialNumber?.trim();
    if (serial != null && serial.isNotEmpty) return serial;
    final qr = charger?.rawQrIdentifier?.trim();
    return qr == null || qr.isEmpty ? null : qr;
  }

  String get chargerName {
    final parts = [
      charger?.manufacturer,
      charger?.model,
      charger?.type,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Charger' : parts.join(' ');
  }
}
