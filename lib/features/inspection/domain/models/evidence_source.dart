// lib/features/inspection/domain/models/evidence_source.dart

enum EvidenceSourceType {
  cameraImage,
  aiYolo,
  thermalImage,
  electricalMeasurement,
  iotEsp32,
  backendAnalysis,
  diagnosticComm,
  none,
}

extension EvidenceSourceTypeExtension on EvidenceSourceType {
  String get displayName {
    switch (this) {
      case EvidenceSourceType.cameraImage:
        return 'Camera Image Analysis';
      case EvidenceSourceType.aiYolo:
        return 'AI / YOLO Object Detection';
      case EvidenceSourceType.thermalImage:
        return 'Thermal Information';
      case EvidenceSourceType.electricalMeasurement:
        return 'Electrical Measurements';
      case EvidenceSourceType.iotEsp32:
        return 'IoT / ESP32 Sensor Data';
      case EvidenceSourceType.backendAnalysis:
        return 'Backend Service Analysis';
      case EvidenceSourceType.diagnosticComm:
        return 'Diagnostic / Communication Data';
      case EvidenceSourceType.none:
        return 'No Evidence';
    }
  }
}

class EvidenceSourceData {
  final EvidenceSourceType type;
  final String label;
  final Map<String, dynamic> metadata;
  final DateTime? timestamp;

  const EvidenceSourceData({
    required this.type,
    required this.label,
    this.metadata = const {},
    this.timestamp,
  });

  static const EvidenceSourceData none = EvidenceSourceData(
    type: EvidenceSourceType.none,
    label: 'No camera/IoT/backend evidence available.',
  );

  factory EvidenceSourceData.fromJson(Map<String, dynamic> json) {
    return EvidenceSourceData(
      type: EvidenceSourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EvidenceSourceType.none,
      ),
      label:
          json['label'] as String? ??
          'No camera/IoT/backend evidence available.',
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'label': label,
      'metadata': metadata,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  EvidenceSourceData copyWith({
    EvidenceSourceType? type,
    String? label,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return EvidenceSourceData(
      type: type ?? this.type,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
