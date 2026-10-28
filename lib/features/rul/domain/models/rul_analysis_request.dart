import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_category.dart';

class RulFaultContext {
  const RulFaultContext({
    required this.componentId,
    required this.faultType,
    required this.category,
    this.severity,
    this.detectedAt,
  });

  final String componentId;
  final String faultType;
  final String category;
  final String? severity;
  final DateTime? detectedAt;

  factory RulFaultContext.fromFault(FaultResult fault) => RulFaultContext(
    componentId: fault.componentId,
    faultType: fault.faultType,
    category: fault.category.name,
    severity: fault.severity,
    detectedAt: fault.detectedAt,
  );

  Map<String, dynamic> toJson() => {
    'componentId': componentId,
    'faultType': faultType,
    'category': category,
    if (severity != null) 'severity': severity,
    if (detectedAt != null) 'detectedAt': detectedAt!.toIso8601String(),
  };
}

class RulInspectionContext {
  const RulInspectionContext({
    required this.componentId,
    required this.status,
    this.componentType,
    this.componentDisplayName,
    this.detectedCondition,
    this.severity,
    this.timestamp,
  });

  final String componentId;
  final String status;
  final String? componentType;
  final String? componentDisplayName;
  final String? detectedCondition;
  final String? severity;
  final DateTime? timestamp;

  factory RulInspectionContext.fromInspection(ComponentInspection inspection) =>
      RulInspectionContext(
        componentId: inspection.component.componentId,
        status: inspection.status.name,
        componentType: inspection.component.componentType,
        componentDisplayName: inspection.component.displayName,
        detectedCondition: inspection.detectedCondition,
        severity: inspection.severity,
        timestamp: inspection.timestamp,
      );

  Map<String, dynamic> toJson() => {
    'componentId': componentId,
    'status': status,
    if (componentType != null) 'componentType': componentType,
    if (componentDisplayName != null)
      'componentDisplayName': componentDisplayName,
    if (detectedCondition != null) 'detectedCondition': detectedCondition,
    if (severity != null) 'severity': severity,
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
  };
}

/// Contains only charger identity and real inspection/fault context already
/// present in the app; it has no fields for fabricated operational history.
class RulAnalysisRequest {
  const RulAnalysisRequest({
    required this.chargerIdentifier,
    required this.charger,
    this.componentId,
    this.componentType,
    this.componentCategory,
    this.componentDisplayName,
    this.inspection,
    this.faults = const [],
  });

  final String chargerIdentifier;
  final ChargerModel charger;
  final String? componentId;
  final String? componentType;
  final String? componentCategory;
  final String? componentDisplayName;
  final RulInspectionContext? inspection;
  final List<RulFaultContext> faults;

  factory RulAnalysisRequest.fromAvailableData({
    required ChargerModel charger,
    required String chargerIdentifier,
    DigitalTwinComponent? component,
    ComponentInspection? inspection,
    List<FaultResult> faults = const [],
  }) => RulAnalysisRequest(
    chargerIdentifier: chargerIdentifier,
    charger: charger,
    componentId: component?.componentId,
    componentType: component?.componentType,
    componentCategory: component == null
        ? null
        : ComponentCategoryExtension.fromString(component.componentType).name,
    componentDisplayName: component?.displayName,
    inspection: inspection == null
        ? null
        : RulInspectionContext.fromInspection(inspection),
    faults: faults.map(RulFaultContext.fromFault).toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'charger': {
      'identifier': chargerIdentifier,
      if (charger.serialNumber != null) 'serialNumber': charger.serialNumber,
      if (charger.rawQrIdentifier != null)
        'rawQrIdentifier': charger.rawQrIdentifier,
      if (charger.manufacturer != null) 'manufacturer': charger.manufacturer,
      if (charger.model != null) 'model': charger.model,
      if (charger.type != null) 'type': charger.type,
    },
    if (componentId != null)
      'component': {
        'componentId': componentId,
        if (componentType != null) 'type': componentType,
        if (componentCategory != null) 'category': componentCategory,
        if (componentDisplayName != null) 'displayName': componentDisplayName,
      },
    if (inspection != null) 'inspection': inspection!.toJson(),
    if (faults.isNotEmpty)
      'faults': faults.map((fault) => fault.toJson()).toList(),
  };
}
