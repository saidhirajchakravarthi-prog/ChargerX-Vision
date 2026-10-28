import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargex_vision/features/chargers/presentation/providers/selected_charger_provider.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_identity.dart';
import '../../data/adapters/backend_inspection_analysis_adapter.dart';
import '../../data/repositories/fault_analysis_repository.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/digital_twin/presentation/providers/digital_twin_provider.dart';
import '../../data/repositories/local_inspection_repository.dart';
import '../../domain/models/inspection_history_record.dart';
import '../../domain/adapters/fault_detection_adapter.dart';
import '../../domain/adapters/inspection_analysis_adapter.dart';
import '../../domain/models/charger_component_key.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';

final faultAnalysisDioProvider = Provider<Dio>((ref) => Dio());

final faultAnalysisRepositoryProvider = Provider<FaultAnalysisRepository>((
  ref,
) {
  const requiresAuth = bool.fromEnvironment(
    'CHARGEX_FAULT_API_REQUIRE_FIREBASE_AUTH',
  );
  return FaultAnalysisRepository(
    dio: ref.watch(faultAnalysisDioProvider),
    requireAuthentication: requiresAuth,
    idTokenProvider: requiresAuth
        ? () async => await FirebaseAuth.instance.currentUser?.getIdToken()
        : null,
  );
});

final faultDetectionAdapterProvider = Provider<FaultDetectionAdapter>((ref) {
  return BackendInspectionAnalysisAdapter(
    ref.watch(faultAnalysisRepositoryProvider),
  );
});

final inspectionAdapterProvider = Provider<InspectionAnalysisAdapter>((ref) {
  return ref.watch(faultDetectionAdapterProvider);
});

class ComponentInspectionState {
  final DigitalTwinComponent? targetComponent;
  final ComponentInspection? currentInspection;
  final FaultResult? activeFaultResult;
  final Map<ChargerComponentKey, FaultResult> faultsByChargerComponent;
  final Map<ChargerComponentKey, ComponentInspection>
  inspectionsByChargerComponent;
  final String? currentInspectionChargerKey;
  final bool isAnalyzing;
  final String? errorMessage;
  final String? persistenceMessage;

  const ComponentInspectionState({
    this.targetComponent,
    this.currentInspection,
    this.activeFaultResult,
    this.faultsByChargerComponent = const {},
    this.inspectionsByChargerComponent = const {},
    this.currentInspectionChargerKey,
    this.isAnalyzing = false,
    this.errorMessage,
    this.persistenceMessage,
  });

  /// Returns only faults belonging to [chargerKey]. Missing identity is empty.
  Map<String, FaultResult> faultsForCharger(String? chargerKey) {
    if (chargerKey == null) return const {};
    return Map.unmodifiable({
      for (final entry in faultsByChargerComponent.entries)
        if (entry.key.chargerKey == chargerKey)
          entry.key.componentId: entry.value,
    });
  }

  ComponentInspection? inspectionForComponent(
    String? chargerKey,
    String componentId,
  ) {
    if (chargerKey == null) return null;
    return inspectionsByChargerComponent[chargerComponentKey(
      chargerKey,
      componentId,
    )];
  }

  /// Compatibility view scoped to the charger of the currently displayed inspection.
  Map<String, FaultResult> get activeComponentFaults =>
      faultsForCharger(currentInspectionChargerKey);

  /// Compatibility view; every returned item belongs to the current scope.
  Map<String, String> get activeFaultChargerKeys {
    final chargerKey = currentInspectionChargerKey;
    if (chargerKey == null) return const {};
    return Map.unmodifiable({
      for (final componentId in faultsForCharger(chargerKey).keys)
        componentId: chargerKey,
    });
  }

