import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/models/rul_analysis_request.dart';
import '../../domain/models/rul_analysis_response.dart';
import '../../domain/models/rul_assessment.dart';
import '../../domain/repositories/rul_repository.dart';

class DioRulRepository implements RulRepository {
  DioRulRepository({
    Dio? dio,
    String? baseUrl,
    String? endpointPath,
    Duration timeout = const Duration(seconds: 20),
    bool requireAuthentication = false,
    Future<String?> Function()? idTokenProvider,
  }) : _dio = dio ?? Dio(),
       _baseUrl =
           (baseUrl ?? const String.fromEnvironment('CHARGEX_RUL_API_BASE_URL'))
               .trim(),
       _endpointPath =
           (endpointPath ??
                   const String.fromEnvironment(
                     'CHARGEX_RUL_API_PATH',
                     defaultValue: '/v1/rul-analysis',
                   ))
               .trim(),
       _timeout = timeout,
       _requireAuthentication = requireAuthentication,
       _idTokenProvider = idTokenProvider;

  final Dio _dio;
  final String _baseUrl;
  final String _endpointPath;
  final Duration _timeout;
  final bool _requireAuthentication;
  final Future<String?> Function()? _idTokenProvider;

  bool get isConfigured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        _endpointPath.startsWith('/');
  }

  @override
  Future<RulAnalysisResponse> analyze(RulAnalysisRequest request) async {
    if (request.chargerIdentifier.trim().isEmpty) {
      return const RulAnalysisResponse(
        outcome: RulResponseOutcome.insufficientData,
        message: 'A charger identifier is required for RUL analysis.',
      );
    }
    if (!isConfigured) {
      return RulAnalysisResponse(
        outcome: RulResponseOutcome.unavailable,
        assessment: RulAssessment.unavailable(
          chargerIdentifier: request.chargerIdentifier,
          reason: 'RUL backend is not configured.',
        ),
        message: 'RUL backend is not configured.',
      );
    }

    try {
      final headers = <String, dynamic>{};
      if (_requireAuthentication) {
        final token = await _idTokenProvider?.call();
        if (token == null || token.isEmpty) {
          return const RulAnalysisResponse(
            outcome: RulResponseOutcome.backendError,
            message: 'Authentication is required for RUL analysis.',
          );
        }
        headers['Authorization'] = 'Bearer $token';
      }
      final url = '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$_endpointPath';
      final response = await _dio
          .post<Object?>(
            url,
            data: request.toJson(),
            options: Options(
              contentType: Headers.jsonContentType,
              headers: headers,
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
            ),
          )
          .timeout(_timeout);

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return _httpFailure(statusCode, request);
      }
      final body = response.data;
      if (body == null || body == '') {
        return const RulAnalysisResponse(
          outcome: RulResponseOutcome.malformedResponse,
          message: 'RUL backend returned an empty response.',
        );
      }
      try {
        final decoded = body is String ? jsonDecode(body) : body;
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('RUL response must be a JSON object.');
        }
        return RulAnalysisResponse.fromJson(decoded, request: request);
      } catch (_) {
        return const RulAnalysisResponse(
          outcome: RulResponseOutcome.malformedResponse,
          message: 'RUL backend returned an invalid response.',
        );
      }
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) return _httpFailure(statusCode, request);
      return RulAnalysisResponse(
        outcome: RulResponseOutcome.unavailable,
        assessment: RulAssessment.unavailable(
          chargerIdentifier: request.chargerIdentifier,
          reason: 'RUL backend could not be reached.',
        ),
        message:
            error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'RUL backend request timed out.'
            : 'RUL backend could not be reached.',
      );
    } on TimeoutException {
      return RulAnalysisResponse(
        outcome: RulResponseOutcome.unavailable,
        assessment: RulAssessment.unavailable(
          chargerIdentifier: request.chargerIdentifier,
          reason: 'RUL backend request timed out.',
        ),
        message: 'RUL backend request timed out.',
      );
    } catch (_) {
      return const RulAnalysisResponse(
        outcome: RulResponseOutcome.backendError,
        message: 'RUL analysis request could not be completed.',
      );
    }
  }

  RulAnalysisResponse _httpFailure(int statusCode, RulAnalysisRequest request) {
    if (statusCode == 422) {
      return RulAnalysisResponse(
        outcome: RulResponseOutcome.insufficientData,
        assessment: RulAssessment.insufficientData(
          chargerIdentifier: request.chargerIdentifier,
          reason: 'RUL backend reports insufficient data.',
        ),
        message: 'RUL backend reports insufficient data.',
      );
    }
    if (statusCode == 404) {
      return RulAnalysisResponse(
        outcome: RulResponseOutcome.unavailable,
        assessment: RulAssessment.unavailable(
          chargerIdentifier: request.chargerIdentifier,
          reason: 'RUL endpoint is unavailable.',
        ),
        message: 'RUL endpoint is unavailable.',
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return const RulAnalysisResponse(
        outcome: RulResponseOutcome.backendError,
        message: 'RUL backend denied the request.',
      );
    }
    return RulAnalysisResponse(
      outcome: RulResponseOutcome.backendError,
      message: statusCode >= 500
          ? 'RUL backend encountered an error.'
          : 'RUL request failed with status $statusCode.',
    );
  }
}
