import '../../../chargers/domain/models/charger_model.dart';
import '../../../digital_twin/domain/models/digital_twin_component.dart';
import 'component_category.dart';
import 'evidence_source.dart';

/// Data already known by the app and sent to the fault-analysis API.
class FaultAnalysisRequest {
  final String componentId;
  final String? componentType;
  final String? componentDisplayName;
  final ComponentCategory? componentCategory;
  final String? assetNodeIdentifier;
  final String? componentDescription;
  final Map<String, dynamic> positionMetadata;
  final Map<String, dynamic> inspectionCapabilityMetadata;
  final ChargerModel? charger;
  final EvidenceSourceData? evidence;

  const FaultAnalysisRequest({
    required this.componentId,
    this.componentType,
    this.componentDisplayName,
    this.componentCategory,
    this.assetNodeIdentifier,
    this.componentDescription,
    this.positionMetadata = const {},
    this.inspectionCapabilityMetadata = const {},
    this.charger,
    this.evidence,
  });

  factory FaultAnalysisRequest.forComponent({
    required DigitalTwinComponent component,
    ChargerModel? charger,
    EvidenceSourceData? evidence,
  }) {
    return FaultAnalysisRequest(
      componentId: component.componentId,
      componentType: component.componentType,
      componentDisplayName: component.displayName,
      componentCategory: ComponentCategoryExtension.fromString(
        component.componentType,
      ),
      assetNodeIdentifier: component.assetNodeIdentifier,
      componentDescription: component.description,
      positionMetadata: component.positionMetadata,
      inspectionCapabilityMetadata: component.inspectionCapabilityMetadata,
      charger: charger,
      evidence: evidence,
    );
  }

  /// A local file path is uploaded as multipart data, never serialized as a
  /// device-local path in the JSON request.
  String? get localEvidencePath {
    final path = evidence?.metadata['path'];
    return path is String && path.isNotEmpty ? path : null;
  }

  Map<String, dynamic> toJson() {
    final chargerData = charger == null
        ? null
        : <String, dynamic>{
            if (charger!.serialNumber != null)
              'serial_number': charger!.serialNumber,
            if (charger!.rawQrIdentifier != null)
              'raw_qr_identifier': charger!.rawQrIdentifier,
            if (charger!.manufacturer != null)
              'manufacturer': charger!.manufacturer,
            if (charger!.model != null) 'model': charger!.model,
            if (charger!.type != null) 'type': charger!.type,
          };
    final evidenceData = evidence == null
        ? null
        : <String, dynamic>{
            'source': evidence!.type.name,
            'label': evidence!.label,
            if (evidence!.metadata.isNotEmpty)
              'metadata': {
                for (final entry in evidence!.metadata.entries)
                  if (entry.key != 'path') entry.key: entry.value,
              },
            if (evidence!.timestamp != null)
              'captured_at': evidence!.timestamp!.toIso8601String(),
          };

    return {
      'schema_version': 1,
      if (chargerData != null && chargerData.isNotEmpty) 'charger': chargerData,
      'component': {
        'component_id': componentId,
        'type': ?componentType,
        'display_name': ?componentDisplayName,
        'category': ?componentCategory?.name,
        if (assetNodeIdentifier != null)
          'asset_node_identifier': assetNodeIdentifier,
        'description': ?componentDescription,
        if (positionMetadata.isNotEmpty) 'position': positionMetadata,
        if (inspectionCapabilityMetadata.isNotEmpty)
          'inspection_capabilities': inspectionCapabilityMetadata,
      },
      'evidence': ?evidenceData,
    };
  }
}