  ComponentInspectionState copyWith({
    DigitalTwinComponent? targetComponent,
    ComponentInspection? currentInspection,
    FaultResult? activeFaultResult,
    Map<ChargerComponentKey, FaultResult>? faultsByChargerComponent,
    Map<ChargerComponentKey, ComponentInspection>?
    inspectionsByChargerComponent,
    String? currentInspectionChargerKey,
    bool clearCurrentInspectionChargerKey = false,
    bool? isAnalyzing,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearActiveFaultResult = false,
    String? persistenceMessage,
    bool clearPersistenceMessage = false,
  }) {
    return ComponentInspectionState(
      targetComponent: targetComponent ?? this.targetComponent,
      currentInspection: currentInspection ?? this.currentInspection,
      activeFaultResult: clearActiveFaultResult
          ? null
          : (activeFaultResult ?? this.activeFaultResult),
      faultsByChargerComponent:
          faultsByChargerComponent ?? this.faultsByChargerComponent,
      inspectionsByChargerComponent:
          inspectionsByChargerComponent ?? this.inspectionsByChargerComponent,
      currentInspectionChargerKey: clearCurrentInspectionChargerKey
          ? null
          : (currentInspectionChargerKey ?? this.currentInspectionChargerKey),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      persistenceMessage: clearPersistenceMessage
          ? null
          : (persistenceMessage ?? this.persistenceMessage),
    );
  }
}

final componentInspectionProvider =
    NotifierProvider<ComponentInspectionNotifier, ComponentInspectionState>(
      ComponentInspectionNotifier.new,
    );

class ComponentInspectionNotifier extends Notifier<ComponentInspectionState> {
  @override
  ComponentInspectionState build() => const ComponentInspectionState();

  /// Selects the inspection already known for this charger/component pair.
  void setComponent(DigitalTwinComponent component) {
    final chargerKey = chargerIdentityKey(ref.read(selectedChargerProvider));
    final previous = state.inspectionForComponent(
      chargerKey,
      component.componentId,
    );
    final fault = chargerKey == null
        ? null
        : state.faultsByChargerComponent[chargerComponentKey(
            chargerKey,
            component.componentId,
          )];
    state = state.copyWith(
      targetComponent: component,
      currentInspection: previous ?? ComponentInspection.unavailable(component),
      activeFaultResult: fault,
      clearActiveFaultResult: fault == null,
      currentInspectionChargerKey: chargerKey,
      clearCurrentInspectionChargerKey: chargerKey == null,
      clearErrorMessage: true,
      clearPersistenceMessage: true,
    );
    final twinState = ref.read(digitalTwinProvider);
    final twin = twinState.chargerKey == chargerKey ? twinState.twin : null;
    if (chargerKey != null && twin != null) {
      unawaited(
        _restoreLatest(chargerKey, component, twin.twinId, twin.version),
      );
    }
  }

  Future<void> _restoreLatest(
    String chargerKey,
    DigitalTwinComponent component,
    String twinId,
    String twinVersion,
  ) async {
    try {
      final repository = await ref.read(
        localInspectionRepositoryProvider.future,
      );
      final charger = ref.read(selectedChargerProvider);
      if (charger == null) return;
      final canonicalId = await repository.resolveCanonicalChargerId(charger);
      final history = await repository.getHistory(
        canonicalChargerId: canonicalId,
      );
      InspectionHistoryRecord? match;
      for (final record in history) {
        if (record.component.componentId == component.componentId &&
            record.twinId == twinId &&
            record.twinVersion == twinVersion) {
          match = record;
          break;
        }
      }
      if (match == null ||
          chargerIdentityKey(ref.read(selectedChargerProvider)) != chargerKey ||
          state.targetComponent?.componentId != component.componentId) {
        return;
      }
      final key = chargerComponentKey(chargerKey, component.componentId);
      final inspections = Map<ChargerComponentKey, ComponentInspection>.from(
        state.inspectionsByChargerComponent,
      )..[key] = match.inspection;
      final faults = Map<ChargerComponentKey, FaultResult>.from(
        state.faultsByChargerComponent,
      );
      if (match.fault == null) {
        faults.remove(key);
      } else {
        faults[key] = match.fault!;
      }
      state = state.copyWith(
        inspectionsByChargerComponent: inspections,
        faultsByChargerComponent: faults,
        currentInspection: match.inspection,
        activeFaultResult: match.fault,
        clearActiveFaultResult: match.fault == null,
        persistenceMessage:
            'Restored from local inspection history • provenance: ${match.provenance.name}.',
      );
    } catch (_) {
      state = state.copyWith(
        persistenceMessage: 'Local inspection history could not be loaded.',
      );
    }
  }

