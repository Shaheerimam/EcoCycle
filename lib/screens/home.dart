import 'dart:typed_data';

import 'package:eco_cycle/classifier/image_classifier.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _picker = ImagePicker();
  final ImageClassifier _classifier = createClassifier();

  List<String> _labels = <String>[];
  Uint8List? _selectedImageBytes;
  String _status = 'Load an image to classify it.';
  String? _predictionLabel;
  double? _confidence;
  bool _isLoading = true;
  bool _isClassifying = false;

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      await _classifier.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _labels = _classifier.labels;
        _isLoading = false;
        _status = 'Model is ready. Pick a picture to classify it.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _status = 'Failed to load the model: $error';
      });
    }
  }

  Future<void> _pickAndClassifyImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );

    if (pickedImage == null) {
      return;
    }

    final imageBytes = await pickedImage.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImageBytes = imageBytes;
      _isClassifying = true;
      _predictionLabel = null;
      _confidence = null;
      _status = 'Running the model...';
    });

    try {
      final prediction = await _classifier.classify(imageBytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _predictionLabel = prediction.label;
        _confidence = prediction.confidence;
        _status = 'Predicted ${prediction.label}.';
        _isClassifying = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Classification failed: $error';
        _isClassifying = false;
      });
    }
  }

  Future<void> _chooseImageSourceAndClassify() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickAndClassifyImage(source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedImageBytes == null)
                        Icon(
                          Icons.image_search_outlined,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                            height: 240,
                            width: double.infinity,
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading) const CircularProgressIndicator(),
                      if (_isClassifying) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_predictionLabel != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _predictionLabel!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Confidence: ${((_confidence ?? 0) * 100).toStringAsFixed(2)}%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Labels: ${_labels.isEmpty ? 'loading...' : _labels.join(', ')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading || _isClassifying
            ? null
            : _chooseImageSourceAndClassify,
        tooltip: 'Capture or pick image',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}
