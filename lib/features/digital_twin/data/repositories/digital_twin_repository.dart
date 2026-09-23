// lib/features/digital_twin/data/repositories/digital_twin_repository.dart
import 'package:dio/dio.dart';
import '../domain/models/digital_twin_model.dart';
import '../../../chargers/domain/models/charger_model.dart';

class DigitalTwinRepository {
  final Dio _dio;
  
  // Future URL for the Twin Registry Backend
  static const String _baseUrl = 'https://api.chargexvision.local/v1/twins';

  DigitalTwinRepository(this._dio);

  Future<DigitalTwinModel?> getDigitalTwinForCharger(ChargerModel charger) async {
    // Determine the query parameters.
    // Use the manufacturer and model if available. Otherwise, use raw QR if that's all we have.
    if (!charger.isRecognized && charger.rawQrIdentifier == null) {
      return null; // Cannot query without some identifier
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          if (charger.manufacturer != null) 'manufacturer': charger.manufacturer,
          if (charger.model != null) 'model': charger.model,
          if (charger.rawQrIdentifier != null) 'raw_qr': charger.rawQrIdentifier,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data is Map<String, dynamic>) {
          // If the backend returns a matching twin
          return DigitalTwinModel.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError) {
        // Backend not available yet. 
        // We do NOT substitute a fake charger, we return null to indicate failure.
        throw Exception('Digital Twin Registry service is not connected yet.');
      }
      throw Exception(e.message ?? 'Unknown network error');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching the Digital Twin.');
    }
  }
}
