// lib/features/digital_twin/domain/models/digital_twin_model.dart
import 'digital_twin_component.dart';

class DigitalTwinModel {
  final String twinId;
  final String manufacturer;
  final String chargerModel;
  final String chargerType;
  final String assetReference;
  final String version;
  final Map<String, dynamic> metadata;
  final List<DigitalTwinComponent> components;

  const DigitalTwinModel({
    required this.twinId,
    required this.manufacturer,
    required this.chargerModel,
    required this.chargerType,
    required this.assetReference,
    required this.version,
    this.metadata = const {},
    this.components = const [],
  });

  factory DigitalTwinModel.fromJson(Map<String, dynamic> json) {
    return DigitalTwinModel(
      twinId: json['twinId'] as String,
      manufacturer: json['manufacturer'] as String,
      chargerModel: json['chargerModel'] as String,
      chargerType: json['chargerType'] as String,
      assetReference: json['assetReference'] as String,
      version: json['version'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => DigitalTwinComponent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
