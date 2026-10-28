import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';

enum RulAssessmentStatus { available, unavailable, insufficientData, error }

class RulAssessment {
  const RulAssessment._({
    required this.status,
    required this.reason,
    this.chargerIdentifier,
    this.componentId,
    this.componentDisplayName,
    this.remainingUsefulLife,
    this.unit,
    this.assessedAt,
    this.horizonStart,
    this.horizonEnd,
    this.modelName,
    this.modelVersion,
    this.confidence,
    this.faultContext = const [],
    this.inspectedComponent,
    this.charger,
  }) : assert(
         status != RulAssessmentStatus.available ||
             (chargerIdentifier != null &&
                 chargerIdentifier != '' &&
                 remainingUsefulLife != null &&
                 unit != null &&
                 unit != ''),
       ),
       assert(
         status == RulAssessmentStatus.available || remainingUsefulLife == null,
       );

  final RulAssessmentStatus status;
  final String reason;
  final String? chargerIdentifier;
  final String? componentId;
  final String? componentDisplayName;
  final double? remainingUsefulLife;
  final String? unit;
  final DateTime? assessedAt;
  final DateTime? horizonStart;
  final DateTime? horizonEnd;
  final String? modelName;
  final String? modelVersion;
  final double? confidence;
  final List<FaultResult> faultContext;
  final DigitalTwinComponent? inspectedComponent;

  bool get hasRulValue =>
      status == RulAssessmentStatus.available && remainingUsefulLife != null;

  String get statusLabel => switch (status) {
    RulAssessmentStatus.available => 'Available',
    RulAssessmentStatus.unavailable => 'Unavailable',
    RulAssessmentStatus.insufficientData => 'Not enough data',
    RulAssessmentStatus.error => 'Error',
  };

  String get chargerName {
    final charger = this.charger;
    final details = [
      charger?.manufacturer,
      charger?.model,
      charger?.type,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return details.isEmpty ? 'Charger' : details.join(' ');
  }

  RulAssessment copyWithContext({
    ChargerModel? charger,
    List<FaultResult>? faultContext,
    DigitalTwinComponent? inspectedComponent,
  }) => RulAssessment._(
    status: status,
    reason: reason,
    chargerIdentifier: chargerIdentifier,
    componentId: componentId,
    componentDisplayName: componentDisplayName,
    remainingUsefulLife: remainingUsefulLife,
    unit: unit,
    assessedAt: assessedAt,
    horizonStart: horizonStart,
    horizonEnd: horizonEnd,
    modelName: modelName,
    modelVersion: modelVersion,
    confidence: confidence,
    faultContext: faultContext ?? this.faultContext,
    inspectedComponent: inspectedComponent ?? this.inspectedComponent,
    charger: charger ?? this.charger,
  );

  /// Display context only; it is not used to invent or calculate RUL.
  final ChargerModel? charger;

  factory RulAssessment.available({
    required String chargerIdentifier,
    required double remainingUsefulLife,
    required String unit,
    required String reason,
    ChargerModel? charger,
    String? componentId,
    String? componentDisplayName,
    DateTime? assessedAt,
    DateTime? horizonStart,
    DateTime? horizonEnd,
    String? modelName,
    String? modelVersion,
    double? confidence,
    List<FaultResult> faultContext = const [],
    DigitalTwinComponent? inspectedComponent,
  }) => RulAssessment._(
    status: RulAssessmentStatus.available,
    reason: reason,
    chargerIdentifier: chargerIdentifier,
    componentId: componentId,
    componentDisplayName: componentDisplayName,
    remainingUsefulLife: remainingUsefulLife,
    unit: unit,
    assessedAt: assessedAt,
    horizonStart: horizonStart,
    horizonEnd: horizonEnd,
    modelName: modelName,
    modelVersion: modelVersion,
    confidence: confidence,
    faultContext: List.unmodifiable(faultContext),
    inspectedComponent: inspectedComponent,
    charger: charger,
  );

  factory RulAssessment.unavailable({
    required String reason,
    String? chargerIdentifier,
    ChargerModel? charger,
  }) => RulAssessment._(
    status: RulAssessmentStatus.unavailable,
    reason: reason,
    chargerIdentifier: chargerIdentifier,
    charger: charger,
  );

  factory RulAssessment.insufficientData({
    required String reason,
    String? chargerIdentifier,
    ChargerModel? charger,
    DigitalTwinComponent? inspectedComponent,
    List<FaultResult> faultContext = const [],
  }) => RulAssessment._(
    status: RulAssessmentStatus.insufficientData,
    reason: reason,
    chargerIdentifier: chargerIdentifier,
    charger: charger,
    inspectedComponent: inspectedComponent,
    faultContext: List.unmodifiable(faultContext),
  );

  factory RulAssessment.error({
    required String reason,
    String? chargerIdentifier,
    ChargerModel? charger,
  }) => RulAssessment._(
    status: RulAssessmentStatus.error,
    reason: reason,
    chargerIdentifier: chargerIdentifier,
    charger: charger,
  );
}
