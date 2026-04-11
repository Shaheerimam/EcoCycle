
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_classifier.dart';

ImageClassifier createImageClassifier() => _MobileImageClassifier();

class _MobileImageClassifier implements ImageClassifier {
  Interpreter? _interpreter;
  List<String> _labels = const <String>[];

  @override
  List<String> get labels => _labels;

  @override
  Future<void> load() async {
    final interpreter = await Interpreter.fromAsset(
      'asset/model_unquant.tflite',
    );
    final labelsText = await rootBundle.loadString('asset/labels.txt');

    _labels = labelsText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(RegExp(r'\s+'));
          return parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
        })
        .toList();

    _interpreter = interpreter;
  }

  @override
  Future<PredictionResult> classify(Uint8List imageBytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Interpreter is not initialized.');
    }

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    final inputShape = inputTensor.shape;
    if (inputShape.length != 4) {
      throw StateError(
        'Expected a 4D input tensor, got ${inputShape.toString()}.',
      );
    }

    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];

    if (channels != 3) {
      throw StateError(
        'This app expects an RGB model, but the model has $channels channels.',
      );
    }

    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw StateError('Could not decode the selected image.');
    }

    final processedImage = img.bakeOrientation(decodedImage);
    final resizedImage = img.copyResize(
      processedImage,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    final input = List.generate(height, (y) {
      return List.generate(width, (x) {
        final pixel = resizedImage.getPixel(x, y);
        return <double>[pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      });
    });

    final outputSize = outputTensor.shape.reduce(
      (value, element) => value * element,
    );
    final output = List.generate(1, (_) => List.filled(outputSize, 0.0));

    interpreter.run([input], output);

    final scores = output.first.cast<num>();
    final bestIndex = _argMax(scores);
    final bestScore = scores[bestIndex].toDouble();
    final label = bestIndex < _labels.length
        ? _labels[bestIndex]
        : 'Class $bestIndex';

    return PredictionResult(label: label, confidence: bestScore);
  }

  int _argMax(List<num> scores) {
    var bestIndex = 0;
    var bestValue = scores.first.toDouble();

    for (var index = 1; index < scores.length; index++) {
      final value = scores[index].toDouble();
      if (value > bestValue) {
        bestValue = value;
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
