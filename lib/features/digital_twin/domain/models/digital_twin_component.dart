// lib/features/digital_twin/domain/models/digital_twin_component.dart

class DigitalTwinComponent {
  final String componentId;
  final String componentType;
  final String displayName;
  final String assetNodeIdentifier;
  final String description;
  final Map<String, dynamic> positionMetadata;
  final Map<String, dynamic> inspectionCapabilityMetadata;

  const DigitalTwinComponent({
    required this.componentId,
    required this.componentType,
    required this.displayName,
    required this.assetNodeIdentifier,
    required this.description,
    this.positionMetadata = const {},
    this.inspectionCapabilityMetadata = const {},
  });

  factory DigitalTwinComponent.fromJson(Map<String, dynamic> json) {
    return DigitalTwinComponent(
      componentId: json['componentId'] as String,
      componentType: json['componentType'] as String,
      displayName: json['displayName'] as String,
      assetNodeIdentifier: json['assetNodeIdentifier'] as String,
      description: json['description'] as String,
      positionMetadata: json['positionMetadata'] as Map<String, dynamic>? ?? {},
      inspectionCapabilityMetadata: json['inspectionCapabilityMetadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
