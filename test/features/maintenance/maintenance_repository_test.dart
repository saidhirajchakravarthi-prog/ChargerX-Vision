import 'dart:typed_data';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/maintenance/data/repositories/dio_maintenance_repository.dart';
import 'package:chargex_vision/features/maintenance/domain/models/maintenance_readiness.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'unconfigured backend and missing identifier return no records',
    () async {
      final repository = DioMaintenanceRepository(baseUrl: '');
      final missing = await repository.fetchForCharger(' ');
      final unconfigured = await repository.fetchForCharger('S-1');
      expect(missing.status, MaintenanceReadinessStatus.missingChargerIdentity);
      expect(unconfigured.status, MaintenanceReadinessStatus.notConfigured);
      expect(unconfigured.records, isEmpty);
    },
  );

  test(
    'configured backend returns parsed real records and query identity',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _Adapter((options) async {
        expect(options.queryParameters['chargerIdentifier'], 'S-1');
        return ResponseBody.fromString(
          '{"status":"available","chargerIdentifier":"S-1","records":[{"recordId":"R-1","recordType":"repair","repairDetails":"Backend supplied"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final repository = DioMaintenanceRepository(
        dio: dio,
        baseUrl: 'https://service.test',
      );
      final result = await repository.fetchForCharger('S-1');
      expect(result.status, MaintenanceReadinessStatus.recordsAvailable);
      expect(result.records.single.repairDetails, 'Backend supplied');
    },
  );

  test('configured empty response remains an empty result', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(
      (options) async => ResponseBody.fromString(
        '{"status":"empty","chargerIdentifier":"S-1","records":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final result = await DioMaintenanceRepository(
      dio: dio,
      baseUrl: 'https://service.test',
    ).fetchForCharger('S-1');
    expect(result.status, MaintenanceReadinessStatus.noRecords);
    expect(result.records, isEmpty);
  });

  test('timeout and malformed response remain record-free', () async {
    final timeoutDio = Dio();
    timeoutDio.httpClientAdapter = _Adapter(
      (options) => Completer<ResponseBody>().future,
    );
    final timeoutRepo = DioMaintenanceRepository(
      dio: timeoutDio,
      baseUrl: 'https://service.test',
      timeout: const Duration(milliseconds: 5),
    );
    final timedOut = await timeoutRepo.fetchForCharger('S-1');
    expect(timedOut.status, MaintenanceReadinessStatus.unavailable);
    expect(timedOut.records, isEmpty);

    final malformedDio = Dio();
    malformedDio.httpClientAdapter = _Adapter(
      (options) async => ResponseBody.fromString('{bad', 200),
    );
    final malformed = await DioMaintenanceRepository(
      dio: malformedDio,
      baseUrl: 'https://service.test',
    ).fetchForCharger('S-1');
    expect(malformed.status, MaintenanceReadinessStatus.error);
    expect(malformed.records, isEmpty);
  });

  test('network error is unavailable', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final result = await DioMaintenanceRepository(
      dio: dio,
      baseUrl: 'https://service.test',
    ).fetchForCharger('S-1');
    expect(result.status, MaintenanceReadinessStatus.unavailable);
    expect(result.records, isEmpty);
  });

  test(
    'unauthorized and server-error responses never create records',
    () async {
      for (final status in [401, 403, 500]) {
        final dio = Dio();
        dio.httpClientAdapter = _Adapter(
          (options) async => ResponseBody.fromString(
            '{"error":{"code":"<illustrative>"}}',
            status,
          ),
        );
        final result = await DioMaintenanceRepository(
          dio: dio,
          baseUrl: 'https://service.test',
        ).fetchForCharger('S-1');

        expect(result.status, MaintenanceReadinessStatus.error);
        expect(result.records, isEmpty);
      }
    },
  );
}
