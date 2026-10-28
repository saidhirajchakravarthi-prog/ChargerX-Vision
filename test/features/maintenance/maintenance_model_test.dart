import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';

void main() {
  const chargerId = 'SERIAL-1';

  test(
    'parses real returned record fields without requiring optional dates',
    () {
      final value = MaintenanceReadiness.fromJson({
        'status': 'available',
        'chargerIdentifier': chargerId,
        'records': [
          {
            'recordId': 'rec-1',
            'recordType': 'inspection',
            'status': 'complete',
          },
        ],
      }, requestedChargerIdentifier: chargerId);
      expect(value.status, MaintenanceReadinessStatus.recordsAvailable);
      expect(value.records.single.recordId, 'rec-1');
      expect(value.records.single.serviceDate, isNull);
      expect(value.records.single.workOrderId, isNull);
    },
  );

  test('valid empty response creates no records', () {
    final value = MaintenanceReadiness.fromJson({
      'status': 'available',
      'chargerIdentifier': chargerId,
      'records': <Object>[],
    }, requestedChargerIdentifier: chargerId);
    expect(value.status, MaintenanceReadinessStatus.noRecords);
    expect(value.records, isEmpty);
  });

  test('missing or mismatched charger identity is rejected', () {
    expect(
      () => MaintenanceReadiness.fromJson({
        'status': 'available',
        'records': [],
      }, requestedChargerIdentifier: chargerId),
      throwsFormatException,
    );
    expect(
      () => MaintenanceReadiness.fromJson({
        'status': 'available',
        'chargerIdentifier': 'OTHER',
        'records': [],
      }, requestedChargerIdentifier: chargerId),
      throwsFormatException,
    );
  });

  test('malformed records and optional fields are rejected', () {
    expect(
      () => MaintenanceReadiness.fromJson({
        'status': 'available',
        'chargerIdentifier': chargerId,
        'records': [
          {'recordId': 'rec-1'},
        ],
      }, requestedChargerIdentifier: chargerId),
      throwsFormatException,
    );
    expect(
      () => MaintenanceRecord.fromJson({
        'recordId': 'rec-1',
        'recordType': 'repair',
        'serviceDate': 'not-a-date',
      }),
      throwsFormatException,
    );
  });

  test('unavailable response never becomes a maintenance record', () {
    final value = MaintenanceReadiness.fromJson({
      'status': 'unavailable',
      'chargerIdentifier': chargerId,
    }, requestedChargerIdentifier: chargerId);
    expect(value.status, MaintenanceReadinessStatus.unavailable);
    expect(value.records, isEmpty);
  });
}
