import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/rul/data/repositories/dio_rul_repository.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_request.dart';
import 'package:chargex_vision/features/rul/domain/models/rul_analysis_response.dart';

const request = RulAnalysisRequest(
  chargerIdentifier: 'SN-1',
  charger: ChargerModel(serialNumber: 'SN-1'),
);

Dio dioReply(Object? body, {DioExceptionType? error, int status = 200}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (error != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: error,
              response: error == DioExceptionType.badResponse
                  ? Response(
                      requestOptions: options,
                      statusCode: status,
                      data: body,
                    )
                  : null,
            ),
          );
        } else {
          handler.resolve(
            Response(requestOptions: options, statusCode: status, data: body),
          );
        }
      },
    ),
  );
  return dio;
}

void main() {
  test('unconfigured RUL API is unavailable and has no value', () async {
    final response = await DioRulRepository(baseUrl: '').analyze(request);
    expect(response.outcome, RulResponseOutcome.unavailable);
    expect(response.assessment?.remainingUsefulLife, isNull);
  });

  test(
    'backend insufficient-data response remains unavailable as a value',
    () async {
      final response = await DioRulRepository(
        dio: dioReply({'status': 'insufficient_data'}),
        baseUrl: 'https://rul.example',
      ).analyze(request);
      expect(response.outcome, RulResponseOutcome.insufficientData);
      expect(response.assessment?.remainingUsefulLife, isNull);
    },
  );

  test('malformed backend response never becomes an assessment', () async {
    final response = await DioRulRepository(
      dio: dioReply({'status': 'available', 'result': {}}),
      baseUrl: 'https://rul.example',
    ).analyze(request);
    expect(response.outcome, RulResponseOutcome.malformedResponse);
    expect(response.assessment, isNull);
  });

  test('request timeout becomes unavailable rather than a value', () async {
    final response = await DioRulRepository(
      dio: dioReply(null, error: DioExceptionType.receiveTimeout),
      baseUrl: 'https://rul.example',
    ).analyze(request);
    expect(response.outcome, RulResponseOutcome.unavailable);
    expect(response.assessment?.remainingUsefulLife, isNull);
  });

  test('required auth without a token is an error', () async {
    final response = await DioRulRepository(
      dio: dioReply(null),
      baseUrl: 'https://rul.example',
      requireAuthentication: true,
      idTokenProvider: () async => null,
    ).analyze(request);
    expect(response.outcome, RulResponseOutcome.backendError);
    expect(response.assessment, isNull);
  });

  test(
    'unauthorized and server-error responses never become RUL values',
    () async {
      for (final status in [401, 403, 500]) {
        final response = await DioRulRepository(
          dio: dioReply(
            null,
            error: DioExceptionType.badResponse,
            status: status,
          ),
          baseUrl: 'https://rul.example',
        ).analyze(request);

        expect(response.outcome, RulResponseOutcome.backendError);
        expect(response.assessment?.remainingUsefulLife, isNull);
      }
    },
  );
}
