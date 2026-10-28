import 'dart:io';

import 'package:chargex_vision/features/ai_recognition/data/repositories/ai_recognition_repository.dart';
import 'package:chargex_vision/features/ai_recognition/domain/models/ai_recognition_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recognition and explicit no-match are distinct mock outcomes',
    () async {
      final directory = await Directory.systemTemp.createTemp('chargex-ai-');
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/charger.jpg');
      await image.writeAsBytes([1, 2, 3]);

      Future<AiRecognitionResult> recognize(Object responseBody) {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: responseBody,
                ),
              ),
            ),
          );
        return AiRecognitionRepository(
          dio,
          endpointUrl: 'https://api.example.invalid/v1/recognize',
        ).recognizeCharger(image);
      }

      final recognized = await recognize({
        'recognized': true,
        'manufacturer': 'Fixture manufacturer',
      });
      final notRecognized = await recognize({'recognized': false});

      expect(recognized.status, AiRecognitionStatus.recognized);
      expect(recognized.manufacturer, 'Fixture manufacturer');
      expect(notRecognized.status, AiRecognitionStatus.notRecognized);
    },
  );

  test(
    'unconfigured AI endpoint returns unavailable without a request',
    () async {
      var requestCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount++;
              handler.resolve(
                Response(requestOptions: options, statusCode: 200),
              );
            },
          ),
        );
      final result = await AiRecognitionRepository(
        dio,
        endpointUrl: '',
      ).recognizeCharger(File('image-not-read-when-unconfigured.jpg'));

      expect(result.status, AiRecognitionStatus.aiUnavailable);
      expect(result.errorMessage, contains('not configured'));
      expect(requestCount, 0);
    },
  );

  test(
    'malformed successful response is not treated as not recognized',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'unexpected': true},
              ),
            ),
          ),
        );
      final directory = await Directory.systemTemp.createTemp('chargex-ai-');
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/charger.jpg');
      await image.writeAsBytes([1, 2, 3]);

      final result = await AiRecognitionRepository(
        dio,
        endpointUrl: 'https://api.example.invalid/v1/recognize',
      ).recognizeCharger(image);

      expect(result.status, AiRecognitionStatus.invalidResponse);
    },
  );
}
