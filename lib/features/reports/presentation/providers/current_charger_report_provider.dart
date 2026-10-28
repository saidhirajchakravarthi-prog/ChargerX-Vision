import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chargers/presentation/providers/selected_charger_provider.dart';
import '../../../health/presentation/providers/health_assessment_provider.dart';
import '../../../inspection/presentation/providers/component_inspection_provider.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../domain/models/current_charger_report.dart';
import '../../domain/services/current_report_composer.dart';

final currentReportComposerProvider = Provider<CurrentReportComposer>(
  (ref) => const CurrentReportComposer(),
);

/// Combines only currently available, charger-scoped application state.
final currentChargerReportProvider = FutureProvider<CurrentChargerReport>((
  ref,
) async {
  final charger = ref.watch(selectedChargerProvider);
  final inspection = ref.watch(componentInspectionProvider);
  final health = await ref.watch(healthAssessmentProvider.future);
  final maintenance = await ref.watch(maintenanceReadinessProvider.future);
  final composer = ref.watch(currentReportComposerProvider);
  return composer.compose(
    charger: charger,
    inspectedChargerKey: inspection.currentInspectionChargerKey,
    currentInspection: inspection.currentInspection,
    activeFaults: inspection.faultsByChargerComponent,
    healthAssessment: health,
    maintenanceReadiness: maintenance,
  );
});
