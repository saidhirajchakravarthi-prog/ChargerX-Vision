import '../models/maintenance_readiness.dart';

abstract interface class MaintenanceRepository {
  Future<MaintenanceReadiness> fetchForCharger(
    String chargerIdentifier, {
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  });
}
