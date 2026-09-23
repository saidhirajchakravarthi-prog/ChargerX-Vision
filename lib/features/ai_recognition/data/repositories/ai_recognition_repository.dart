// lib/features/ai_recognition/data/repositories/ai_recognition_repository.dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/models/ai_recognition_result.dart';

class AiRecognitionRepository {
  final Dio _dio;

  // Future URL for the Python/FastAPI backend
  static const String _baseUrl = 'https://api.chargexvision.local/v1/recognize';

  AiRecognitionRepository(this._dio);

  Future<AiRecognitionResult> recognizeCharger(File imageFile) async {
    try {
      // Prepare the data for upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
      });

      // Attempt to connect to the backend
      final response = await _dio.post(
        _baseUrl,
        data: formData,
        options: Options(
          // Short timeout since this is local/simulated for now
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['recognized'] == true) {
          return AiRecognitionResult(
            status: AiRecognitionStatus.recognized,
            manufacturer: data['manufacturer'] as String?,
            model: data['model'] as String?,
            type: data['type'] as String?,
            confidence: (data['confidence'] as num?)?.toDouble(),
            imagePath: imageFile.path,
          );
        } else {
          return AiRecognitionResult(
            status: AiRecognitionStatus.notRecognized,
            imagePath: imageFile.path,
            errorMessage: 'Charger not recognized from image.',
          );
        }
      } else {
        return AiRecognitionResult(
          status: AiRecognitionStatus.invalidResponse,
          imagePath: imageFile.path,
          errorMessage: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return AiRecognitionResult(
          status: AiRecognitionStatus.aiUnavailable,
          imagePath: imageFile.path,
          errorMessage: 'AI recognition service is not connected yet.',
        );
      }
      return AiRecognitionResult(
        status: AiRecognitionStatus.networkError,
        imagePath: imageFile.path,
        errorMessage: e.message ?? 'Unknown network error',
      );
    } catch (e) {
      return AiRecognitionResult(
        status: AiRecognitionStatus.invalidResponse,
        imagePath: imageFile.path,
        errorMessage: 'An unexpected error occurred.',
      );
    }
  }
}
