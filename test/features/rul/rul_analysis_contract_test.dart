import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_request.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_response.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_assessment.dart';

const charger = ChargerModel(
  manufacturer: 'ABB',
  model: 'Terra',
  serialNumber: 'SN-1',
);
const chargerRequest = RulAnalysisRequest(
  chargerIdentifier: 'SN-1',
  charger: charger,
);

void main() {
  test('valid charger-level RUL response is parsed with backend fields', () {
    final response = RulAnalysisResponse.fromJson({
      'status': 'available',
      'result': {
        'chargerIdentifier': 'SN-1',
        'remainingUsefulLife': 740,
        'unit': 'operating_hours',
        'assessedAt': '2026-10-02T10:00:00Z',
        'horizonEnd': '2027-01-02T10:00:00Z',
        'modelVersion': 'rul-v2',
        'confidence': 0.84,
      },
    }, request: chargerRequest);
    final assessment = response.assessment!;
    expect(response.outcome, RulResponseOutcome.available);
    expect(assessment.status, RulAssessmentStatus.available);
    expect(assessment.remainingUsefulLife, 740);
    expect(assessment.unit, 'operating_hours');
    expect(assessment.charger, charger);
    expect(assessment.assessedAt, DateTime.utc(2026, 10, 2, 10));
    expect(assessment.confidence, 0.84);
  });

  test('missing RUL value is rejected as malformed', () {
    expect(
      () => RulAnalysisResponse.fromJson({
        'status': 'available',
        'result': {'chargerIdentifier': 'SN-1', 'unit': 'hours'},
      }, request: chargerRequest),
      throwsFormatException,
    );
  });

  test('mismatched charger association is rejected', () {
    expect(
      () => RulAnalysisResponse.fromJson({
        'status': 'available',
        'result': {
          'chargerIdentifier': 'OTHER',
          'remainingUsefulLife': 7,
          'unit': 'days',
        },
      }, request: chargerRequest),
      throwsFormatException,
    );
  });

  test('component RUL requires matching component association', () {
    const request = RulAnalysisRequest(
      chargerIdentifier: 'SN-1',
      charger: charger,
      componentId: 'fan-1',
    );
    final parsed = RulAnalysisResponse.fromJson({
      'status': 'available',
      'result': {
        'chargerIdentifier': 'SN-1',
        'componentId': 'fan-1',
        'componentDisplayName': 'Cooling Fan',
        'remainingUsefulLife': 12,
        'unit': 'months',
      },
    }, request: request);
    expect(parsed.assessment?.componentId, 'fan-1');
    expect(parsed.assessment?.componentDisplayName, 'Cooling Fan');

    expect(
      () => RulAnalysisResponse.fromJson({
        'status': 'available',
        'result': {
          'chargerIdentifier': 'SN-1',
          'componentId': 'other',
          'remainingUsefulLife': 12,
          'unit': 'months',
        },
      }, request: request),
      throwsFormatException,
    );
  });

  test('request serializes only actual charger and available context', () {
    const request = RulAnalysisRequest(
      chargerIdentifier: 'SN-1',
      charger: charger,
    );
    final json = request.toJson();
    expect(json['charger']['identifier'], 'SN-1');
    expect(json.toString(), isNot(contains('operatingHours')));
    expect(json.toString(), isNot(contains('degradation')));
  });

  test('insufficient data is a typed response without an RUL value', () {
    final response = RulAnalysisResponse.fromJson({
      'status': 'insufficient_data',
      'message': 'No operating history.',
    }, request: chargerRequest);
    expect(response.outcome, RulResponseOutcome.insufficientData);
    expect(response.assessment?.status, RulAssessmentStatus.insufficientData);
    expect(response.assessment?.remainingUsefulLife, isNull);
  });

  test('unknown or incomplete response is malformed', () {
    expect(
      () => RulAnalysisResponse.fromJson({}, request: chargerRequest),
      throwsFormatException,
    );
  });
}
