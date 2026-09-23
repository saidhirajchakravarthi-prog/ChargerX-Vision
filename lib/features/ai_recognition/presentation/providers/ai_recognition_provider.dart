// lib/features/ai_recognition/presentation/providers/ai_recognition_provider.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_recognition_repository.dart';
import '../../domain/models/ai_recognition_result.dart';

// Provide a singleton Dio instance for this feature (or could be global)
final _dioProvider = Provider<Dio>((ref) => Dio());

final aiRecognitionRepositoryProvider = Provider<AiRecognitionRepository>((
  ref,
) {
  return AiRecognitionRepository(ref.read(_dioProvider));
});

final aiRecognitionProvider =
    NotifierProvider<AiRecognitionNotifier, AiRecognitionResult>(
      AiRecognitionNotifier.new,
    );

class AiRecognitionNotifier extends Notifier<AiRecognitionResult> {
  @override
  AiRecognitionResult build() {
    return const AiRecognitionResult();
  }

  void reset() {
    state = const AiRecognitionResult();
  }

  Future<void> recognizeCharger(String imagePath) async {
    state = state.copyWith(
      status: AiRecognitionStatus.uploading,
      imagePath: imagePath,
      errorMessage: null,
    );

    // Minor delay to show uploading state for UI transition
    await Future.delayed(const Duration(milliseconds: 500));

    state = state.copyWith(status: AiRecognitionStatus.analyzing);

    final repository = ref.read(aiRecognitionRepositoryProvider);
    final result = await repository.recognizeCharger(File(imagePath));

    state = result;
  }
}
