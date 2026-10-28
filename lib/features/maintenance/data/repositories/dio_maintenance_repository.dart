import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/models/maintenance_readiness.dart';
import '../../domain/repositories/maintenance_repository.dart';

class DioMaintenanceRepository implements MaintenanceRepository {
  DioMaintenanceRepository({
    Dio? dio,
    String? baseUrl,
    String? endpointPath,
    Duration timeout = const Duration(seconds: 20),
    bool requireAuthentication = false,
    Future<String?> Function()? idTokenProvider,
  }) : _dio = dio ?? Dio(),
       _baseUrl =
           (baseUrl ??
                   const String.fromEnvironment(
                     'CHARGEX_MAINTENANCE_API_BASE_URL',
                   ))
               .trim(),
       _endpointPath =
           (endpointPath ??
                   const String.fromEnvironment(
                     'CHARGEX_MAINTENANCE_API_PATH',
                     defaultValue: '/v1/maintenance-records',
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
  Future<MaintenanceReadiness> fetchForCharger(
    String chargerIdentifier, {
    List<FaultAnalysisRecommendation> faultRecommendations = const [],
  }) async {
    final identifier = chargerIdentifier.trim();
    if (identifier.isEmpty) {
      return MaintenanceReadiness.missingChargerIdentity();
    }
    if (!isConfigured) {
      return MaintenanceReadiness.notConfigured(
        chargerIdentifier: identifier,
        faultRecommendations: faultRecommendations,
      );
    }

    try {
      final headers = <String, dynamic>{};
      if (_requireAuthentication) {
        final token = await _idTokenProvider?.call();
        if (token == null || token.isEmpty) {
          return MaintenanceReadiness.error(
            chargerIdentifier: identifier,
            message: 'Authentication is required for maintenance records.',
            faultRecommendations: faultRecommendations,
          );
        }
        headers['Authorization'] = 'Bearer $token';
      }
      final url = '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$_endpointPath';
      final response = await _dio
          .get<Object?>(
            url,
            queryParameters: {'chargerIdentifier': identifier},
            options: Options(
              headers: headers,
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
            ),
          )
          .timeout(_timeout);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return _httpFailure(status, identifier, faultRecommendations);
      }
      final body = response.data;
      if (body == null || body == '') {
        return MaintenanceReadiness.error(
          chargerIdentifier: identifier,
          message: 'Maintenance service returned an empty response.',
          faultRecommendations: faultRecommendations,
        );
      }
      try {
        final decoded = body is String ? jsonDecode(body) : body;
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object.');
        }
        return MaintenanceReadiness.fromJson(
          decoded,
          requestedChargerIdentifier: identifier,
          faultRecommendations: faultRecommendations,
        );
      } catch (_) {
        return MaintenanceReadiness.error(
          chargerIdentifier: identifier,
          message: 'Maintenance service returned malformed data.',
          faultRecommendations: faultRecommendations,
        );
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null) {
        return _httpFailure(status, identifier, faultRecommendations);
      }
      return MaintenanceReadiness.unavailable(
        chargerIdentifier: identifier,
        message:
            error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'Maintenance service request timed out.'
            : 'Maintenance service is currently unavailable.',
        faultRecommendations: faultRecommendations,
      );
    } on TimeoutException {
      return MaintenanceReadiness.unavailable(
        chargerIdentifier: identifier,
        message: 'Maintenance service request timed out.',
        faultRecommendations: faultRecommendations,
      );
    } catch (_) {
      return MaintenanceReadiness.error(
        chargerIdentifier: identifier,
        message: 'Maintenance request could not be completed.',
        faultRecommendations: faultRecommendations,
      );
    }
  }

  MaintenanceReadiness _httpFailure(
    int status,
    String identifier,
    List<FaultAnalysisRecommendation> recommendations,
  ) {
    if (status == 404) {
      return MaintenanceReadiness.unavailable(
        chargerIdentifier: identifier,
        message: 'Maintenance service endpoint is unavailable.',
        faultRecommendations: recommendations,
      );
    }
    if (status == 401 || status == 403) {
      return MaintenanceReadiness.error(
        chargerIdentifier: identifier,
        message: 'Maintenance service denied the request.',
        faultRecommendations: recommendations,
      );
    }
    return MaintenanceReadiness.error(
      chargerIdentifier: identifier,
      message: status >= 500
          ? 'Maintenance service encountered an error.'
          : 'Maintenance request failed.',
      faultRecommendations: recommendations,
    );
  }
}
