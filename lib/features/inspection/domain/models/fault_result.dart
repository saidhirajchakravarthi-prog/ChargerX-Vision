// lib/features/inspection/domain/models/fault_result.dart

import 'evidence_source.dart';
import 'fault_category.dart';

class FaultResult {
  final String faultType;
  final FaultCategory category;
  final String componentId;
  final String? componentDisplayName;
  final String? locationDescription;
  final String? severity;
  final List<String> evidence;
  final List<EvidenceSourceData> evidenceSources;
  final String? probableCause;
  final String? recommendation;
  final double? confidence;
  final DateTime? detectedAt;

  const FaultResult({
    required this.faultType,
    required this.componentId,
    this.category = FaultCategory.other,
    this.componentDisplayName,
    this.locationDescription,
    this.severity,
    this.evidence = const [],
    this.evidenceSources = const [],
    this.probableCause,
    this.recommendation,
    this.confidence,
    this.detectedAt,
  });

  factory FaultResult.fromJson(Map<String, dynamic> json) {
    final rawSources = json['evidenceSources'] as List<dynamic>?;
    final List<EvidenceSourceData> parsedSources = rawSources != null
        ? rawSources
              .map(
                (e) => EvidenceSourceData.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : const [];

    return FaultResult(
      faultType: json['faultType'] as String,
      componentId: json['componentId'] as String,
      category: json['category'] != null
          ? FaultCategoryExtension.fromString(json['category'] as String)
          : FaultCategoryExtension.fromString(json['faultType'] as String),
      componentDisplayName: json['componentDisplayName'] as String?,
      locationDescription: json['locationDescription'] as String?,
      severity: json['severity'] as String?,
      evidence:
          (json['evidence'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      evidenceSources: parsedSources,
      probableCause: json['probableCause'] as String?,
      recommendation: json['recommendation'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'faultType': faultType,
      'category': category.name,
      'componentId': componentId,
      'componentDisplayName': componentDisplayName,
      'locationDescription': locationDescription,
      'severity': severity,
      'evidence': evidence,
      'evidenceSources': evidenceSources.map((e) => e.toJson()).toList(),
      'probableCause': probableCause,
      'recommendation': recommendation,
      'confidence': confidence,
      'detectedAt': detectedAt?.toIso8601String(),
    };
  }

  FaultResult copyWith({
    String? faultType,
    FaultCategory? category,
    String? componentId,
    String? componentDisplayName,
    String? locationDescription,
    String? severity,
    List<String>? evidence,
    List<EvidenceSourceData>? evidenceSources,
    String? probableCause,
    String? recommendation,
    double? confidence,
    DateTime? detectedAt,
  }) {
    return FaultResult(
      faultType: faultType ?? this.faultType,
      category: category ?? this.category,
      componentId: componentId ?? this.componentId,
      componentDisplayName: componentDisplayName ?? this.componentDisplayName,
      locationDescription: locationDescription ?? this.locationDescription,
      severity: severity ?? this.severity,
      evidence: evidence ?? this.evidence,
      evidenceSources: evidenceSources ?? this.evidenceSources,
      probableCause: probableCause ?? this.probableCause,
      recommendation: recommendation ?? this.recommendation,
      confidence: confidence ?? this.confidence,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }
}