  Future<void> runFaultAnalysis(
    DigitalTwinComponent component, {
    List<EvidenceSourceData> evidenceList = const [],
  }) async {
    if (state.isAnalyzing) return;
    final charger = ref.read(selectedChargerProvider);
    final chargerKey = chargerIdentityKey(charger);
    state = state.copyWith(
      targetComponent: component,
      isAnalyzing: true,
      currentInspection: ComponentInspection(
        component: component,
        status: InspectionStatus.pending,
        statusMessage: 'Analysis is in progress.',
      ),
      activeFaultResult: null,
      clearActiveFaultResult: true,
      currentInspectionChargerKey: chargerKey,
      clearCurrentInspectionChargerKey: chargerKey == null,
      clearErrorMessage: true,
    );

    final adapter = ref.read(inspectionAdapterProvider);
    if (!adapter.isConnected) {
      await _finishInspection(
        component,
        chargerKey,
        ComponentInspection.serviceNotConnected(component),
      );
      return;
    }

    try {
      final inspection = await adapter.inspectComponent(
        component,
        evidence: evidenceList.isEmpty ? null : evidenceList.first,
        charger: charger,
      );

      if (inspection.status == InspectionStatus.noFaultDetected) {
        await _finishInspection(
          component,
          chargerKey,
          inspection,
          evidenceList: evidenceList,
        );
        return;
      }
      if (inspection.status != InspectionStatus.completed) {
        await _finishInspection(
          component,
          chargerKey,
          inspection,
          errorMessage: inspection.status == InspectionStatus.failed
              ? inspection.statusMessage
              : null,
        );
        return;
      }

      // The adapter lookup uses the same charger identity as the request.
      final fault = await adapter.fetchActiveFaultForComponent(
        component.componentId,
        charger: charger,
      );
      if (fault == null || fault.componentId != component.componentId) {
        const message = 'The analysis service did not return a fault result.';
        await _finishInspection(
          component,
          chargerKey,
          ComponentInspection.failed(component, message),
          errorMessage: message,
        );
        return;
      }
      final completed = ComponentInspection.completed(
        component: component,
        evidenceSource: fault.evidenceSources.isNotEmpty
            ? fault.evidenceSources.first
            : evidenceList.isNotEmpty
            ? evidenceList.first
            : EvidenceSourceData.none,
        detectedCondition: fault.faultType,
        confidence: fault.confidence,
        severity: fault.severity,
        timestamp: fault.detectedAt,
        evidenceMetadata: {
          'evidence': fault.evidence,
          'locationDescription': fault.locationDescription,
        },
      );
      await _finishInspection(
        component,
        chargerKey,
        completed,
        fault: fault,
        evidenceList: evidenceList,
      );
    } catch (_) {
      const message =
          'Analysis could not be completed. Please retry or check the analysis service.';
      await _finishInspection(
        component,
        chargerKey,
        ComponentInspection.failed(component, message),
        errorMessage: message,
      );
    }
  }

