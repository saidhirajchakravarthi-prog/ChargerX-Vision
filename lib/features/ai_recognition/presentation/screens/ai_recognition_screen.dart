// lib/features/ai_recognition/presentation/screens/ai_recognition_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/ai_recognition_provider.dart';
import '../../domain/models/ai_recognition_result.dart';
import '../../../chargers/domain/models/charger_model.dart';
import '../../../chargers/presentation/providers/selected_charger_provider.dart';

class AiRecognitionScreen extends ConsumerStatefulWidget {
  const AiRecognitionScreen({super.key});

  @override
  ConsumerState<AiRecognitionScreen> createState() =>
      _AiRecognitionScreenState();
}

class _AiRecognitionScreenState extends ConsumerState<AiRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Start with a clean state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiRecognitionProvider.notifier).reset();
    });
  }

  Future<void> _captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        if (!mounted) return;
        ref.read(aiRecognitionProvider.notifier).recognizeCharger(photo.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiRecognitionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recognition'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // State Display Area
              Expanded(child: _buildStateView(state)),

              const SizedBox(height: 24),

              // Action Buttons
              if (state.status == AiRecognitionStatus.ready ||
                  state.status == AiRecognitionStatus.aiUnavailable ||
                  state.status == AiRecognitionStatus.networkError ||
                  state.status == AiRecognitionStatus.notRecognized ||
                  state.status == AiRecognitionStatus.invalidResponse)
                FilledButton.icon(
                  onPressed: _captureImage,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capture Charger Photo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),

              if (state.status == AiRecognitionStatus.recognized)
                FilledButton.icon(
                  onPressed: () {
                    final charger = ChargerModel(
                      manufacturer: state.manufacturer,
                      model: state.model,
                      type: state.type,
                    );
                    ref
                        .read(selectedChargerProvider.notifier)
                        .selectCharger(charger);
                    context.go('/digital-twin', extra: charger);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirm & View Digital Twin'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),

              if (state.status == AiRecognitionStatus.recognized) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(aiRecognitionProvider.notifier).reset(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Scan Another'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateView(AiRecognitionResult state) {
    switch (state.status) {
      case AiRecognitionStatus.ready:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'Visual Charger Recognition',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Take a photo of the EV charger to automatically identify its manufacturer and model using AI.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case AiRecognitionStatus.uploading:
      case AiRecognitionStatus.analyzing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.imagePath != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(state.imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              state.status == AiRecognitionStatus.uploading
                  ? 'Uploading photo securely...'
                  : 'AI is analyzing the charger...',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        );

      case AiRecognitionStatus.recognized:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.imagePath != null)
                Container(
                  height: 250,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(state.imagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Charger Recognized',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildDetailRow('Manufacturer', state.manufacturer),
                      const Divider(),
                      _buildDetailRow('Model', state.model),
                      const Divider(),
                      _buildDetailRow('Type', state.type),
                      if (state.confidence != null) ...[
                        const Divider(),
                        _buildDetailRow(
                          'AI Confidence',
                          '${(state.confidence! * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case AiRecognitionStatus.aiUnavailable:
      case AiRecognitionStatus.networkError:
      case AiRecognitionStatus.notRecognized:
      case AiRecognitionStatus.invalidResponse:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.imagePath != null)
              Container(
                height: 150,
                width: 150,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(state.imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Icon(
              state.status == AiRecognitionStatus.aiUnavailable
                  ? Icons.cloud_off_rounded
                  : Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Recognition Failed',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'An unknown error occurred.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            if (state.status == AiRecognitionStatus.aiUnavailable) ...[
              const SizedBox(height: 16),
              Text(
                '(The Python/FastAPI backend is not running yet. Please connect to a valid endpoint.)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.isNotEmpty == true ? value! : 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
