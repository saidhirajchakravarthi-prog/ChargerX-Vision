import '../models/rul_analysis_request.dart';
import '../models/rul_analysis_response.dart';

abstract interface class RulRepository {
  Future<RulAnalysisResponse> analyze(RulAnalysisRequest request);
}
