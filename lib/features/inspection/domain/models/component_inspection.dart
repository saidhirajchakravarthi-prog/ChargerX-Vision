// lib/features/inspection/domain/models/component_inspection.dart

import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'evidence_source.dart';

enum InspectionStatus {
  unavailable,
  serviceNotConnected,
  pending,
  completed,
  noFaultDetected,
  failed,
}

extension InspectionStatusExtension on InspectionStatus {
  String get displayName {
    switch (this) {
      case InspectionStatus.unavailable:
        return 'Inspection data unavailable';
      case InspectionStatus.serviceNotConnected:
        return 'Analysis service not connected';
      case InspectionStatus.pending:
        return 'Analysis in progress';
      case InspectionStatus.completed:
        return 'Inspection completed';
      case InspectionStatus.noFaultDetected:
        return 'No fault detected';
      case InspectionStatus.failed:
        return 'Inspection failed';
    }
  }
}

class ComponentInspection {
  final DigitalTwinComponent component;
  final InspectionStatus status;
  final EvidenceSourceData evidenceSource;
  final String? detectedCondition;
  final double? confidence;
  final String? severity;
  final DateTime? timestamp;
  final Map<String, dynamic> evidenceMetadata;
  final String statusMessage;

  const ComponentInspection({
    required this.component,
    required this.status,
    this.evidenceSource = EvidenceSourceData.none,
    this.detectedCondition,
    this.confidence,
    this.severity,
    this.timestamp,
    this.evidenceMetadata = const {},
    required this.statusMessage,
  });

  /// Factory for when no real evidence exists
  factory ComponentInspection.unavailable(
    DigitalTwinComponent component, {
    String? message,
  }) {
    return ComponentInspection(
      component: component,
      status: InspectionStatus.unavailable,
      evidenceSource: EvidenceSourceData.none,
      statusMessage: message ?? 'No inspection data available.',
    );
  }

  /// Factory for when analysis service is not connected
  factory ComponentInspection.serviceNotConnected(
    DigitalTwinComponent component,
  ) {
    return ComponentInspection(
      component: component,
      status: InspectionStatus.serviceNotConnected,
      evidenceSource: EvidenceSourceData.none,
      statusMessage:
          'Analysis service is not connected. Connect a camera, ESP32/IoT device, or backend AI service to analyze this component.',
    );
  }

  /// Factory for a real analysis result
  factory ComponentInspection.completed({
    required DigitalTwinComponent component,
    required EvidenceSourceData evidenceSource,
    required String detectedCondition,
    double? confidence,
    String? severity,
    DateTime? timestamp,
    Map<String, dynamic> evidenceMetadata = const {},
  }) {
    return ComponentInspection(
      component: component,
      status: InspectionStatus.completed,
      evidenceSource: evidenceSource,
      detectedCondition: detectedCondition,
      confidence: confidence,
      severity: severity,
      timestamp: timestamp,
      evidenceMetadata: evidenceMetadata,
      statusMessage: 'Inspection completed with real result',
    );
  }

  /// A clean result explicitly returned by a connected analysis service.
  factory ComponentInspection.noFaultDetected({
    required DigitalTwinComponent component,
    required EvidenceSourceData evidenceSource,
    DateTime? timestamp,
    Map<String, dynamic> evidenceMetadata = const {},
  }) {
    return ComponentInspection(
      component: component,
      status: InspectionStatus.noFaultDetected,
      evidenceSource: evidenceSource,
      timestamp: timestamp,
      evidenceMetadata: evidenceMetadata,
      statusMessage: 'The connected analysis service reported no fault.',
    );
  }

  factory ComponentInspection.failed(
    DigitalTwinComponent component,
    String message,
  ) => ComponentInspection(
    component: component,
    status: InspectionStatus.failed,
    statusMessage: message,
  );

  factory ComponentInspection.fromJson(
    Map<String, dynamic> json,
    DigitalTwinComponent component,
  ) {
    return ComponentInspection(
      component: component,
      status: InspectionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InspectionStatus.unavailable,
      ),
      evidenceSource: json['evidenceSource'] != null
          ? EvidenceSourceData.fromJson(
              json['evidenceSource'] as Map<String, dynamic>,
            )
          : EvidenceSourceData.none,
      detectedCondition: json['detectedCondition'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      severity: json['severity'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      evidenceMetadata:
          json['evidenceMetadata'] as Map<String, dynamic>? ?? const {},
      statusMessage:
          json['statusMessage'] as String? ?? 'No inspection data available.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'componentId': component.componentId,
      'status': status.name,
      'evidenceSource': evidenceSource.toJson(),
      'detectedCondition': detectedCondition,
      'confidence': confidence,
      'severity': severity,
      'timestamp': timestamp?.toIso8601String(),
      'evidenceMetadata': evidenceMetadata,
      'statusMessage': statusMessage,
    };
  }

  ComponentInspection copyWith({
    DigitalTwinComponent? component,
    InspectionStatus? status,
    EvidenceSourceData? evidenceSource,
    String? detectedCondition,
    double? confidence,
    String? severity,
    DateTime? timestamp,
    Map<String, dynamic>? evidenceMetadata,
    String? statusMessage,
  }) {
    return ComponentInspection(
      component: component ?? this.component,
      status: status ?? this.status,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      detectedCondition: detectedCondition ?? this.detectedCondition,
      confidence: confidence ?? this.confidence,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      evidenceMetadata: evidenceMetadata ?? this.evidenceMetadata,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
