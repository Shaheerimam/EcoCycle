import 'dart:typed_data';

import 'image_classifier_stub.dart'
    if (dart.library.io) 'image_classifier_mobile.dart'
    if (dart.library.js_interop) 'image_classifier_web.dart';

class PredictionResult {
  const PredictionResult({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

abstract class ImageClassifier {
  List<String> get labels;

  Future<void> load();

  Future<PredictionResult> classify(Uint8List imageBytes);

  void dispose();
}

ImageClassifier createClassifier() => createImageClassifier();