  Future<void> _finishInspection(
    DigitalTwinComponent component,
    String? chargerKey,
    ComponentInspection inspection, {
    FaultResult? fault,
    String? errorMessage,
    List<EvidenceSourceData> evidenceList = const [],
  }) async {
    var savedInspection = inspection;
    String? persistenceMessage;
    if (inspection.status == InspectionStatus.completed ||
        inspection.status == InspectionStatus.noFaultDetected) {
      final charger = ref.read(selectedChargerProvider);
      final twinState = ref.read(digitalTwinProvider);
      final twin = twinState.chargerKey == chargerKey ? twinState.twin : null;
      if (charger == null || chargerIdentityKey(charger) != chargerKey) {
        persistenceMessage =
            'Result was not saved: charger identity is unavailable.';
      } else if (twin == null ||
          twin.twinId.trim().isEmpty ||
          twin.version.trim().isEmpty) {
        persistenceMessage =
            'Result was not saved: Digital Twin identity is unavailable.';
      } else {
        try {
          final repository = await ref.read(
            localInspectionRepositoryProvider.future,
          );
          final recordId = repository.generateRecordId();
          final result =
              evidenceList.isNotEmpty &&
                  inspection.evidenceSource.type == EvidenceSourceType.none
              ? inspection.copyWith(evidenceSource: evidenceList.first)
              : inspection;
          final record = await repository.saveInspection(
            recordId: recordId,
            charger: charger,
            twin: twin,
            inspection: result,
            fault: fault,
            provenance: InspectionProvenance.unknown,
          );
          savedInspection = record.inspection;
          persistenceMessage = 'Saved locally • provenance: unknown.';
        } catch (_) {
          persistenceMessage =
              'Result could not be saved to local history. Check charger identity, Digital Twin identity, and evidence availability.';
        }
      }
    }
    final faults = Map<ChargerComponentKey, FaultResult>.from(
      state.faultsByChargerComponent,
    );
    final inspections = Map<ChargerComponentKey, ComponentInspection>.from(
      state.inspectionsByChargerComponent,
    );
    if (chargerKey != null) {
      final key = chargerComponentKey(chargerKey, component.componentId);
      if (fault != null) {
        faults[key] = fault;
      } else {
        // A no-fault result clears only this charger's active fault.
        faults.remove(key);
      }
      inspections[key] = savedInspection;
    }

    final isStillCurrent =
        state.targetComponent?.componentId == component.componentId &&
        chargerIdentityKey(ref.read(selectedChargerProvider)) == chargerKey;
    state = state.copyWith(
      faultsByChargerComponent: faults,
      inspectionsByChargerComponent: inspections,
      currentInspection: isStillCurrent
          ? savedInspection
          : state.currentInspection,
      activeFaultResult: isStillCurrent ? fault : state.activeFaultResult,
      clearActiveFaultResult: isStillCurrent && fault == null,
      currentInspectionChargerKey: isStillCurrent ? chargerKey : null,
      clearCurrentInspectionChargerKey: isStillCurrent && chargerKey == null,
      isAnalyzing: false,
      errorMessage: isStillCurrent ? errorMessage : null,
      clearErrorMessage: isStillCurrent && errorMessage == null,
      persistenceMessage: isStillCurrent ? persistenceMessage : null,
      clearPersistenceMessage: isStillCurrent && persistenceMessage == null,
    );
  }

  Future<void> runInspection(
    DigitalTwinComponent component, {
    EvidenceSourceData? customEvidence,
  }) => runFaultAnalysis(
    component,
    evidenceList: customEvidence == null ? const [] : [customEvidence],
  );

  /// Registers only a genuine fault. Without stable charger identity it remains
  /// out of persistent scoped state and cannot highlight/report as charger data.
  void registerRealFaultResult(FaultResult fault) {
    final chargerKey = chargerIdentityKey(ref.read(selectedChargerProvider));
    final faults = Map<ChargerComponentKey, FaultResult>.from(
      state.faultsByChargerComponent,
    );
    if (chargerKey != null) {
      faults[chargerComponentKey(chargerKey, fault.componentId)] = fault;
    }

    final isTarget = state.targetComponent?.componentId == fault.componentId;
    final inspection = isTarget
        ? ComponentInspection.completed(
            component: state.targetComponent!,
            evidenceSource: fault.evidenceSources.isNotEmpty
                ? fault.evidenceSources.first
                : EvidenceSourceData.none,
            detectedCondition: fault.faultType,
            confidence: fault.confidence,
            severity: fault.severity,
            timestamp: fault.detectedAt,
          )
        : state.currentInspection;
    final inspections = Map<ChargerComponentKey, ComponentInspection>.from(
      state.inspectionsByChargerComponent,
    );
    if (isTarget && chargerKey != null) {
      inspections[chargerComponentKey(chargerKey, fault.componentId)] =
          inspection!;
    }
    state = state.copyWith(
      faultsByChargerComponent: faults,
      inspectionsByChargerComponent: inspections,
      currentInspection: inspection,
      activeFaultResult: isTarget ? fault : state.activeFaultResult,
      currentInspectionChargerKey: isTarget ? chargerKey : null,
      clearCurrentInspectionChargerKey: isTarget && chargerKey == null,
    );
  }

  void clearState() => state = const ComponentInspectionState();

  bool hasRealFaultForComponent(String componentId, {String? chargerKey}) {
    final scope =
        chargerKey ?? chargerIdentityKey(ref.read(selectedChargerProvider));
    return scope != null &&
        state.faultsByChargerComponent.containsKey(
          chargerComponentKey(scope, componentId),
        );
  }
}
