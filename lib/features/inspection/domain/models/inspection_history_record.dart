import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

enum InspectionProvenance {
  verifiedBackend,
  verifiedDevice,
  simulated,
  unknown,
}

class InspectionEvidenceFile {
  const InspectionEvidenceFile({
    required this.sha256,
    required this.path,
    required this.originalName,
    required this.byteLength,
  });

  final String sha256;
  final String path;
  final String originalName;
  final int byteLength;

  Map<String, Object?> toJson() => {
    'sha256': sha256,
    'path': path,
    'originalName': originalName,
    'byteLength': byteLength,
  };

  factory InspectionEvidenceFile.fromJson(Map<String, Object?> json) {
    return InspectionEvidenceFile(
      sha256: json['sha256'] as String,
      path: json['path'] as String,
      originalName: json['originalName'] as String,
      byteLength: json['byteLength'] as int,
    );
  }
}

class InspectionHistoryRecord {
  const InspectionHistoryRecord({
    required this.id,
    required this.canonicalChargerId,
    required this.chargerIdentifiers,
    required this.twinId,
    required this.twinVersion,
    required this.component,
    required this.inspection,
    required this.provenance,
    required this.createdAt,
    required this.updatedAt,
    this.fault,
    this.evidenceFiles = const [],
  });

  static const schemaVersion = 1;
  final String id;
  final String canonicalChargerId;
  final Map<String, String> chargerIdentifiers;
  final String twinId;
  final String twinVersion;
  final DigitalTwinComponent component;
  final ComponentInspection inspection;
  final FaultResult? fault;
  final InspectionProvenance provenance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InspectionEvidenceFile> evidenceFiles;

  InspectionHistoryRecord copyWith({
    ComponentInspection? inspection,
    FaultResult? fault,
    InspectionProvenance? provenance,
    DateTime? updatedAt,
    List<InspectionEvidenceFile>? evidenceFiles,
  }) => InspectionHistoryRecord(
    id: id,
    canonicalChargerId: canonicalChargerId,
    chargerIdentifiers: chargerIdentifiers,
    twinId: twinId,
    twinVersion: twinVersion,
    component: component,
    inspection: inspection ?? this.inspection,
    fault: fault ?? this.fault,
    provenance: provenance ?? this.provenance,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    evidenceFiles: evidenceFiles ?? this.evidenceFiles,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'canonicalChargerId': canonicalChargerId,
    'chargerIdentifiers': chargerIdentifiers,
    'twinId': twinId,
    'twinVersion': twinVersion,
    'component': component.toJson(),
    'inspection': inspection.toJson(),
    'fault': fault?.toJson(),
    'provenance': provenance.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'evidenceFiles': evidenceFiles.map((file) => file.toJson()).toList(),
  };

  factory InspectionHistoryRecord.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported inspection record version.');
    }
    final component = DigitalTwinComponent.fromJson(
      Map<String, dynamic>.from(json['component'] as Map),
    );
    final provenance = InspectionProvenance.values.firstWhere(
      (value) => value.name == json['provenance'],
      orElse: () => throw const FormatException('Invalid provenance.'),
    );
    final identifiers = Map<String, dynamic>.from(
      json['chargerIdentifiers'] as Map,
    ).map((key, value) => MapEntry(key, value as String));
    final evidence = (json['evidenceFiles'] as List<dynamic>? ?? const [])
        .map(
          (item) => InspectionEvidenceFile.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final rawFault = json['fault'];
    return InspectionHistoryRecord(
      id: json['id'] as String,
      canonicalChargerId: json['canonicalChargerId'] as String,
      chargerIdentifiers: identifiers,
      twinId: json['twinId'] as String,
      twinVersion: json['twinVersion'] as String,
      component: component,
      inspection: ComponentInspection.fromJson(
        Map<String, dynamic>.from(json['inspection'] as Map),
        component,
      ),
      fault: rawFault == null
          ? null
          : FaultResult.fromJson(Map<String, dynamic>.from(rawFault as Map)),
      provenance: provenance,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      evidenceFiles: evidence,
    );
  }
}
