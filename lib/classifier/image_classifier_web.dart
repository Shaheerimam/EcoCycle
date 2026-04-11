import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'image_classifier.dart';

@JS('ecoCycleLoadModel')
external JSPromise<JSAny?> _ecoCycleLoadModel();

@JS('ecoCycleGetLabels')
external JSPromise<JSString> _ecoCycleGetLabels();

@JS('ecoCycleClassifyImageBytes')
external JSPromise<JSString> _ecoCycleClassifyImageBytes(
  JSUint8Array imageBytes,
);

ImageClassifier createImageClassifier() => _WebImageClassifier();

class _WebImageClassifier implements ImageClassifier {
  List<String> _labels = const <String>[];

  @override
  List<String> get labels => _labels;

  @override
  Future<void> load() async {
    await _ecoCycleLoadModel().toDart;
    final labelsRaw = (await _ecoCycleGetLabels().toDart).toDart;
    _labels = labelsRaw
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Future<PredictionResult> classify(Uint8List imageBytes) async {
    final scoresRaw = (await _ecoCycleClassifyImageBytes(
      imageBytes.toJS,
    ).toDart).toDart;

    final scores = (jsonDecode(scoresRaw) as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList();

    if (scores.isEmpty) {
      throw StateError('No scores were produced by the web model.');
    }

    final bestIndex = _argMax(scores);
    final label = bestIndex < _labels.length
        ? _labels[bestIndex]
        : 'Class $bestIndex';

    return PredictionResult(label: label, confidence: scores[bestIndex]);
  }

  int _argMax(List<double> scores) {
    var bestIndex = 0;
    var bestValue = scores.first;

    for (var index = 1; index < scores.length; index++) {
      if (scores[index] > bestValue) {
        bestValue = scores[index];
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  @override
  void dispose() {}
}
