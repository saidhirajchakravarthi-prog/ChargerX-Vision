// lib/features/ai_recognition/domain/models/ai_recognition_result.dart

enum AiRecognitionStatus {
  ready,
  capturing,
  uploading,
  analyzing,
  recognized,
  notRecognized,
  networkError,
  aiUnavailable,
  invalidResponse,
}

class AiRecognitionResult {
  final String? manufacturer;
  final String? model;
  final String? type;
  final double? confidence;
  final AiRecognitionStatus status;
  final String? errorMessage;
  final String? imagePath;

  const AiRecognitionResult({
    this.manufacturer,
    this.model,
    this.type,
    this.confidence,
    this.status = AiRecognitionStatus.ready,
    this.errorMessage,
    this.imagePath,
  });

  AiRecognitionResult copyWith({
    String? manufacturer,
    String? model,
    String? type,
    double? confidence,
    AiRecognitionStatus? status,
    String? errorMessage,
    String? imagePath,
  }) {
    return AiRecognitionResult(
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
