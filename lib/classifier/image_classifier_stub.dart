import 'dart:typed_data';

import 'image_classifier.dart';

ImageClassifier createImageClassifier() => _UnsupportedImageClassifier();

class _UnsupportedImageClassifier implements ImageClassifier {
  @override
  List<String> get labels => const <String>[];

  @override
  Future<void> load() async {
    throw UnsupportedError(
      'Image classification is not supported on this platform.',
    );
  }

  @override
  Future<PredictionResult> classify(Uint8List imageBytes) async {
    throw UnsupportedError(
      'Image classification is not supported on this platform.',
    );
  }

  @override
  void dispose() {}
}
