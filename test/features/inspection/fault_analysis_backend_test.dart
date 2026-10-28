import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/inspection/data/adapters/backend_inspection_analysis_adapter.dart';
import 'package:chargex_vision/features/inspection/data/repositories/fault_analysis_repository.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_analysis_request.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_analysis_response.dart';

const component = DigitalTwinComponent(
  componentId: 'fan-01',
  componentType: 'Cooling Fan',
  displayName: 'Cooling Fan',
  assetNodeIdentifier: 'fan-node-01',
  description: 'Cooling assembly fan',
);

Dio respondingWith(Object? body, {int status = 200, DioExceptionType? error}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (error != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: error,
              response: status == 200
                  ? null
                  : Response(requestOptions: options, statusCode: status),
            ),
          );
          return;
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: status, data: body),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'request sends existing component/evidence metadata without local path',
    () {
      const request = FaultAnalysisRequest(
        componentId: 'fan-01',
        componentType: 'Cooling Fan',
        assetNodeIdentifier: 'fan-node-01',
        evidence: EvidenceSourceData(
          type: EvidenceSourceType.cameraImage,
          label: 'Gallery image selected',
          metadata: {'path': 'C:/private/evidence.jpg', 'format': 'jpeg'},
        ),
      );
      final json = request.toJson();
      expect(json['component']['component_id'], 'fan-01');
      expect(json['evidence']['metadata'], {'format': 'jpeg'});
      expect(json.toString(), isNot(contains('C:/private')));
      expect(request.localEvidencePath, 'C:/private/evidence.jpg');
    },
  );

  test('unconfigured backend is explicitly unavailable', () async {
    final result = await FaultAnalysisRepository(
      baseUrl: '',
    ).analyze(const FaultAnalysisRequest(componentId: 'fan-01'));
    expect(result.outcome, FaultAnalysisOutcome.backendUnavailable);
  });

  test(
    'selected evidence is uploaded to the API as a multipart file',
    () async {
      final directory = await Directory.systemTemp.createTemp('chargex-fault-');
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/evidence.jpg');
      await image.writeAsBytes([1, 2, 3]);
      Object? sentData;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentData = options.data;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'no_fault_detected'},
              ),
            );
          },
        ),
      );
      final repository = FaultAnalysisRepository(
        dio: dio,
        baseUrl: 'https://backend.example',
      );

      await repository.analyze(
        FaultAnalysisRequest(
          componentId: component.componentId,
          evidence: EvidenceSourceData(
            type: EvidenceSourceType.cameraImage,
            label: 'Gallery image selected',
            metadata: {'path': image.path},
          ),
        ),
      );

      final form = sentData! as FormData;
      expect(form.files.single.key, 'evidence_file');
      final requestJson =
          jsonDecode(
                form.fields
                    .singleWhere((field) => field.key == 'request')
                    .value,
              )
              as Map<String, dynamic>;
      expect(requestJson['component']['component_id'], component.componentId);
      expect(requestJson.toString(), isNot(contains(image.path)));
    },
  );

  test('parses a real fault response and preserves absent location', () async {
    final repo = FaultAnalysisRepository(
      dio: respondingWith({
        'status': 'fault_detected',
        'fault': {'faultType': 'fan failure', 'componentId': 'fan-01'},
      }),
      baseUrl: 'https://backend.example',
    );
    final adapter = BackendInspectionAnalysisAdapter(repo);
    final inspection = await adapter.inspectComponent(component);
    final fault = await adapter.fetchActiveFaultForComponent('fan-01');
    expect(inspection.status, InspectionStatus.completed);
    expect(fault?.componentId, 'fan-01');
    expect(fault?.locationDescription, isNull);
    expect(inspection.confidence, isNull);
    expect(inspection.severity, isNull);
  });

  test(
    'no-fault response remains a clean state without active fault',
    () async {
      final adapter = BackendInspectionAnalysisAdapter(
        FaultAnalysisRepository(
          dio: respondingWith({'status': 'no_fault_detected'}),
          baseUrl: 'https://backend.example',
        ),
      );
      final inspection = await adapter.inspectComponent(component);
      expect(inspection.status, InspectionStatus.noFaultDetected);
      expect(await adapter.fetchActiveFaultForComponent('fan-01'), isNull);
    },
  );

  test(
    'malformed responses and backend failures never become faults',
    () async {
      final malformed = await FaultAnalysisRepository(
        dio: respondingWith({'unexpected': true}),
        baseUrl: 'https://backend.example',
      ).analyze(const FaultAnalysisRequest(componentId: 'fan-01'));
      expect(malformed.outcome, FaultAnalysisOutcome.backendError);
      expect(malformed.faultResult, isNull);

      final unavailable = await FaultAnalysisRepository(
        dio: respondingWith(
          null,
          status: 503,
          error: DioExceptionType.badResponse,
        ),
        baseUrl: 'https://backend.example',
      ).analyze(const FaultAnalysisRequest(componentId: 'fan-01'));
      expect(unavailable.outcome, FaultAnalysisOutcome.backendError);
      expect(unavailable.faultResult, isNull);
    },
  );

  test('unauthorized and server-error responses never become faults', () async {
    for (final status in [401, 403, 500]) {
      final result = await FaultAnalysisRepository(
        dio: respondingWith(
          null,
          status: status,
          error: DioExceptionType.badResponse,
        ),
        baseUrl: 'https://backend.example',
      ).analyze(const FaultAnalysisRequest(componentId: 'fan-01'));

      expect(result.outcome, FaultAnalysisOutcome.backendError);
      expect(result.faultResult, isNull);
    }
  });

  test(
    'timeout and wrong component association do not localize a fault',
    () async {
      final timeout = await FaultAnalysisRepository(
        dio: respondingWith(null, error: DioExceptionType.receiveTimeout),
        baseUrl: 'https://backend.example',
      ).analyze(const FaultAnalysisRequest(componentId: 'fan-01'));
      expect(timeout.outcome, FaultAnalysisOutcome.backendUnavailable);

      final adapter = BackendInspectionAnalysisAdapter(
        FaultAnalysisRepository(
          dio: respondingWith({
            'status': 'fault_detected',
            'fault': {
              'faultType': 'fan failure',
              'componentId': 'other-component',
            },
          }),
          baseUrl: 'https://backend.example',
        ),
      );
      final inspection = await adapter.inspectComponent(component);
      expect(inspection.status, InspectionStatus.failed);
      expect(await adapter.fetchActiveFaultForComponent('fan-01'), isNull);
    },
  );

  test('typed response rejects fault status without a fault object', () {
    expect(
      () => FaultAnalysisResponse.fromJson({'status': 'fault_detected'}),
      throwsFormatException,
    );
  });
}
