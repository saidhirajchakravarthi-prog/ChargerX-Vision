import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/models/fault_analysis_request.dart';
import '../../domain/models/fault_analysis_response.dart';

class FaultAnalysisRepository {
  FaultAnalysisRepository({
    Dio? dio,
    String? baseUrl,
    String endpointPath = '/v1/fault-analysis',
    Duration timeout = const Duration(seconds: 20),
    bool requireAuthentication = false,
    Future<String?> Function()? idTokenProvider,
  }) : _dio = dio ?? Dio(),
       _baseUrl =
           (baseUrl ??
                   const String.fromEnvironment('CHARGEX_FAULT_API_BASE_URL'))
               .trim(),
       _endpointPath = endpointPath,
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
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<FaultAnalysisResponse> analyze(FaultAnalysisRequest request) async {
    if (!isConfigured) {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendUnavailable,
        message: 'Fault analysis service is not configured.',
      );
    }

    try {
      final url =
          '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}'
          '$_endpointPath';
      final path = request.localEvidencePath;
      Object data;
      Options options;
      Map<String, dynamic> headers = const {};
      if (_requireAuthentication) {
        final token = await _idTokenProvider?.call();
        if (token == null || token.isEmpty) {
          return const FaultAnalysisResponse(
            outcome: FaultAnalysisOutcome.backendError,
            message: 'Sign in is required to use the analysis service.',
          );
        }
        headers = {'Authorization': 'Bearer $token'};
      }
      if (path != null) {
        final file = File(path);
        if (!await file.exists()) {
          return const FaultAnalysisResponse(
            outcome: FaultAnalysisOutcome.invalidRequest,
            message: 'The selected evidence file is no longer available.',
          );
        }
        data = FormData.fromMap({
          'request': jsonEncode(request.toJson()),
          'evidence_file': await MultipartFile.fromFile(path),
        });
        options = Options(contentType: 'multipart/form-data', headers: headers);
      } else {
        data = request.toJson();
        options = Options(
          contentType: Headers.jsonContentType,
          headers: headers,
        );
      }

      final response = await _dio
          .post<Object?>(url, data: data, options: options)
          .timeout(_timeout);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) return _httpFailure(status);
      final body = response.data;
      if (body == null || body == '') {
        return const FaultAnalysisResponse(
          outcome: FaultAnalysisOutcome.backendError,
          message: 'The analysis service returned an empty response.',
        );
      }
      final decoded = body is String ? jsonDecode(body) : body;
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object response.');
      }
      return FaultAnalysisResponse.fromJson(decoded);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null) return _httpFailure(status);
      return FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendUnavailable,
        message:
            error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout
            ? 'The analysis service timed out.'
            : 'The analysis service could not be reached.',
      );
    } on TimeoutException {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendUnavailable,
        message: 'The analysis service timed out.',
      );
    } on FormatException {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendError,
        message: 'The analysis service returned an invalid response.',
      );
    } catch (_) {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendError,
        message: 'The analysis request could not be completed.',
      );
    }
  }

  FaultAnalysisResponse _httpFailure(int status) {
    if (status == 400 || status == 409 || status == 422) {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.invalidRequest,
        message: 'The analysis service rejected the request.',
      );
    }
    if (status == 404) {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendUnavailable,
        message: 'The analysis endpoint is unavailable.',
      );
    }
    if (status == 401 || status == 403) {
      return const FaultAnalysisResponse(
        outcome: FaultAnalysisOutcome.backendError,
        message: 'The analysis service denied the request.',
      );
    }
    return FaultAnalysisResponse(
      outcome: FaultAnalysisOutcome.backendError,
      message: status >= 500
          ? 'The analysis service encountered an error.'
          : 'The analysis request failed.',
    );
  }
}
